namespace BiTTU;

using System.Net.Http;
using System.Text.Json;

// Port of Sources/BiTTU/AutoUpdate.swift: update checks against the GitHub
// releases feed. The macOS build uses Sparkle with an appcast; on Windows the
// equivalent feed is the repo's GitHub releases — the newest release asset
// BiTTU-windows-x64/BiTTU.exe wins. Updates are opt-in: a menu item triggers
// the check, nothing phones home on launch.
public static class AutoUpdater
{
    private const string ReleasesApi = "https://api.github.com/repos/PROxZONE/BiTTU-Web-App/releases/latest";

    private static readonly HttpClient http = new()
    {
        Timeout = TimeSpan.FromSeconds(15),
    };

    public static bool IsEnabled { get; private set; } = true;

    public static void Start()
    {
        // Same spirit as the Sparkle guard: with no feed reachable the menu
        // item simply reports that updates are unavailable.
        IsEnabled = true;
    }

    public static async void CheckForUpdates()
    {
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, ReleasesApi);
            request.Headers.UserAgent.ParseAdd("BiTTU-Web-App");
            request.Headers.Accept.ParseAdd("application/vnd.github+json");
            var response = await http.SendAsync(request);
            if (!response.IsSuccessStatusCode)
            {
                Report("Update check failed: HTTP " + (int)response.StatusCode);
                return;
            }
            using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
            var root = doc.RootElement;
            var tag = root.GetProperty("tag_name").GetString() ?? "unknown";
            var url = root.GetProperty("html_url").GetString() ?? ReleasesApi;
            Report("Latest release: " + tag + " — " + url);
        }
        catch (Exception ex)
        {
            Report("Update check failed: " + ex.Message);
        }
    }

    private static void Report(string message)
    {
        Console.Error.WriteLine("BiTTU auto-update: " + message);
        MessageBox.Show(message, "BiTTU — Check for Updates",
            MessageBoxButtons.OK, MessageBoxIcon.Information);
    }
}
