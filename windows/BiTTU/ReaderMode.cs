namespace BiTTU;

using System.Text.Json;

// Port of Sources/BiTTU/ReaderMode.swift: extracts the main text of the
// current page and shows it in a clean, distraction-free window.
public static class ReaderMode
{
    private static Form? window;

    private const string ExtractionJs = """
    (function() {
      var candidates = ['article', 'main', '[role="main"]', '#content', '.post', '.entry-content'];
      var best = null;
      for (var i = 0; i < candidates.length; i++) {
        var el = document.querySelector(candidates[i]);
        if (el && el.innerText && el.innerText.length > (best ? best.innerText.length : 800)) { best = el; }
      }
      var text = (best || document.body).innerText || '';
      return JSON.stringify({ title: document.title, text: text });
    })()
    """;

    public static void Toggle(Microsoft.Web.WebView2.WinForms.WebView2 webView, string fallbackTitle)
    {
        if (window is { IsDisposed: false } visible)
        {
            visible.Close();
            return;
        }
        Show(webView, fallbackTitle);
    }

    private static async void Show(Microsoft.Web.WebView2.WinForms.WebView2 webView, string fallbackTitle)
    {
        if (webView.CoreWebView2 is not { } core) return;
        string raw;
        try
        {
            raw = await core.ExecuteScriptAsync(ExtractionJs);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("BiTTU reader mode: extraction failed: " + ex.Message);
            return;
        }

        string? title = null;
        string? text = null;
        try
        {
            using var doc = JsonDocument.Parse(raw);
            title = doc.RootElement.GetProperty("title").GetString();
            text = doc.RootElement.GetProperty("text").GetString();
        }
        catch { /* fall through to the guard below */ }

        if (string.IsNullOrEmpty(text))
        {
            Console.Error.WriteLine("BiTTU reader mode: nothing to extract on " + core.Source);
            return;
        }

        Present(title: string.IsNullOrEmpty(title) ? fallbackTitle : title!,
               url: core.Source, text: text!);
    }

    private static void Present(string title, string url, string text)
    {
        window?.Dispose();
        window = new Form
        {
            Text = title,
            ClientSize = new Size(640, 720),
            StartPosition = FormStartPosition.CenterParent,
            BackColor = Theme.Background,
        };
        Theme.Apply(window);

        var layout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 4,
            Padding = new Padding(24, 20, 24, 20),
        };
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));

        var eyebrow = Theme.Eyebrow("Reader · cleaned text");
        var header = new Label
        {
            Text = title,
            Font = Theme.Mono(14f, FontStyle.Bold),
            ForeColor = Theme.Heading,
            AutoSize = true,
            MaximumSize = new Size(592, 0),
            Padding = new Padding(0, 0, 0, 4),
        };
        var source = new Label
        {
            Text = url,
            Font = Theme.Mono(8f),
            ForeColor = Theme.Muted,
            AutoSize = true,
            MaximumSize = new Size(592, 0),
            Padding = new Padding(0, 0, 0, 10),
        };
        var body = new TextBox
        {
            Text = text,
            Multiline = true,
            ReadOnly = true,
            ScrollBars = ScrollBars.Vertical,
            Dock = DockStyle.Fill,
            Font = Theme.Mono(10.5f),
            BorderStyle = BorderStyle.None,
            BackColor = Theme.Background,
            ForeColor = Theme.Foreground,
        };

        layout.Controls.Add(eyebrow, 0, 0);
        layout.Controls.Add(header, 0, 1);
        layout.Controls.Add(source, 0, 2);
        layout.Controls.Add(body, 0, 3);
        window.Controls.Add(layout);
        window.StartPosition = FormStartPosition.CenterParent;
        window.Show();
    }
}