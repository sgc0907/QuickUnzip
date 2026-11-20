// QuickUnzip.exe: 같은 폴더의 QuickUnzip.ps1 을 창 없이 실행하는 런처
using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

[assembly: System.Reflection.AssemblyTitle("QuickUnzip")]
[assembly: System.Reflection.AssemblyProduct("QuickUnzip")]

static class Program {
    [STAThread]
    static void Main(string[] args) {
        if (args.Length == 0) {
            MessageBox.Show("zip 파일을 더블클릭하거나 이 프로그램 위에 끌어다 놓으세요.", "QuickUnzip");
            return;
        }
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        try { File.AppendAllText(Path.Combine(dir, "log.txt"), DateTime.Now.ToString("s") + " exe args: " + string.Join(" | ", args) + Environment.NewLine); } catch { }
        string script = Path.Combine(dir, "QuickUnzip.ps1");
        // 사용법: QuickUnzip.exe [--enc=auto|utf8|cp949|cp932|cp936] 파일...
        string enc = "auto";
        foreach (string a in args) if (a.StartsWith("--enc=")) enc = a.Substring(6);
        foreach (string zip in args) {
            if (zip.StartsWith("--")) continue;
            var psi = new ProcessStartInfo("powershell.exe",
                "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\" \"" + zip + "\" -Encoding " + enc);
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            Process.Start(psi);
        }
    }
}
