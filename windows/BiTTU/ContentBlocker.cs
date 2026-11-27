namespace BiTTU;

using System.Text.Json;
using System.Text.RegularExpressions;

// Port of Sources/BiTTU/ContentBlocker.swift. WKContentRuleList is macOS-only,
// so the same Safari content-blocker JSON is interpreted here and enforced with
// WebView2's WebResourceRequested handler (network blocks) and an injected
// stylesheet (css-display-none rules).
public sealed class ContentBlocker
{
    public sealed record Rule(Regex? DomainPattern, Regex? UrlPattern, bool BlocksAnyUrl, string? CssSelector);

    private static readonly Lazy<ContentBlocker> Instance = new(LoadAll);
    public static ContentBlocker Shared => Instance.Value;

    public IReadOnlyList<Rule> Rules { get; private init; } = Array.Empty<Rule>();
    public string InjectedCss { get; private init; } = string.Empty;
    public int ListsLoaded { get; private init; }

    public bool ShouldBlock(Uri url)
    {
        foreach (var rule in Rules)
        {
            if (rule.CssSelector is not null) continue;
            if (rule.BlocksAnyUrl || rule.UrlPattern?.IsMatch(url.AbsoluteUri) == true)
            {
                var host = url.Host;
                if (rule.DomainPattern is null || rule.DomainPattern.IsMatch(host))
                {
                    return true;
                }
            }
        }
        return false;
    }

    private static ContentBlocker LoadAll()
    {
        var dir = Path.Combine(AppContext.BaseDirectory, "blocklists");
        var files = Directory.Exists(dir)
            ? Directory.GetFiles(dir, "*.json").OrderBy(f => f, StringComparer.Ordinal).ToArray()
            : Array.Empty<string>();

        if (files.Length == 0)
        {
            Console.Error.WriteLine("BiTTU: no blocklists bundled");
            return new ContentBlocker();
        }

        var rules = new List<Rule>();
        var css = new List<string>();
        var loaded = 0;

        foreach (var file in files)
        {
            try
            {
                using var doc = JsonDocument.Parse(File.ReadAllText(file));
                foreach (var element in doc.RootElement.EnumerateArray())
                {
                    var trigger = element.GetProperty("trigger");
                    var action = element.GetProperty("action");
                    var actionType = action.GetProperty("type").GetString();

                    if (actionType == "css-display-none")
                    {
                        css.Add(action.GetProperty("selector").GetString() ?? string.Empty);
                        continue;
                    }
                    if (actionType != "block") continue;

                    var urlFilter = trigger.GetProperty("url-filter").GetString() ?? ".*";
                    var anyUrl = urlFilter == ".*";

                    Regex? domainPattern = null;
                    if (trigger.TryGetProperty("if-domain", out var domains))
                    {
                        domainPattern = DomainRegex(domains);
                    }

                    rules.Add(new Rule(domainPattern,
                        anyUrl ? null : new Regex(urlFilter, RegexOptions.IgnoreCase | RegexOptions.Compiled),
                        anyUrl && domainPattern is not null,
                        null));
                }
                loaded++;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"BiTTU: blocklist {Path.GetFileName(file)} failed to load: {ex.Message}");
            }
        }

        Console.Error.WriteLine($"BiTTU: {loaded}/{files.Length} blocklists active");
        return new ContentBlocker
        {
            Rules = rules,
            InjectedCss = string.Join("\n", css.Where(s => s.Length > 0)
                .Select(s => s + " { display: none !important; }")),
            ListsLoaded = loaded,
        };
    }

    // Safari domain triggers use a leading * wildcard: "*.doubleclick.net".
    private static Regex DomainRegex(JsonElement domains)
    {
        var alternatives = domains.EnumerateArray()
            .Select(d => d.GetString() ?? string.Empty)
            .Select(d => Regex.Escape(d).Replace(@"\*", "[^\".]*").Trim())
            .Where(p => p.Length > 0);
        return new Regex("^(?:.*\\.)?(?:" + string.Join("|", alternatives) + ")$",
            RegexOptions.IgnoreCase | RegexOptions.Compiled);
    }
}