using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace DocumentationSync
{
    public static class WindowsFile
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct FileInformation
        {
            public uint Attributes;
            public FILETIME CreationTime;
            public FILETIME LastAccessTime;
            public FILETIME LastWriteTime;
            public uint VolumeSerialNumber;
            public uint SizeHigh;
            public uint SizeLow;
            public uint NumberOfLinks;
            public uint FileIndexHigh;
            public uint FileIndexLow;
        }

        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetFileInformationByHandle(SafeFileHandle file, out FileInformation information);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
        private static extern uint GetFinalPathNameByHandleW(SafeFileHandle file, StringBuilder path, uint capacity, uint flags);

        public static string GetBlockReason(SafeFileHandle file, string expectedPath)
        {
            const uint directory = 0x10;
            const uint device = 0x40;
            const uint reparsePoint = 0x400;
            if (!GetFileInformationByHandle(file, out var information))
                throw new Win32Exception(Marshal.GetLastWin32Error());

            if ((information.Attributes & (directory | device | reparsePoint)) != 0)
                return "not_an_ordinary_file";
            if (information.NumberOfLinks != 1)
                return "hard_link_or_unverified_link_count";

            // Zero requests the normalized DOS name for the opened handle.
            var path = new StringBuilder(32768);
            uint length = GetFinalPathNameByHandleW(file, path, (uint)path.Capacity, 0);
            if (length == 0)
                throw new Win32Exception(Marshal.GetLastWin32Error());
            if (length >= path.Capacity ||
                !string.Equals(path.ToString(), @"\\?\" + expectedPath, StringComparison.OrdinalIgnoreCase))
                return "opened_path_mismatch";

            return null;
        }
    }
}
