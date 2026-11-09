// [VI] Launcher Moc.exe (asInvoker): chạy Start-Moc.ps1 bằng powershell.exe 5.1 với RemoteSigned cho riêng tiến trình con; báo lỗi bằng MessageBox.
// Thin, asInvoker bootstrap. The application logic remains readable PowerShell.
// Do not use shell execution or elevate the full GUI.
using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class MocLauncher
{
    [STAThread]
    private static int Main(string[] arguments)
    {
        try
        {
            string root = AppDomain.CurrentDomain.BaseDirectory;
            string script = Path.Combine(root, "Start-Moc.ps1");
            if (!File.Exists(script)) throw new FileNotFoundException("Keep Moc.exe together with Start-Moc.ps1, src and data.");
            string engine = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), @"System32\WindowsPowerShell\v1.0\powershell.exe");
            var start = new ProcessStartInfo(engine);
            start.Arguments = "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -STA -File \"" + script + "\"";
            // Fixed developer smoke mode; never forward arbitrary command-line text.
            if (arguments.Length == 1 && arguments[0] == "--smoke-test") start.Arguments += " -SmokeTest";
            else if (arguments.Length != 0) throw new ArgumentException("Supported arguments: --smoke-test (optional)");
            start.WorkingDirectory = root;
            start.UseShellExecute = false;
            start.CreateNoWindow = true;
            start.RedirectStandardOutput = true;
            start.RedirectStandardError = true;
            using (var process = Process.Start(start))
            {
                var output = process.StandardOutput.ReadToEndAsync();
                var error = process.StandardError.ReadToEndAsync();
                process.WaitForExit();
                string details = error.GetAwaiter().GetResult();
                output.GetAwaiter().GetResult();
                if (process.ExitCode != 0)
                    MessageBox.Show(details.Length > 0 ? details : "Moc exited before completing startup. Try Start-Moc.cmd for details.", "Moc Toolkit", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return process.ExitCode;
            }
        }
        catch (Exception error)
        {
            MessageBox.Show(error.Message, "Moc Toolkit", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}
