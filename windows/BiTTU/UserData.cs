namespace BiTTU;

using System.Text.Json;
using System.Text.Json.Serialization;

// Port of Sources/BiTTU/UserData.swift: bookmarks, history and search engines
// as plain JSON under %LOCALAPPDATA%/BiTTU — nothing leaves the machine, and
// private tabs never touch history.
public sealed class UserData
{
    public sealed record Bookmark(string Title, string Url, DateTimeOffset Added);
    public sealed record HistoryEntry(string Title, string Url, DateTimeOffset Visited);
    public sealed record SearchEngine(string Name, string Template);

    public static readonly SearchEngine[] BuiltInEngines =
    {
        new("DuckDuckGo", "https://duckduckgo.com/?q={query}"),
        new("Startpage", "https://www.startpage.com/sp/search?query={query}"),
        new("Mojeek", "https://www.mojeek.com/search?q={query}"),
        new("Google", "https://www.google.com/search?q={query}"),
        new("Bing", "https://www.bing.com/search?q={query}"),
    };

    private static readonly UserData instance = new();
    public static UserData Shared => instance;

    private const int HistoryLimit = 2000;

    private readonly object gate = new();
    private readonly string dir;
    private List<Bookmark> bookmarks = new();
    private List<HistoryEntry> history = new();
    private List<SearchEngine> engines = new();
    private string defaultEngineName = "DuckDuckGo";

    private UserData()
    {
        dir = Path.Combine(
            System.Environment.GetFolderPath(System.Environment.SpecialFolder.LocalApplicationData),
            "BiTTU");
        Directory.CreateDirectory(dir);
        bookmarks = LoadList<Bookmark>("bookmarks.json") ?? new List<Bookmark>();
        history = LoadList<HistoryEntry>("history.json") ?? new List<HistoryEntry>();
        engines = LoadList<SearchEngine>("engines.json") ?? new List<SearchEngine>();
        if (engines.Count == 0) engines = BuiltInEngines.ToList();
        var storedDefault = LoadString("default-engine.json");
        defaultEngineName = storedDefault is not null && engines.Any(e => e.Name == storedDefault)
            ? storedDefault
            : "DuckDuckGo";
    }

    private string Path_(string name) => Path.Combine(dir, name);

    private List<T>? LoadList<T>(string name)
    {
        try
        {
            if (!File.Exists(Path_(name))) return null;
            return JsonSerializer.Deserialize<List<T>>(File.ReadAllText(Path_(name)));
        }
        catch { return null; }
    }

    private string? LoadString(string name)
    {
        try { return File.Exists(Path_(name)) ? File.ReadAllText(Path_(name)).Trim().Trim('"') : null; }
        catch { return null; }
    }

    private void Save(object value, string name)
    {
        try
        {
            var options = new JsonSerializerOptions
            {
                WriteIndented = true,
                DefaultIgnoreCondition = JsonIgnoreCondition.Never,
            };
            File.WriteAllText(Path_(name), JsonSerializer.Serialize(value, options));
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("BiTTU: failed to save " + name + ": " + ex.Message);
        }
    }

    public IReadOnlyList<Bookmark> Bookmarks { get { lock (gate) return bookmarks.ToArray(); } }
    public IReadOnlyList<HistoryEntry> History { get { lock (gate) return history.ToArray(); } }
    public IReadOnlyList<SearchEngine> Engines { get { lock (gate) return engines.ToArray(); } }
    public string DefaultEngineName => defaultEngineName;

    public SearchEngine? DefaultEngine =>
        Engines.FirstOrDefault(e => e.Name == defaultEngineName) ?? BuiltInEngines[0];

    // MARK: Bookmarks

    public bool AddBookmark(string title, string url)
    {
        if (IsBookmarked(url)) return false;
        lock (gate)
        {
            bookmarks.Add(new Bookmark(title.Length == 0 ? url : title, url, DateTimeOffset.Now));
            Save(bookmarks, "bookmarks.json");
        }
        return true;
    }

    public void RemoveBookmark(string url)
    {
        lock (gate)
        {
            bookmarks.RemoveAll(b => b.Url == url);
            Save(bookmarks, "bookmarks.json");
        }
    }

    public bool IsBookmarked(string url)
    {
        lock (gate) return bookmarks.Any(b => b.Url == url);
    }

    public string ExportBookmarks()
    {
        using var dialog = new SaveFileDialog
        {
            Filter = "JSON files (*.json)|*.json",
            FileName = "BiTTU-Bookmarks.json",
            Title = "Export Bookmarks",
        };
        if (dialog.ShowDialog() != DialogResult.OK) return "";
        try
        {
            var options = new JsonSerializerOptions { WriteIndented = true };
            File.WriteAllText(dialog.FileName, JsonSerializer.Serialize(Bookmarks, options));
            return dialog.FileName;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("BiTTU bookmark export failed: " + ex.Message);
            return "";
        }
    }

    // MARK: History

    public void RecordVisit(string title, Uri url, bool isPrivate)
    {
        if (isPrivate) return;
        var entry = new HistoryEntry(title.Length == 0 ? url.AbsoluteUri : title,
                                     url.AbsoluteUri, DateTimeOffset.Now);
        lock (gate)
        {
            history.RemoveAll(h => h.Url == entry.Url);
            history.Add(entry);
            if (history.Count > HistoryLimit)
            {
                history.RemoveRange(0, history.Count - HistoryLimit);
            }
            Save(history, "history.json");
        }
    }

    public void ClearHistory()
    {
        lock (gate)
        {
            history.Clear();
            Save(history, "history.json");
        }
    }

    // MARK: Search engines

    public bool SetDefaultEngine(string name)
    {
        if (!Engines.Any(e => e.Name == name)) return false;
        defaultEngineName = name;
        lock (gate) Save(name, "default-engine.json");
        return true;
    }

    public bool AddEngine(string name, string template)
    {
        var trimmedName = name.Trim();
        var trimmedTemplate = template.Trim();
        if (trimmedName.Length == 0 || trimmedTemplate.Length == 0) return false;
        if (!trimmedTemplate.Contains("{query}")) return false;
        if (!Uri.TryCreate(trimmedTemplate.Replace("{query}", "x"), UriKind.Absolute, out _)) return false;
        lock (gate)
        {
            if (engines.Any(e => string.Equals(e.Name, trimmedName, StringComparison.OrdinalIgnoreCase)))
            {
                return false;
            }
            engines.Add(new SearchEngine(trimmedName, trimmedTemplate));
            Save(engines, "engines.json");
        }
        return true;
    }

    public void RemoveEngine(string name)
    {
        lock (gate)
        {
            engines.RemoveAll(e => e.Name == name);
            if (defaultEngineName == name)
            {
                defaultEngineName = engines.FirstOrDefault()?.Name ?? "DuckDuckGo";
            }
            Save(engines, "engines.json");
            Save(defaultEngineName, "default-engine.json");
        }
    }

    // Resolve raw address-bar input with the chosen engine's template,
    // falling back to DuckDuckGo when no custom engine matches.
    public Uri? SearchUrl(string raw)
    {
        var encoded = Uri.EscapeDataString(raw).Replace("+", "%2B");
        var template = DefaultEngine?.Template ?? "https://duckduckgo.com/?q={query}";
        return Uri.TryCreate(template.Replace("{query}", encoded), UriKind.Absolute, out var url) ? url : null;
    }
}
