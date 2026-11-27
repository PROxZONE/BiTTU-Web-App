namespace BiTTU;

using System.Text.Json;
using Microsoft.Web.WebView2.Core;

// Port of Sources/BiTTU/CookiePolicy.swift: cookie policy with first-party
// isolation, persisted to %LOCALAPPDATA%/BiTTU/cookie-policy.json and enforced
// through WebView2's cookie manager.
public static class CookiePolicy
{
    public enum Mode
    {
        AllowAll,
        BlockThirdParty,
        BlockAll,
    }

    private static readonly object gate = new();
    private static readonly string prefsPath = Path.Combine(
        System.Environment.GetFolderPath(System.Environment.SpecialFolder.LocalApplicationData),
        "BiTTU", "cookie-policy.json");

    public static Mode Current { get; private set; } = Mode.BlockThirdParty;

    public static void Load()
    {
        try
        {
            if (!File.Exists(prefsPath)) return;
            var saved = JsonSerializer.Deserialize<Mode>(File.ReadAllText(prefsPath));
            if (saved is { } mode) Current = mode;
        }
        catch { /* keep the default */ }
    }

    public static void Set(Mode mode)
    {
        Current = mode;
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(prefsPath)!);
            File.WriteAllText(prefsPath, JsonSerializer.Serialize(mode, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("BiTTU cookie policy save failed: " + ex.Message);
        }
        Console.Error.WriteLine("BiTTU cookie policy set to " + mode);
    }

    public static string Label(Mode mode) => mode switch
    {
        Mode.AllowAll => "Allow cookies",
        Mode.BlockThirdParty => "Block third-party cookies (first-party isolation)",
        Mode.BlockAll => "Block all cookies",
        _ => "Block third-party cookies (first-party isolation)",
    };

    // WebView2 has no block-cookies rule list, so the policy is enforced by
    // deleting cookies after responses: third-party jars get wiped on every
    // page load in BlockThirdParty, everything gets wiped in BlockAll.
    public static void Apply(CoreWebView2 core)
    {
        if (Current == Mode.AllowAll) return;
        var cookieManager = core.CookieManager;
        cookieManager.GetCookiesAsync(string.Empty).ContinueWith(t =>
        {
            var cookies = t.Result;
            foreach (var cookie in cookies)
            {
                var thirdParty = !string.Equals(cookie.Domain.TrimStart('.'),
                    CurrentHost(core), StringComparison.OrdinalIgnoreCase);
                var wipe = Current == Mode.BlockAll || thirdParty;
                if (!wipe) continue;
                cookieManager.DeleteCookie(cookie);
            }
        });
    }

    private static string? CurrentHost(CoreWebView2 core) =>
        Uri.TryCreate(core.Source, UriKind.Absolute, out var url) ? url.Host : null;
}
