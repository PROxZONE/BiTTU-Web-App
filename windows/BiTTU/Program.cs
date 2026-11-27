namespace BiTTU;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        CookiePolicy.Load();
        HttpsOnly.SetEnabled(true);
        AutoUpdater.Start();
        _ = ContentBlocker.Shared; // compile blocklists before the first tab
        Application.Run(new BrowserForm());
    }
}