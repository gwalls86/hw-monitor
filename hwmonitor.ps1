# ============================================================
# Ulanzi HW Monitor - HWiNFO64 (PRO Edition) - Fixed Manufacturers
# ============================================================

$Host.UI.RawUI.WindowTitle = "UlanziEngine"
$INTERVALO_SEGUNDOS = 1
$LOG_FILE  = "$PSScriptRoot\hwmonitor.log"
$JSON_FILE = "$PSScriptRoot\data\datos.json"

function Write-Log($msg) {
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$timestamp - $msg" | Tee-Object -FilePath $LOG_FILE -Append -ErrorAction SilentlyContinue | Write-Host
    } catch {
        Write-Host "$msg"
    }
}

Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.IO.MemoryMappedFiles;

public class HWiNFO {
    public class Reading {
        public string SensorName;
        public string Label;
        public string Unit;
        public double Value;
    }
    static string ReadAnsi(byte[] buf, int offset, int maxLen) {
        int end = offset;
        while (end < offset + maxLen && end < buf.Length && buf[end] != 0) end++;
        return Encoding.Default.GetString(buf, offset, end - offset);
    }
    public static List<Reading> GetReadings() {
        var result = new List<Reading>();
        try {
            var mmf = MemoryMappedFile.OpenExisting("Global\\HWiNFO_SENS_SM2");
            var acc = mmf.CreateViewAccessor(0, 0, MemoryMappedFileAccess.Read);
            uint offSensor   = acc.ReadUInt32(20);
            uint sizeSensor  = acc.ReadUInt32(24);
            uint numSensor   = acc.ReadUInt32(28);
            uint offReading  = acc.ReadUInt32(32);
            uint sizeReading = acc.ReadUInt32(36);
            uint numReading  = acc.ReadUInt32(40);
            long totalSize   = offReading + (long)numReading * sizeReading;
            byte[] buf = new byte[totalSize];
            acc.ReadArray(0, buf, 0, (int)totalSize);
            var sensorNames = new Dictionary<uint, string>();
            for (uint i = 0; i < numSensor; i++) {
                long off = offSensor + i * sizeSensor;
                sensorNames[i] = ReadAnsi(buf, (int)(off + 8), 128);
            }
            for (uint i = 0; i < numReading; i++) {
                long off   = offReading + i * sizeReading;
                uint sIdx  = BitConverter.ToUInt32(buf, (int)(off + 4));
                string lbl = ReadAnsi(buf, (int)(off + 12), 128);
                string unit= ReadAnsi(buf, (int)(off + 268), 16);
                double val = BitConverter.ToDouble(buf, (int)(off + 284));
                result.Add(new Reading {
                    SensorName = sensorNames.ContainsKey(sIdx) ? sensorNames[sIdx] : "",
                    Label = lbl, Unit = unit, Value = val
                });
            }
            acc.Dispose(); mmf.Dispose();
        } catch (Exception ex) {
            result.Add(new Reading { Label="ERROR", SensorName=ex.Message, Unit="", Value=0 });
        }
        return result;
    }
}
"@

function Get-Sensors {
    try {
        return [HWiNFO]::GetReadings()
    } catch { return @() }
}

function Get-DiskShortName($sensorName) {
    if ($sensorName -match '\[([A-Z]:)\]') { $letra = " [$($matches[1])]" } else { $letra = "" }
    $nombre = $sensorName -replace "^S\.M\.A\.R\.T\.: ", ""
    $nombre = $nombre -replace "\s*\([^)]*\).*$", ""
    $nombre = $nombre.Trim()
    if ($nombre.Length -gt 15) { $nombre = $nombre.Substring(0,15).Trim() }
    return "$nombre$letra"
}

function Get-HardwareData($s) {
    if (-not $script:diskMetadata) {
        $script:diskMetadata = @{}
        try {
            Get-PhysicalDisk | ForEach-Object {
                $rawSize = $_.Size
                $formattedSize = if ($rawSize -ge 1TB) { "$([math]::Round($rawSize/1TB, 1)) TB" } else { "$([math]::Round($rawSize/1GB, 0)) GB" }
                $maker = if ($_.Manufacturer -and $_.Manufacturer -notmatch "Generic|Standard") { $_.Manufacturer } else { "Unknown" }
                $script:diskMetadata[$_.FriendlyName.Trim()] = @{ 
                    media = $_.MediaType.ToString()
                    bus   = $_.BusType.ToString().Replace("RAID","SSD")
                    maker = $maker
                    size  = $formattedSize
                }
            }
        } catch {}
    }

    $data = @{
        'discos' = @()
        'cpu'    = @{ 'temp' = "N/A"; 'uso' = 0; 'tag' = ""; 'nombre' = "CPU" }
        'ram'    = @{ 'temp' = "N/A"; 'usada_gb' = 0; 'total_gb' = 0; 'porcentaje' = 0; 'tag' = ""; 'nombre' = "RAM" }
        'gpu'    = @{ 'temp' = "N/A"; 'uso' = 0; 'tag' = ""; 'nombre' = "GPU" }
    }
    
    # CPU
    $cpuT = $s | Where-Object { ($_.Label -match "Tctl|Package|Tdie") -and $_.Value -gt 5 } | Select-Object -First 1
    if ($cpuT) { 
        $data['cpu']['temp'] = [math]::Round($cpuT.Value, 1) 
        $data['cpu']['nombre'] = ($cpuT.SensorName -replace "^CPU\s*\[#\d+\]:\s*", "" -replace ":.*$", "").Trim()
    }
    $cpuL = $s | Where-Object { $_.Label -match "Total CPU Usage|CPU Total" } | Select-Object -First 1
    if ($cpuL) { $data['cpu']['uso'] = [math]::Round($cpuL.Value, 1) }
    
    # GPU
    $gpuT = $s | Where-Object { $_.Label -match "GPU Temp|Graphics Temp" -and $_.SensorName -match "NVIDIA|dGPU" } | Select-Object -First 1
    if ($gpuT) { 
        $data['gpu']['temp'] = [math]::Round($gpuT.Value, 1) 
        $data['gpu']['nombre'] = ($gpuT.SensorName -replace "^(d|i)?GPU\s*\[#\d+\]:\s*", "" -split ":")[0].Trim()
    }
    $gpuL = $s | Where-Object { $_.Label -match "GPU Core Load|Graphics Usage" -and $_.SensorName -match "NVIDIA|dGPU" } | Select-Object -First 1
    if ($gpuL) { $data['gpu']['uso'] = [math]::Round($gpuL.Value, 1) }
    
    # Static Info (Run once or update if needed)
    if (-not $script:staticInfo) {
        $script:staticInfo = @{ 'cpu' = ""; 'ram' = ""; 'gpu' = "" }
        try { 
            $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
            $script:staticInfo['cpu'] = "$($cpu.NumberOfCores)C / $($cpu.NumberOfLogicalProcessors)T"
        } catch { $script:staticInfo['cpu'] = "CPU" }
        
        try {
            $ramItems = Get-CimInstance Win32_PhysicalMemory
            $totalGB = 0; $ramItems | ForEach-Object { $totalGB += $_.Capacity }
            $type = switch ($ramItems[0].SMBIOSMemoryType) { 26 { "DDR4" } 34 { "DDR5" } 24 { "DDR3" } default { "RAM" } }
            $script:staticInfo['ram'] = "$([math]::Round($totalGB/1GB, 0))GB $type"
            $script:ramBrand = if ($ramItems[0].Manufacturer -and $ramItems[0].Manufacturer -notmatch "Unknown|0x") { $ramItems[0].Manufacturer } else { "Samsung" }
        } catch {}
    }

    # Dynamic GPU Static Info (Update if we have a name and haven't set it yet)
    if ($data['gpu']['nombre'] -and ($script:staticInfo['gpu'] -eq "" -or $script:lastGpuName -ne $data['gpu']['nombre'])) {
        try {
            $gpuName = $data['gpu']['nombre']
            $gpuMeta = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -like "*$gpuName*" -or $_.Caption -like "*$gpuName*" } | Select-Object -First 1
            if (-not $gpuMeta) { $gpuMeta = Get-CimInstance Win32_VideoController | Where-Object { $_.AdapterRAM -gt 0 } | Select-Object -First 1 }
            
            if ($gpuMeta) {
                # Handle 32-bit uint overflow (4GB cards often report 4294967295)
                $rawRam = [uint64]$gpuMeta.AdapterRAM
                $vram = [math]::Round($rawRam / 1GB, 0)
                if ($vram -eq 0 -and $rawRam -gt 0) { $vram = [math]::Round($rawRam / 1MB / 1024, 0) }
                # Fallback for 4GB cards that report max uint32
                if ($rawRam -eq 4294967295 -or ($vram -lt 4 -and $gpuName -match "1650|1050|1060|2060|3060")) { 
                    # If it's a known 4GB+ card and reports low, it's likely a reporting error
                    if ($rawRam -eq 4294967295) { $vram = 4 }
                }
                
                $typeSensor = $s | Where-Object { $_.Label -match "Memory Type" -and $_.SensorName -match $gpuName } | Select-Object -First 1
                $typeStr = if ($typeSensor -and $typeSensor.Value -ne 0) { $typeSensor.Value } else { "GDDR5" }
                if ($gpuName -match "RTX|GTX 16") { $typeStr = "GDDR6" } # Heuristic for modern cards if sensor fails
                
                $script:staticInfo['gpu'] = "${vram}GB $typeStr"
                $script:lastGpuName = $gpuName
            }
        } catch { $script:staticInfo['gpu'] = "VRAM" }
    }
    $data['cpu']['tag'] = $script:staticInfo['cpu']
    $data['ram']['tag'] = $script:staticInfo['ram']
    $data['gpu']['tag'] = $script:staticInfo['gpu']
    $data['ram']['nombre'] = $script:ramBrand

    # RAM Dynamic
    $ramU = $s | Where-Object { $_.Label -eq "Physical Memory Used" } | Select-Object -First 1
    $ramA = $s | Where-Object { $_.Label -eq "Physical Memory Available" } | Select-Object -First 1
    if ($ramU) {
        $u = $ramU.Value / 1024
        $total = if ($ramA) { ($ramU.Value + $ramA.Value) / 1024 } else { $u }
        $data['ram']['usada_gb'] = [math]::Round($u, 1)
        $data['ram']['total_gb'] = [math]::Round($total, 1)
        $data['ram']['porcentaje'] = [math]::Round(($u / $total) * 100, 1)
    }
    $ramT = $s | Where-Object { $_.Label -match "SPD Hub Temperature|Memory Temperature|DIMM.*Temp" } | Select-Object -First 1
    if ($ramT) { $data['ram']['temp'] = [math]::Round($ramT.Value, 1) }

    # Disks
    $tempMap = @{}
    $diskTItems = $s | Where-Object { $_.Label -like "Drive Temperature*" -and $_.SensorName -like "*S.M.A.R.T.*" }
    foreach ($d in $diskTItems) {
        $rawName = ($d.SensorName -replace "^S\.M\.A\.R\.T\.: ", "" -replace "\s*\([^)]*\).*$", "").Trim()
        $meta = if ($script:diskMetadata.ContainsKey($rawName)) { $script:diskMetadata[$rawName] } else { @{ 'media'="SSD"; 'bus'="SATA"; 'maker'="Unknown"; 'size'="--" } }
        $letra = if ($d.SensorName -match '\[([A-Z]:)\]') { $matches[1] } else { "UNK" }
        $key = "$rawName-$letra"
        if (-not $tempMap.ContainsKey($key) -or $d.Label -eq "Drive Temperature") {
            $p = "\[$letra\]"; $diskLoadItem = $null
            if ($letra -ne "UNK") { $diskLoadItem = $s | Where-Object { $_.Label -eq "Total Activity" -and $_.SensorName -match $p -and $_.SensorName -notmatch "S\.M\.A\.R\.T\." } | Select-Object -First 1 }
            $fabricante = if ($meta['maker'] -and $meta['maker'] -notmatch "Unknown|Generic|Standard") { $meta['maker'] } else {
                if ($rawName -match "WDC|Western") { "Western Digital" }
                elseif ($rawName -match "Lexar") { "Lexar" }
                elseif ($rawName -match "CT|Crucial") { "Crucial" }
                elseif ($rawName -match "Samsung") { "Samsung" }
                else { "Storage" }
            }
            $tempMap[$key] = @{
                'nombre' = (Get-DiskShortName $d.SensorName)
                'letra'  = $letra
                'temp'   = [math]::Round($d.Value, 1)
                'uso'    = if ($diskLoadItem) { [math]::Round($diskLoadItem.Value, 1) } else { 0 }
                'tipo'   = $meta['media']; 'bus' = $meta['bus']
                'ext'    = [bool]($meta['bus'] -eq "USB" -or $letra -eq "L:")
                'maker'  = $fabricante; 'size' = $meta['size']
            }
        }
    }
    $data['discos'] = $tempMap.Values | ForEach-Object { $_ }
    return $data
}

# --- MAIN LOOP ---
Write-Log "=== Ulanzi HW Monitor PRO (v2) ==="
if (Test-Path $JSON_FILE) { Remove-Item $JSON_FILE -Force }
$dir = "$PSScriptRoot\data"; if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
$lastData = $null

while ($true) {
    try {
        $s = Get-Sensors
        if ($s.Count -gt 0 -and $s[0].Label -ne "ERROR") { 
            $currentData = Get-HardwareData $s
            if ($lastData) {
                if ($currentData['cpu']['temp'] -eq "N/A") { $currentData['cpu']['temp'] = $lastData['cpu']['temp'] }
                if ($currentData['gpu']['temp'] -eq "N/A") { $currentData['gpu']['temp'] = $lastData['gpu']['temp'] }
            }
            $lastData = $currentData
            $tempJson = "$JSON_FILE.tmp"
            $currentData | ConvertTo-Json -Depth 3 | Set-Content $tempJson -Encoding UTF8
            Move-Item -Path $tempJson -Destination $JSON_FILE -Force
            Write-Log "Live -> CPU:$($currentData['cpu']['temp']) GPU:$($currentData['gpu']['temp']) RAM:$($currentData['ram']['temp'])"
        }
    } catch { Write-Log "ERR: $($_.Exception.Message)" }
    Start-Sleep -Seconds $INTERVALO_SEGUNDOS
}
