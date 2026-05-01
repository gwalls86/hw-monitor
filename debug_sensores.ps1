# Debug v3 - busca el double value y el label con offsets correctos

Add-Type @"
using System;
using System.Text;
using System.IO.MemoryMappedFiles;

public class HWiNFO4 {
    static string ReadAnsi(byte[] buf, int offset, int maxLen) {
        int end = offset;
        while (end < offset + maxLen && end < buf.Length && buf[end] != 0) end++;
        return Encoding.Default.GetString(buf, offset, end - offset);
    }

    public static void Dump() {
        var mmf = MemoryMappedFile.OpenExisting("Global\\HWiNFO_SENS_SM2");
        var acc = mmf.CreateViewAccessor(0, 0,
            System.IO.MemoryMappedFiles.MemoryMappedFileAccess.Read);

        uint offReading  = acc.ReadUInt32(36);
        uint sizeReading = acc.ReadUInt32(40);  // 412
        uint numReading  = acc.ReadUInt32(44);

        long totalSize = offReading + (long)numReading * sizeReading;
        byte[] buf = new byte[totalSize];
        acc.ReadArray(0, buf, 0, (int)totalSize);

        // El layout real segun los bytes:
        // +000: szSensorNameOrig (128 bytes) - pero parece que empieza en buf[offReading+0]
        // Vemos "D Ryzen 7 9700X" en +000, lo que significa que los primeros 2 bytes
        // son algo mas (tReading=uint32 + dwSensorIndex=uint32 = 8 bytes?)
        // Revisemos: en +000 vemos 44 20 = 'D ' que es parte de "AMD Ryzen"
        // Eso significa que NO hay header antes, el string empieza directo en +000
        // PERO el nombre completo es "CPU [#0]: AMD Ryzen 7 9700X"
        // En +000 vemos "D Ryzen 7 9700X" -> los primeros bytes son "CPU [#0]: AM"
        // que tiene 12 chars -> offset real del SensorName es -12? No...
        
        // Mirando +112: "....CPU [#0]: AM" -> los 4 bytes antes son 00s
        // Mirando +000: "D Ryzen 7 9700X" -> esto es la continuacion de algo
        
        // CONCLUSION: sizeReading=412 pero el elemento ANTERIOR termina aqui
        // El primer reading empieza en offReading=460
        // Pero el dump muestra desde offReading, y vemos "D Ryzen 7 9700X" en +0
        // Eso significa que offReading esta mal calculado O el struct tiene padding
        
        // Probemos: el header dice offSensor=392, sizeSensor=23(??)... 23 es muy pequeno
        // Quizas sizeSensor esta en otro offset
        
        // Releyendo header con layout oficial HWiNFO:
        // offset 0:  dwSignature (4)
        // offset 4:  dwVersion (4)  
        // offset 8:  dwRevision (4)
        // offset 12: poll_time (8) <- int64!
        // offset 20: dwOffsetOfSensorSection (4) = 48 (0x30)  <- ojo! era offset 20 no 24
        // offset 24: dwSizeOfSensorElement (4) = 392 (0x188)  <- ese es el SIZE!
        // offset 28: dwNumSensorElements (4) = 23
        // offset 32: dwOffsetOfReadingSection (4) = 9064 (0x2368)
        // offset 36: dwSizeOfReadingElement (4) = 460 (0x1CC) 
        // offset 40: dwNumReadingElements (4) = 412
        // offset 44: ??? = 2000
        
        // Intentemos con estos offsets corregidos:
        uint offSensor2   = acc.ReadUInt32(20);  // 48
        uint sizeSensor2  = acc.ReadUInt32(24);  // 392
        uint numSensor2   = acc.ReadUInt32(28);  // 23
        uint offReading2  = acc.ReadUInt32(32);  // 9064
        uint sizeReading2 = acc.ReadUInt32(36);  // 460
        uint numReading2  = acc.ReadUInt32(40);  // 412

        Console.WriteLine("LAYOUT CORREGIDO:");
        Console.WriteLine("offSensor="  + offSensor2  + " sizeSensor="  + sizeSensor2  + " numSensor="  + numSensor2);
        Console.WriteLine("offReading=" + offReading2 + " sizeReading=" + sizeReading2 + " numReading=" + numReading2);

        long totalSize2 = offReading2 + (long)numReading2 * sizeReading2;
        byte[] buf2 = new byte[totalSize2];
        acc.ReadArray(0, buf2, 0, (int)totalSize2);

        // Dump primer sensor
        Console.WriteLine("\n=== PRIMER SENSOR (sizeSensor=" + sizeSensor2 + ") ===");
        for (int i = 0; i < (int)sizeSensor2 && i < 512; i += 16) {
            string hex = ""; string asc = "";
            for (int j = i; j < i+16 && j < (int)sizeSensor2; j++) {
                byte b = buf2[(int)offSensor2 + j];
                hex += b.ToString("X2") + " ";
                asc += (b >= 32 && b < 127) ? (char)b : '.';
            }
            Console.WriteLine("  +" + i.ToString("D3") + ": " + hex.PadRight(49) + " | " + asc);
        }

        // Dump primer reading
        Console.WriteLine("\n=== PRIMER READING (sizeReading=" + sizeReading2 + ") ===");
        for (int i = 0; i < (int)sizeReading2 && i < 512; i += 16) {
            string hex = ""; string asc = "";
            for (int j = i; j < i+16 && j < (int)sizeReading2; j++) {
                byte b = buf2[(int)offReading2 + j];
                hex += b.ToString("X2") + " ";
                asc += (b >= 32 && b < 127) ? (char)b : '.';
            }
            Console.WriteLine("  +" + i.ToString("D3") + ": " + hex.PadRight(49) + " | " + asc);
        }

        // Buscar doubles que parezcan temperaturas (20-120) o porcentajes (0-100)
        Console.WriteLine("\n=== DOUBLES EN PRIMER READING ===");
        for (int i = 0; i + 8 <= (int)sizeReading2; i += 4) {
            double d = BitConverter.ToDouble(buf2, (int)offReading2 + i);
            if (d > 0 && d < 200 && !double.IsNaN(d) && !double.IsInfinity(d)) {
                Console.WriteLine("  offset +" + i + ": " + Math.Round(d, 4));
            }
        }

        acc.Dispose(); mmf.Dispose();
    }
}
"@

[HWiNFO4]::Dump()