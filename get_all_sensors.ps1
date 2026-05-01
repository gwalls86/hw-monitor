
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
            uint offReading  = acc.ReadUInt32(32);
            uint numReading  = acc.ReadUInt32(40);
            uint sizeReading = acc.ReadUInt32(36);
            long totalSize   = offReading + (long)numReading * sizeReading;
            byte[] buf = new byte[totalSize];
            acc.ReadArray(0, buf, 0, (int)totalSize);
            for (uint i = 0; i < numReading; i++) {
                long off   = offReading + i * sizeReading;
                string lbl = ReadAnsi(buf, (int)(off + 12), 128);
                string unit= ReadAnsi(buf, (int)(off + 268), 16);
                double val = BitConverter.ToDouble(buf, (int)(off + 284));
                result.Add(new Reading { Label = lbl, Unit = unit, Value = val });
            }
            acc.Dispose(); mmf.Dispose();
        } catch {}
        return result;
    }
}
"@
try {
    $r = [HWiNFO]::GetReadings()
    if ($r.Count -eq 0) { "NO DATA" }
    else {
        $r | ForEach-Object { "$($_.Label) | $($_.Value) | $($_.Unit)" }
    }
} catch { "ERROR: $_" }
