namespace BiTTU;

using System.Globalization;

// Port of Sources/BiTTU/SecurityPolicy.swift: address-bar resolution, HTTPS
// upgrade and the scheme allow-list.
public static class SecurityPolicy
{
    public static Uri? RequestUrl(string raw)
    {
        var trimmed = raw.Trim();
        if (trimmed.Length == 0) return null;

        var lower = trimmed.ToLowerInvariant();
        if (lower.StartsWith("https://") || lower.StartsWith("http://"))
        {
            return Upgraded(Uri.TryCreate(trimmed, UriKind.Absolute, out var url) ? url : null);
        }

        var looksLikeDomain = !trimmed.Contains(' ')
            && trimmed.Contains('.')
            && !trimmed.Contains("..")
            && !trimmed.EndsWith(".");
        if (looksLikeDomain && Uri.TryCreate("https://" + trimmed, UriKind.Absolute, out var https))
        {
            return https;
        }

        var encoded = Uri.EscapeDataString(trimmed);
        return Uri.TryCreate("https://duckduckgo.com/?q=" + encoded, UriKind.Absolute, out var search)
            ? search
            : null;
    }

    public static Uri? Upgraded(Uri? url)
    {
        if (url is null) return null;
        if (!string.Equals(url.Scheme, "http", StringComparison.OrdinalIgnoreCase)) return url;
        var builder = new UriBuilder(url) { Scheme = "https", Port = 443 };
        return builder.Uri;
    }

    // Only plain web content is allowed. Everything else (file:, ftp:,
    // javascript:, custom schemes...) is cancelled and logged.
    public static bool NavigationAllowed(Uri? url)
    {
        if (url is null || string.IsNullOrEmpty(url.Scheme))
        {
            Console.Error.WriteLine("BiTTU blocked navigation with no URL/scheme");
            return false;
        }
        var scheme = url.Scheme.ToLowerInvariant();
        var allowed = scheme is "https" or "http";
        if (!allowed)
        {
            Console.Error.WriteLine($"BiTTU blocked non-web scheme {scheme} ( {url.AbsoluteUri} )");
        }
        return allowed;
    }
}
