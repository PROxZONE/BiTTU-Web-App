namespace BiTTU;

using Microsoft.Web.WebView2.Core;

// Port of Sources/BiTTU/Downloads.swift: downloads go to ~/Downloads under a
// non-colliding name, progress is tracked per item and a Downloads window
// mirrors the macOS panel.
public sealed class DownloadManager
{
    public sealed record Item
    {
        public required string Filename { get; set; }
        public required string Url { get; init; }
        public long ExpectedBytes { get; init; }
        public long ReceivedBytes { get; set; }
        public bool Finished { get; set; }
        public bool Failed { get; set; }
        public string? Destination { get; set; }
    }

    private static readonly DownloadManager instance = new();
    public static DownloadManager Shared => instance;

    public List<Item> Items { get; } = new();
    public event Action? Changed;

    private Form? downloadsWindow;
    private Label summaryLabel = new();

    public void StartDownload(CoreWebView2DownloadOperation download)
    {
        var name = string.IsNullOrEmpty(download.ResultFilePath)
            ? "download"
            : Path.GetFileName(download.ResultFilePath);
        var item = new Item
        {
            Filename = name,
            Url = download.Uri ?? "unknown",
            ExpectedBytes = (long)download.TotalBytesToReceive,
        };
        Items.Add(item);
        download.BytesReceivedChanged += (_, _) =>
        {
            item.ReceivedBytes = (long)download.BytesReceived;
            OnChanged();
        };
        download.StateChanged += (_, _) =>
        {
            if (download.State == CoreWebView2DownloadState.Completed)
            {
                item.Finished = true;
                item.ReceivedBytes = (long)download.BytesReceived;
            }
            else if (download.State == CoreWebView2DownloadState.Interrupted)
            {
                item.Failed = true;
                Console.Error.WriteLine("BiTTU download failed: " + download.InterruptReason);
            }
            OnChanged();
        };
        item.Destination = DestinationFor(name, item);
        ShowWindow();
        OnChanged();
    }

    // Same naming scheme as decideDestinationUsing: clean the filename, then
    // append " (2)", " (3)", ... until it does not collide.
    public string DestinationFor(string suggestedFilename, Item item)
    {
        var downloadsDir = Path.Combine(
            System.Environment.GetFolderPath(System.Environment.SpecialFolder.UserProfile), "Downloads");
        Directory.CreateDirectory(downloadsDir);

        var clean = suggestedFilename.Replace('/', '-');
        var ext = Path.GetExtension(clean);
        var baseName = Path.GetFileNameWithoutExtension(clean);
        var bump = 1;
        var name = clean;
        while (File.Exists(Path.Combine(downloadsDir, name)))
        {
            name = ext.Length == 0
                ? baseName + " (" + bump + ")"
                : baseName + " (" + bump + ")" + ext;
            bump += 1;
        }
        var target = Path.Combine(downloadsDir, name);
        item.Destination = target;
        item.Filename = Path.GetFileName(target);
        return target;
    }

    private void OnChanged()
    {
        foreach (var control in new Form?[] { downloadsWindow })
        {
            if (control?.IsHandleCreated == true)
            {
                control.BeginInvoke(Refresh);
            }
        }
        Changed?.Invoke();
    }

    public void ShowWindow()
    {
        if (downloadsWindow is { IsDisposed: false } window)
        {
            window.BringToFront();
            window.Activate();
            Refresh();
            return;
        }

        downloadsWindow = new Form
        {
            Text = "Downloads",
            ClientSize = new Size(460, 240),
            StartPosition = FormStartPosition.CenterParent,
            MaximizeBox = false,
        };
        Theme.Apply(downloadsWindow);
        downloadsWindow.BackColor = Theme.Background;
        downloadsWindow.Padding = new Padding(12, 0, 12, 12);

        summaryLabel = new Label
        {
            Text = "No downloads yet.",
            AutoSize = false,
            Dock = DockStyle.Fill,
            Padding = new Padding(16, 12, 16, 12),
        };
        Theme.StyleLabel(summaryLabel, muted: false);
        var eyebrow = Theme.Eyebrow("Downloads · local only");
        eyebrow.Dock = DockStyle.Top;
        eyebrow.AutoSize = false;
        eyebrow.Height = 30;
        eyebrow.Padding = new Padding(16, 6, 0, 0);
        var refresh = new Button
        {
            Text = "Refresh",
            Dock = DockStyle.Bottom,
            Height = 34,
        };
        Theme.StyleButton(refresh);
        refresh.Click += (_, _) => Refresh();
        downloadsWindow.Controls.Add(summaryLabel);
        downloadsWindow.Controls.Add(eyebrow);
        downloadsWindow.Controls.Add(refresh);

        Refresh();
        downloadsWindow.Show();
    }

    // Same wording as the macOS panel.
    public void Refresh()
    {
        if (Items.Count == 0)
        {
            summaryLabel.Text = "No downloads yet.";
            return;
        }
        var lines = Items.Select(item =>
        {
            var line = item.Filename + " — ";
            if (item.Failed)
            {
                line += "failed";
            }
            else if (item.Finished)
            {
                line += "saved to " + (item.Destination ?? "unknown");
            }
            else
            {
                line += FormatBytes(item.ReceivedBytes) + " / "
                    + (item.ExpectedBytes > 0 ? FormatBytes(item.ExpectedBytes) : "?");
            }
            return line;
        });
        summaryLabel.Text = string.Join(Environment.NewLine, lines);
    }

    private static string FormatBytes(long bytes)
    {
        string[] units = { "B", "KB", "MB", "GB", "TB" };
        double value = bytes;
        var unit = 0;
        while (value >= 1000 && unit < units.Length - 1)
        {
            value /= 1000;
            unit += 1;
        }
        return value.ToString("0.##") + " " + units[unit];
    }
}
