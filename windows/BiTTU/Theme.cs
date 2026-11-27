namespace BiTTU;

using System.Drawing;
using System.Runtime.InteropServices;

// "Midnight Instrument" — the same dark tokens as Sources/BiTTU/Theme.swift,
// applied to every BiTTU window so the Windows build matches the Mac one.
internal static class Theme
{
    public static readonly Color Background = Color.FromArgb(0x0A, 0x0E, 0x14);
    public static readonly Color Surface = Color.FromArgb(0x11, 0x16, 0x1F);
    public static readonly Color Raised = Color.FromArgb(0x16, 0x1D, 0x28);
    public static readonly Color Border = Color.FromArgb(0x25, 0x30, 0x3D);
    public static readonly Color Foreground = Color.FromArgb(0xDC, 0xE6, 0xF2);
    public static readonly Color Heading = Color.FromArgb(0xF3, 0xF8, 0xFF);
    public static readonly Color Muted = Color.FromArgb(0x8E, 0x9D, 0xB1);
    public static readonly Color Accent = Color.FromArgb(0x5B, 0xE4, 0x9B);
    public static readonly Color AccentInk = Color.FromArgb(0x06, 0x28, 0x1A);
    public static readonly Color Danger = Color.FromArgb(0xFF, 0x7A, 0x85);

    public const int Radius = 6;

    private static readonly Lazy<string> MonoFamilyName = new(() =>
    {
        foreach (var name in new[] { "Cascadia Mono", "Consolas", "Courier New" })
        {
            if (FontFamily.Families.Any(family => family.Name == name)) return name;
        }
        return FontFamily.GenericMonospace.Name;
    });

    public static Font Mono(float size, FontStyle style = FontStyle.Regular) =>
        new(MonoFamilyName.Value, size, style);

    /// Small uppercase mono readout, the Windows twin of Theme.eyebrow on the Mac.
    public static Label Eyebrow(string text) => new()
    {
        Text = text.ToUpperInvariant(),
        AutoSize = true,
        ForeColor = Muted,
        Font = Mono(8.5f, FontStyle.Bold),
    };

    /// Dark window shell: background, text color, dark title bar, readable mono.
    public static void Apply(Form form)
    {
        form.BackColor = Background;
        form.ForeColor = Foreground;
        form.Font = Mono(9.5f);
        if (form.IsHandleCreated) DarkTitleBar(form);
        else form.HandleCreated += (_, _) => DarkTitleBar(form);
    }

    public static void StyleField(TextBox field)
    {
        field.BackColor = Raised;
        field.ForeColor = Foreground;
        field.BorderStyle = BorderStyle.FixedSingle;
        field.Font = Mono(10f);
    }

    public static void StyleButton(Button button, bool primary = false)
    {
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderColor = primary ? Accent : Border;
        button.FlatAppearance.MouseOverBackColor = primary ? Accent : Surface;
        button.BackColor = primary ? Accent : Raised;
        button.ForeColor = primary ? AccentInk : Foreground;
        button.Font = Mono(9f, FontStyle.Bold);
        button.UseVisualStyleBackColor = false;
    }

    public static void StyleList(ListView list)
    {
        list.BackColor = Surface;
        list.ForeColor = Foreground;
        list.BorderStyle = BorderStyle.FixedSingle;
        list.Font = Mono(9.5f);
    }

    public static void StyleLabel(Label label, bool muted = true)
    {
        label.BackColor = Color.Transparent;
        label.ForeColor = muted ? Muted : Foreground;
        label.Font = Mono(9.5f);
    }

    private const int DwmWaUseImmersiveDarkMode = 20;

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);

    private static void DarkTitleBar(Form form)
    {
        try
        {
            var enabled = 1;
            DwmSetWindowAttribute(form.Handle, DwmWaUseImmersiveDarkMode, ref enabled, sizeof(int));
        }
        catch (Exception error) when (error is DllNotFoundException or EntryPointNotFoundException)
        {
            // Older Windows builds keep the light title bar; the client area stays dark.
        }
    }
}

/// Dark context-menu surface (cookie policy) built from the same tokens.
internal sealed class DarkMenuRenderer : ToolStripProfessionalRenderer
{
    public DarkMenuRenderer() : base(new DarkColorTable()) { }
}

internal sealed class DarkColorTable : ProfessionalColorTable
{
    public override Color ToolStripDropDownBackground => Theme.Surface;
    public override Color MenuBorder => Theme.Border;
    public override Color MenuItemBorder => Theme.Accent;
    public override Color MenuItemSelected => Theme.Raised;
    public override Color MenuItemSelectedGradientBegin => Theme.Raised;
    public override Color MenuItemSelectedGradientEnd => Theme.Raised;
    public override Color MenuItemPressedGradientBegin => Theme.Raised;
    public override Color MenuItemPressedGradientEnd => Theme.Raised;
    public override Color ImageMarginGradientBegin => Theme.Surface;
    public override Color ImageMarginGradientMiddle => Theme.Surface;
    public override Color ImageMarginGradientEnd => Theme.Surface;
    public override Color SeparatorDark => Theme.Border;
    public override Color SeparatorLight => Theme.Surface;
}
