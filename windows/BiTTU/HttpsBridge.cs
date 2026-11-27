namespace BiTTU;

// Host object behind window.bittuHttps on the HTTPS-only warning page. The
// page posts the insecure URL; allowing the host covers the browsing session,
// exactly like the bittuHttps message handler in the macOS build.
public sealed class HttpsBridge
{
    public void PostMessage(string url)
    {
        if (Uri.TryCreate(url, UriKind.Absolute, out var parsed) && parsed.Host.Length > 0)
        {
            HttpsOnly.Allow(parsed.Host);
            Console.Error.WriteLine("BiTTU HTTPS-only exception for " + parsed.Host);
        }
    }
}