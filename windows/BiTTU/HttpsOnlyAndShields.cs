namespace BiTTU;

// Ports of Sources/BiTTU/HTTPSOnly.swift and Shields.swift: the session-scoped
// insecure-host exceptions and the per-site shields-down set, both persisted
// as plain JSON under %LOCALAPPDATA%/BiTTU.
public static class HttpsOnly
{
    private const string UrlPlaceholder = "__BITTU_URL__";

    public static bool IsEnabled { get; private set; } = true;

    private static readonly HashSet<string> exceptions = new();
    private static readonly object gate = new();
    private static string? cachedPage;

    public static void SetEnabled(bool on) => IsEnabled = on;

    public static void Allow(string host)
    {
        lock (gate) exceptions.Add(host.ToLowerInvariant());
    }

    public static bool IsAllowed(string host)
    {
        lock (gate) return exceptions.Contains(host.ToLowerInvariant());
    }

    public static bool ShouldWarn(Uri? url)
    {
        if (!IsEnabled || url is null) return false;
        var scheme = url.Scheme.ToLowerInvariant();
        if (scheme is not ("http" or "ws")) return false;
        var host = url.Host;
        if (host.Length == 0) return false;
        return !IsAllowed(host);
    }

    // The dark warning page ships as Resources/warning.html (same CSS as the
    // macOS build); the URL is substituted in escaped form.
    public static string WarningPage(Uri url) =>
        Page().Replace(UrlPlaceholder, EscapedHtml(url.AbsoluteUri));

    private static string Page()
    {
        if (cachedPage is not null) return cachedPage;
        using var stream = typeof(HttpsOnly).Assembly.GetManifestResourceStream("BiTTU.warning.html");
        if (stream is null) return "<!DOCTYPE html><html><body><h1>This page would travel unencrypted.</h1></body></html>";
        using var reader = new StreamReader(stream);
        cachedPage = reader.ReadToEnd();
        return cachedPage;
    }

    // Same escaping order as HTTPSOnly.escapedHTML in the Swift source.
    public static string EscapedHtml(string text) => text
        .Replace("&", "&amp;")
        .Replace("<", "&lt;")
        .Replace(">", "&gt;")
        .Replace(""", "&quot;");
}

public sealed class Shields
{
    private static readonly Shields shared = new();
    public static Shields Shared => shared;

    private readonly object gate = new();
    private readonly string path;
    private HashSet<string> disabledHosts = new();

    private Shields()
    {
        var dir = Path.Combine(
            System.Environment.GetFolderPath(System.Environment.SpecialFolder.LocalApplicationData),
            "BiTTU");
        Directory.CreateDirectory(dir);
        path = Path.Combine(dir, "shields.json");
        try
        {
            if (File.Exists(path))
            {
                var hosts = System.Text.Json.JsonSerializer.Deserialize<HashSet<string>>(File.ReadAllText(path));
                if (hosts is not null) disabledHosts = hosts;
            }
        }
        catch { /* start with shields up everywhere */ }
    }

    public bool IsEnabled(string? host)
    {
        if (string.IsNullOrEmpty(host)) return true;
        lock (gate) return !disabledHosts.Contains(host.ToLowerInvariant());
    }

    public bool Toggle(string host)
    {
        var key = host.ToLowerInvariant();
        bool enabled;
        lock (gate)
        {
            if (!disabledHosts.Remove(key)) disabledHosts.Add(key);
            enabled = !disabledHosts.Contains(key);
            try
            {
                File.WriteAllText(path, System.Text.Json.JsonSerializer.Serialize(disabledHosts));
            }
            catch { /* keep the in-memory state */ }
        }
        Console.Error.WriteLine("BiTTU shields " + (enabled ? "up" : "down") + " for " + key);
        return enabled;
    }
}
