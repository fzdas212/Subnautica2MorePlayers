using System;
using System.IO;
using System.Text;
using System.Collections.Generic;

class S
{
    class Sec
    {
        public string Name = "";
        public uint VA;
        public uint VS;
        public uint Raw;
        public uint RawSize;
    }

    static ushort U16(byte[] b, int o) { return BitConverter.ToUInt16(b, o); }
    static uint U32(byte[] b, int o) { return BitConverter.ToUInt32(b, o); }
    static ulong U64(byte[] b, int o) { return BitConverter.ToUInt64(b, o); }

    static List<int> Find(byte[] hay, byte[] needle)
    {
        List<int> res = new List<int>();
        for (int i = 0; i <= hay.Length - needle.Length; i++)
        {
            int j = 0;
            for (; j < needle.Length; j++)
            {
                if (hay[i + j] != needle[j]) break;
            }
            if (j == needle.Length) res.Add(i);
        }
        return res;
    }

    static string HexBytes(byte[] data, int off, int count)
    {
        if (off < 0) off = 0;
        if (off + count > data.Length) count = data.Length - off;
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < count; i++)
        {
            if (i > 0) sb.Append(' ');
            sb.Append(data[off + i].ToString("X2"));
        }
        return sb.ToString();
    }

    static void Main(string[] args)
    {
        string path = args[0];
        byte[] data = File.ReadAllBytes(path);
        int pe = (int)U32(data, 0x3c);
        ushort sections = U16(data, pe + 6);
        ushort optSize = U16(data, pe + 20);
        int opt = pe + 24;
        ulong imageBase = U16(data, opt) == 0x20b ? U64(data, opt + 24) : U32(data, opt + 28);
        int secOff = opt + optSize;
        List<Sec> secs = new List<Sec>();
        for (int i = 0; i < sections; i++)
        {
            int o = secOff + i * 40;
            string name = Encoding.ASCII.GetString(data, o, 8).TrimEnd('\0');
            Sec s = new Sec();
            s.Name = name;
            s.VS = U32(data, o + 8);
            s.VA = U32(data, o + 12);
            s.RawSize = U32(data, o + 16);
            s.Raw = U32(data, o + 20);
            secs.Add(s);
        }

        Func<int, uint?> offToRva = delegate(int off) {
            foreach (Sec s in secs)
            {
                if (off >= s.Raw && off < s.Raw + s.RawSize)
                    return (uint)(s.VA + (off - s.Raw));
            }
            return null;
        };

        Func<uint, int?> rvaToOff = delegate(uint rva) {
            foreach (Sec s in secs)
            {
                uint size = Math.Max(s.VS, s.RawSize);
                if (rva >= s.VA && rva < s.VA + size)
                    return (int)(s.Raw + (rva - s.VA));
            }
            return null;
        };

        Console.WriteLine("ImageBase=0x" + imageBase.ToString("X") + " Sections=" + sections);
        foreach (Sec s in secs)
        {
            Console.WriteLine("SECTION " + s.Name + " VA=0x" + s.VA.ToString("X") + " VS=0x" + s.VS.ToString("X") + " Raw=0x" + s.Raw.ToString("X") + " RawSize=0x" + s.RawSize.ToString("X"));
        }

        string[] patterns = new string[] {
            "Server full", "Server full.", "AtCapacity", "ApproveLogin", "PreLogin", "MaxPlayers",
            "NumPlayers", "NumOpenPrivateConnections", "NumPrivateConnections", "UGameSessionSettings", "SN2GameSession"
        };

        foreach (string p in patterns)
        {
            byte[] ascii = Encoding.ASCII.GetBytes(p);
            byte[] wide = Encoding.Unicode.GetBytes(p);
            byte[][] needles = new byte[][] { ascii, wide };
            string[] labels = new string[] { "ascii", "utf16" };
            for (int n = 0; n < needles.Length; n++)
            {
                List<int> hits = Find(data, needles[n]);
                Console.WriteLine("PATTERN " + p + " " + labels[n] + " count=" + hits.Count);
                int limit = Math.Min(25, hits.Count);
                for (int i = 0; i < limit; i++)
                {
                    int off = hits[i];
                    uint? rva = offToRva(off);
                    string rvaText = rva.HasValue ? "0x" + rva.Value.ToString("X") : "?";
                    string vaText = rva.HasValue ? "0x" + (imageBase + rva.Value).ToString("X") : "?";
                    Console.WriteLine("  off=0x" + off.ToString("X") + " rva=" + rvaText + " va=" + vaText);
                }
            }
        }

        uint[] xrefTargets = new uint[] {
            0xA37C010, // Server full.
            0xA37BF90, // ApproveLogin
            0xA37BEA8, // MaxPlayers near GameSession metadata
            0xA36AD10  // MaxPlayers earlier metadata
        };

        Sec text = null;
        foreach (Sec s in secs)
        {
            if (s.Name == ".text") { text = s; break; }
        }
        if (text != null)
        {
            int textStart = (int)text.Raw;
            int textEnd = (int)(text.Raw + text.RawSize);
            foreach (uint targetRva in xrefTargets)
            {
                ulong targetVa = imageBase + targetRva;
                byte[] vaBytes = BitConverter.GetBytes(targetVa);
                List<int> absHits = Find(data, vaBytes);
                Console.WriteLine("XREF_ABS targetRva=0x" + targetRva.ToString("X") + " targetVa=0x" + targetVa.ToString("X") + " count=" + absHits.Count);
                int absLimit = Math.Min(20, absHits.Count);
                for (int i = 0; i < absLimit; i++)
                {
                    int off = absHits[i];
                    uint? rva = offToRva(off);
                    Console.WriteLine("  off=0x" + off.ToString("X") + " rva=" + (rva.HasValue ? "0x" + rva.Value.ToString("X") : "?") + " bytes=" + HexBytes(data, off - 8, 24));
                }

                List<int> ripHits = new List<int>();
                for (int off = textStart; off < textEnd - 8; off++)
                {
                    for (int len = 5; len <= 10; len++)
                    {
                        int dispOff = off + len - 4;
                        if (dispOff < textStart || dispOff + 4 > textEnd) continue;
                        int disp = BitConverter.ToInt32(data, dispOff);
                        uint instRva = (uint)(text.VA + (off - text.Raw));
                        long computed = (long)instRva + len + disp;
                        if (computed == targetRva)
                        {
                            ripHits.Add(off);
                            break;
                        }
                    }
                }
                Console.WriteLine("XREF_RIP targetRva=0x" + targetRva.ToString("X") + " count=" + ripHits.Count);
                int ripLimit = Math.Min(80, ripHits.Count);
                for (int i = 0; i < ripLimit; i++)
                {
                    int off = ripHits[i];
                    uint? rva = offToRva(off);
                    Console.WriteLine("  off=0x" + off.ToString("X") + " rva=" + (rva.HasValue ? "0x" + rva.Value.ToString("X") : "?") + " bytes=" + HexBytes(data, off - 12, 48));
                }
            }
        }

        uint focusRva = 0x3FBC7E2;
        Sec pdata = null;
        foreach (Sec s in secs)
        {
            if (s.Name == ".pdata") { pdata = s; break; }
        }
        if (pdata != null)
        {
            int pStart = (int)pdata.Raw;
            int pEnd = (int)(pdata.Raw + pdata.RawSize);
            for (int off = pStart; off + 12 <= pEnd; off += 12)
            {
                uint begin = U32(data, off);
                uint end = U32(data, off + 4);
                uint unwind = U32(data, off + 8);
                if (focusRva >= begin && focusRva < end)
                {
                    Console.WriteLine("FOCUS_FUNCTION rva=0x" + focusRva.ToString("X") + " begin=0x" + begin.ToString("X") + " end=0x" + end.ToString("X") + " unwind=0x" + unwind.ToString("X"));
                    int? bOff = rvaToOff(begin);
                    int? eOff = rvaToOff(end);
                    if (bOff.HasValue && eOff.HasValue)
                    {
                        Console.WriteLine("FOCUS_OFFSETS beginOff=0x" + bOff.Value.ToString("X") + " endOff=0x" + eOff.Value.ToString("X") + " size=0x" + (eOff.Value - bOff.Value).ToString("X"));
                        for (int cur = bOff.Value; cur < eOff.Value; cur += 16)
                        {
                            int rvaCur = (int)begin + (cur - bOff.Value);
                            Console.WriteLine("  0x" + rvaCur.ToString("X") + ": " + HexBytes(data, cur, Math.Min(16, eOff.Value - cur)));
                        }
                        int tailEnd = Math.Min(data.Length, eOff.Value + 0x180);
                        Console.WriteLine("FOCUS_TAIL_AFTER_END");
                        for (int cur = eOff.Value; cur < tailEnd; cur += 16)
                        {
                            int rvaCur = (int)end + (cur - eOff.Value);
                            Console.WriteLine("  0x" + rvaCur.ToString("X") + ": " + HexBytes(data, cur, Math.Min(16, tailEnd - cur)));
                        }
                    }
                    break;
                }
            }
        }
    }
}
