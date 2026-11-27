namespace BiTTU;

using Microsoft.Web.WebView2.Core;
using System.Text.Json;
using System.Text.RegularExpressions;

// One tab = one WebView2 control, mirroring Sources/BiTTU/Tab.swift plus the
// PermissionGate and SecurityPolicy behaviours attached to every WKWebView.
public sealed class Tab : IDisposable
{
    public Guid Id { get; } = Guid.NewGuid();
    public bool IsPrivate { get; }
    public Microsoft.Web.WebView2.WinForms.WebView2 WebView { get; }
    public string ShieldText => "Shields engaged · permissions blocked";

    public Tab(bool isPrivate, CoreWebView2Environment environment, CoreWebView2ControllerOptions? options)
    {
        IsPrivate = isPrivate;
        WebView = new Microsoft.Web.WebView2.WinForms.WebView2
        {
            Dock = DockStyle.Fill,
            DefaultBackgroundColor = Theme.Background,
        };
        ConfigureWebView(WebView, environment, options);
    }

    public Task Ready => InitTask;

    private Task InitTask { get; set; } = Task.CompletedTask;

    public string Title
    {
        get
        {
            var title = WebView.CoreWebView2?.DocumentTitle;
            if (!string.IsNullOrEmpty(title)) return title!;
            var host = WebView.Source?.Host;
            if (!string.IsNullOrEmpty(host)) return host!;
            return IsPrivate ? "Private Tab" : "New Tab";
        }
    }

    private static Task ConfigureWebView(
        Microsoft.Web.WebView2.WinForms.WebView2 webView,
        CoreWebView2Environment environment,
        CoreWebView2ControllerOptions? options)
    {
        webView.CoreWebView2InitializationCompleted += (_, e) =>
        {
            if (!e.IsSuccess) return;
            var core = webView.CoreWebView2;

            // PermissionGate: every web permission is denied by default.
            core.PermissionRequested += (_, args) =>
            {
                Console.Error.WriteLine($"BiTTU denied permission ({args.PermissionKind}) for origin {args.Uri}");
                args.State = CoreWebView2PermissionState.Deny;
                args.Handled = true;
            };

            // PermissionGate: popups are always blocked.
            core.NewWindowRequested += (_, args) =>
            {
                Console.Error.WriteLine($"BiTTU blocked popup → {args.Uri}");
                args.Handled = true;
            };

            // SecurityPolicy: scheme filter + HTTPS-only upgrade on every navigation.
            core.NavigationStarting += (_, args) =>
            {
                var url = Uri.TryCreate(args.Uri, UriKind.Absolute, out var parsed) ? parsed : null;
                if (url is null) return;
                if (string.Equals(url.Scheme, "http", StringComparison.OrdinalIgnoreCase))
                {
                    var upgraded = SecurityPolicy.Upgraded(url);
                    if (upgraded is not null)
                    {
                        args.Cancel = true;
                        webView.Source = upgraded;
                    }
                    return;
                }
                if (!SecurityPolicy.NavigationAllowed(url))
                {
                    args.Cancel = true;
                }
            };

            // Downloads: hand every download to the DownloadManager.
            core.DownloadStarting += (_, args) =>
            {
                args.Handled = true;
                DownloadManager.Shared.StartDownload(args.DownloadOperation);
            };

            // Shields (per-site) + FingerprintShield injection at document start.
            core.AddWebResourceRequestedFilter("*", CoreWebView2WebResourceContext.All);
            core.WebResourceRequested += (_, args) =>
            {
                if (Uri.TryCreate(args.Request.Uri, UriKind.Absolute, out var url)
                    && Shields.Shared.IsEnabled(url.Host)
                    && ContentBlocker.Shared.ShouldBlock(url))
                {
                    args.Response = core.Environment.CreateWebResourceResponse(null, 403, "Blocked", string.Empty);
                }
            };

            // HTTPS-only: warn instead of silently loading plain HTTP, with the
            // same one-tap session exception as the macOS build.
            core.AddWebResourceRequestedFilter("*", CoreWebView2WebResourceContext.Document);
            core.WebResourceRequested += (_, args) =>
            {
                if (Uri.TryCreate(args.Request.Uri, UriKind.Absolute, out var navUrl)
                    && HttpsOnly.ShouldWarn(navUrl))
                {
                    var response = core.Environment.CreateWebResourceResponse(
                        new MemoryStream(System.Text.Encoding.UTF8.GetBytes(HttpsOnly.WarningPage(navUrl))),
                        200, "OK", "Content-Type: text/html");
                    args.Response = response;
                }
            };

            // CookiePolicy: enforce the chosen mode on every page load.
            core.NavigationCompleted += (_, _) => CookiePolicy.Apply(core);

            // The warning page's "Continue to insecure site" button.
            core.AddHostObjectToScript("bittuHttps", new HttpsBridge());

            // ContentBlocker: hide ad placeholders so layout does not shift.
            var css = ContentBlocker.Shared.InjectedCss;
            if (css.Length > 0)
            {
                var script = "(function(){var s=document.createElement('style');s.textContent=" +
                             JsonSerializer.Serialize(css) + ";document.head.appendChild(s);})();";
                core.AddScriptToExecuteOnDocumentCreatedAsync(script);
            }

            // FingerprintShield: same farbling script as the macOS build.
            _ = core.AddScriptToExecuteOnDocumentCreatedAsync(FingerprintShield.Source);
        };

        return webView.EnsureCoreWebView2Async(environment, options);
    }

    public void Dispose() => ((IDisposable)WebView).Dispose();
}
