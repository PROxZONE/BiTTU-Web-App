namespace BiTTU;

using Microsoft.Web.WebView2.Core;

// One WebView2 environment for the whole app. Private tabs use InPrivate
// controller options so nothing is written to the user-data folder
// (mirrors Tab(isPrivate:) in Sources/BiTTU/Tab.swift).
internal sealed class WebViewEnvironment
{
    private static readonly Lazy<WebViewEnvironment> Instance = new(Create);
    public static WebViewEnvironment Shared => Instance.Value;

    public CoreWebView2Environment Environment { get; private init; } = null!;

    public static CoreWebView2ControllerOptions? OptionsFor(bool privateMode)
    {
        if (!privateMode) return null;
        try
        {
            var options = Shared.Environment.CreateCoreWebView2ControllerOptions();
            options.IsInPrivateModeEnabled = true;
            return options;
        }
        catch (NotImplementedException)
        {
            Console.Error.WriteLine("BiTTU: InPrivate mode unavailable in this WebView2 runtime");
            return null;
        }
    }

    private static WebViewEnvironment Create()
    {
        var dataFolder = Path.Combine(
            System.Environment.GetFolderPath(System.Environment.SpecialFolder.LocalApplicationData),
            "BiTTU", "WebView2");
        var environment = CoreWebView2Environment.CreateAsync(
            userDataFolder: dataFolder,
            options: new CoreWebView2EnvironmentOptions
            {
                // Keep the same tracking-prevention stance as the macOS build.
                EnableTrackingPrevention = true,
            }).GetAwaiter().GetResult();
        return new WebViewEnvironment { Environment = environment };
    }
}
