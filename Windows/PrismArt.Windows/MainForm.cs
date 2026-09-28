using System.Diagnostics;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Text;
using System.Windows.Forms;

namespace PrismArt.Windows;

internal sealed class MainForm : Form
{
    private static readonly (string Name, int Mode)[] Modes =
    [
        ("Combo", 0), ("Triangle", 1), ("Rectangle", 2), ("Ellipse", 3),
        ("Circle", 4), ("Rotated rectangle", 5), ("Bezier", 6),
        ("Rotated ellipse", 7), ("Polygon", 8)
    ];

    private readonly ComboBox preset = NewCombo("Balanced", "Portrait", "Landscape", "Architecture", "Abstract", "Minimal", "Custom");
    private readonly ComboBox shape = NewCombo(Modes.Select(x => x.Name).ToArray());
    private readonly NumericUpDown count = new() { Minimum = 25, Maximum = 20_000, Increment = 25, Value = 900, Width = 110, ThousandsSeparator = true };
    private readonly TrackBar countSlider = new() { Minimum = 25, Maximum = 20_000, TickFrequency = 2_500, SmallChange = 25, LargeChange = 500, Value = 900, Width = 282 };
    private readonly NumericUpDown opacity = new() { Minimum = 0, Maximum = 255, Value = 128, Width = 110 };
    private readonly ComboBox analysis = NewCombo("128 px · Fast", "256 px · Balanced", "512 px · Detailed", "1024 px · Very detailed");
    private readonly ComboBox output = NewCombo("1024 px", "1536 px", "2048 px", "4096 px", "8192 px");
    private readonly ComboBox format = NewCombo("PNG", "JPEG", "SVG");
    private readonly PictureBox imageView = new() { Dock = DockStyle.Fill, SizeMode = PictureBoxSizeMode.Zoom, BackColor = Color.FromArgb(244, 246, 250) };
    private readonly Label status = new() { Text = "Open or paste an image to begin.", Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft, AutoEllipsis = true };
    private readonly ProgressBar progress = new() { Dock = DockStyle.Fill, Maximum = 100 };
    private readonly Button openButton = NewButton("Open image");
    private readonly Button pasteButton = NewButton("Paste image");
    private readonly Button previewButton = NewButton("Quick preview");
    private readonly Button generateButton = NewButton("Generate full quality");
    private readonly Button cancelButton = NewButton("Cancel");
    private readonly Button toggleButton = NewButton("Show original");
    private readonly Panel settingsPanel = new() { Dock = DockStyle.Fill, AutoScroll = true, BackColor = Color.FromArgb(249, 250, 252) };
    private Image? sourceImage;
    private Image? artworkImage;
    private CancellationTokenSource? cancellation;
    private Process? activeProcess;
    private bool showingOriginal;
    private bool applyingPreset;

    internal MainForm()
    {
        Text = "PrismArt for Windows";
        MinimumSize = new Size(920, 660);
        Size = new Size(1200, 790);
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Segoe UI", 10);
        BackColor = Color.White;
        BuildLayout();
        WireEvents();
        ApplyPreset(0);
        UpdateButtons(false);
    }

    private static ComboBox NewCombo(params string[] values)
    {
        var control = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 282 };
        control.Items.AddRange(values.Cast<object>().ToArray());
        return control;
    }

    private static Button NewButton(string text) => new()
    {
        Text = text, AutoSize = true, Padding = new Padding(10, 5, 10, 5),
        Margin = new Padding(4)
    };

    private static Label FieldLabel(string text) => new()
    {
        Text = text, AutoSize = true, Font = new Font("Segoe UI", 9, FontStyle.Bold),
        ForeColor = Color.FromArgb(59, 67, 80), Margin = new Padding(4, 10, 4, 2)
    };

    private void BuildLayout()
    {
        var split = new SplitContainer { Dock = DockStyle.Fill, SplitterDistance = 350, FixedPanel = FixedPanel.Panel1 };
        Controls.Add(split);
        split.Panel1.Controls.Add(settingsPanel);

        var fields = new FlowLayoutPanel
        {
            FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoScroll = true,
            Dock = DockStyle.Fill, Padding = new Padding(18, 16, 10, 14)
        };
        settingsPanel.Controls.Add(fields);
        var title = new Label { Text = "PrismArt", Font = new Font("Segoe UI", 19, FontStyle.Bold), AutoSize = true, Margin = new Padding(4, 0, 4, 3) };
        fields.Controls.Add(title);
        fields.Controls.Add(new Label { Text = "Turn photos into geometric artwork locally.", AutoSize = true, ForeColor = Color.DimGray, Margin = new Padding(4, 0, 4, 12) });
        fields.Controls.Add(FieldLabel("Preset")); fields.Controls.Add(preset);
        fields.Controls.Add(FieldLabel("Shape")); fields.Controls.Add(shape);
        fields.Controls.Add(FieldLabel("Shapes · 25–20,000"));
        fields.Controls.Add(count); fields.Controls.Add(countSlider);
        fields.Controls.Add(FieldLabel("Opacity · 0 means automatic")); fields.Controls.Add(opacity);
        fields.Controls.Add(FieldLabel("Analysis size")); fields.Controls.Add(analysis);
        fields.Controls.Add(FieldLabel("Output size")); fields.Controls.Add(output);
        fields.Controls.Add(FieldLabel("Export format")); fields.Controls.Add(format);
        fields.Controls.Add(new Label
        {
            Text = "More shapes and higher analysis sizes preserve detail but can take much longer. Bezier at high counts may look like dense linework.",
            Width = 285, Height = 68, ForeColor = Color.DimGray, Margin = new Padding(4, 16, 4, 8)
        });
        fields.Controls.Add(generateButton);
        fields.Controls.Add(previewButton);
        fields.Controls.Add(cancelButton);

        var right = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, ColumnCount = 1, Padding = new Padding(16) };
        right.RowStyles.Add(new RowStyle(SizeType.Absolute, 52));
        right.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        right.RowStyles.Add(new RowStyle(SizeType.Absolute, 54));
        split.Panel2.Controls.Add(right);
        var toolbar = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.LeftToRight, WrapContents = false };
        toolbar.Controls.AddRange([openButton, pasteButton, toggleButton]);
        right.Controls.Add(toolbar, 0, 0);
        right.Controls.Add(imageView, 0, 1);
        var footer = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2 };
        footer.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        footer.RowStyles.Add(new RowStyle(SizeType.Absolute, 7));
        footer.Controls.Add(status, 0, 0);
        footer.Controls.Add(progress, 0, 1);
        right.Controls.Add(footer, 0, 2);
    }

    private void WireEvents()
    {
        openButton.Click += (_, _) => OpenImage();
        pasteButton.Click += (_, _) => PasteImage();
        previewButton.Click += async (_, _) => await RenderAsync(quick: true);
        generateButton.Click += async (_, _) => await RenderAsync(quick: false);
        cancelButton.Click += (_, _) => CancelRender();
        toggleButton.Click += (_, _) => { showingOriginal = !showingOriginal; UpdateImageView(); };
        preset.SelectedIndexChanged += (_, _) => { if (preset.SelectedIndex is >= 0 and < 6) ApplyPreset(preset.SelectedIndex); };
        count.ValueChanged += (_, _) =>
        {
            if (countSlider.Value != (int)count.Value) countSlider.Value = (int)count.Value;
            MarkCustom();
        };
        countSlider.ValueChanged += (_, _) => count.Value = countSlider.Value;
        shape.SelectedIndexChanged += (_, _) => MarkCustom();
        opacity.ValueChanged += (_, _) => MarkCustom();
        analysis.SelectedIndexChanged += (_, _) => MarkCustom();
        output.SelectedIndexChanged += (_, _) => MarkCustom();
        format.SelectedIndexChanged += (_, _) => MarkCustom();
        AllowDrop = true;
        DragEnter += (_, e) => e.Effect = e.Data?.GetDataPresent(DataFormats.FileDrop) == true ? DragDropEffects.Copy : DragDropEffects.None;
        DragDrop += (_, e) =>
        {
            if (e.Data?.GetData(DataFormats.FileDrop) is string[] paths && paths.Length > 0) LoadImage(paths[0]);
        };
        FormClosing += (_, _) => CancelRender();
    }

    private void ApplyPreset(int index)
    {
        applyingPreset = true;
        (int mode, int shapes, int alpha, int size) = index switch
        {
            1 => (1, 1_400, 112, 512),
            2 => (8, 1_100, 144, 512),
            3 => (5, 1_100, 150, 512),
            4 => (0, 900, 104, 512),
            5 => (4, 80, 160, 256),
            _ => (1, 900, 128, 512)
        };
        shape.SelectedIndex = mode;
        count.Value = shapes;
        opacity.Value = alpha;
        analysis.SelectedIndex = size == 256 ? 1 : 2;
        output.SelectedIndex = index == 5 ? 1 : 2;
        if (format.SelectedIndex < 0) format.SelectedIndex = 0;
        preset.SelectedIndex = index;
        applyingPreset = false;
    }

    private void MarkCustom()
    {
        if (!applyingPreset && preset.SelectedIndex >= 0 && preset.SelectedIndex != 6)
            preset.SelectedIndex = 6;
    }

    private void OpenImage()
    {
        using var dialog = new OpenFileDialog
        {
            Title = "Open an image", Filter = "Images|*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.tif;*.tiff;*.webp|All files|*.*"
        };
        if (dialog.ShowDialog(this) == DialogResult.OK) LoadImage(dialog.FileName);
    }

    private void PasteImage()
    {
        try
        {
            var image = Clipboard.GetImage();
            if (image is null) { MessageBox.Show(this, "The clipboard does not contain an image."); return; }
            ReplaceSource(new Bitmap(image), "Pasted image");
            image.Dispose();
        }
        catch (Exception ex) { MessageBox.Show(this, ex.Message, "Paste failed"); }
    }

    private void LoadImage(string path)
    {
        try
        {
            using var original = Image.FromFile(path);
            var copy = new Bitmap(original);
            ApplyOrientation(copy, original);
            ReplaceSource(copy, Path.GetFileName(path));
        }
        catch (Exception ex) { MessageBox.Show(this, ex.Message, "Could not open image"); }
    }

    private static void ApplyOrientation(Bitmap copy, Image original)
    {
        const int orientationId = 0x0112;
        if (!original.PropertyIdList.Contains(orientationId)) return;
        var bytes = original.GetPropertyItem(orientationId)?.Value;
        if (bytes is null || bytes.Length < 2) return;
        var orientation = BitConverter.ToUInt16(bytes, 0);
        var rotation = orientation switch
        {
            2 => RotateFlipType.RotateNoneFlipX, 3 => RotateFlipType.Rotate180FlipNone,
            4 => RotateFlipType.Rotate180FlipX, 5 => RotateFlipType.Rotate90FlipX,
            6 => RotateFlipType.Rotate90FlipNone, 7 => RotateFlipType.Rotate270FlipX,
            8 => RotateFlipType.Rotate270FlipNone, _ => RotateFlipType.RotateNoneFlipNone
        };
        copy.RotateFlip(rotation);
    }

    private void ReplaceSource(Image image, string name)
    {
        sourceImage?.Dispose(); artworkImage?.Dispose();
        sourceImage = image; artworkImage = null; showingOriginal = true;
        UpdateImageView();
        status.Text = $"{name} · {image.Width} × {image.Height} · ready";
        UpdateButtons(false);
    }

    private void UpdateImageView()
    {
        imageView.Image = showingOriginal || artworkImage is null ? sourceImage : artworkImage;
        toggleButton.Text = showingOriginal ? "Show artwork" : "Show original";
        toggleButton.Enabled = artworkImage is not null;
    }

    private void UpdateButtons(bool busy)
    {
        settingsPanel.Enabled = !busy;
        openButton.Enabled = !busy;
        pasteButton.Enabled = !busy;
        previewButton.Enabled = !busy && sourceImage is not null;
        generateButton.Enabled = !busy && sourceImage is not null;
        cancelButton.Enabled = busy;
    }

    private async Task RenderAsync(bool quick)
    {
        if (sourceImage is null || cancellation is not null) return;
        var extension = format.SelectedIndex switch { 1 => "jpg", 2 => "svg", _ => "png" };
        string? destination = null;
        if (!quick)
        {
            using var dialog = new SaveFileDialog
            {
                Title = "Save PrismArt artwork", Filter = extension switch
                {
                    "jpg" => "JPEG image|*.jpg", "svg" => "SVG vector|*.svg", _ => "PNG image|*.png"
                },
                DefaultExt = extension,
                AddExtension = true,
                FileName = $"prismart-{DateTime.Now:yyyyMMdd-HHmmss}.{extension}"
            };
            if (dialog.ShowDialog(this) != DialogResult.OK) return;
            destination = dialog.FileName;
        }

        int shapes = quick ? Math.Min(180, Math.Max(64, (int)count.Value / 5)) : (int)count.Value;
        int inputSize = quick ? Math.Min(256, AnalysisSize()) : AnalysisSize();
        int outputSize = quick ? Math.Min(1536, OutputSize()) : OutputSize();
        int alpha = (int)opacity.Value;
        int mode = Modes[Math.Max(0, shape.SelectedIndex)].Mode;
        var work = Path.Combine(Path.GetTempPath(), "PrismArt-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(work);
        cancellation = new CancellationTokenSource();
        UpdateButtons(true);
        progress.Value = 0;
        status.Text = quick ? "Building quick preview…" : $"Rendering {shapes:N0} shapes…";
        try
        {
            var input = Path.Combine(work, "input.png");
            SaveWorkingImage(sourceImage, input, inputSize);
            var result = Path.Combine(work, "result." + (quick ? "png" : extension));
            var display = quick || extension == "png" ? result : Path.Combine(work, "display.png");
            await RunEngineAsync(input, result, display, mode, shapes, alpha, inputSize, outputSize, cancellation.Token);
            cancellation.Token.ThrowIfCancellationRequested();
            var preview = LoadDisplayImage(display);
            if (destination is not null) File.Copy(result, destination, overwrite: true);
            artworkImage?.Dispose(); artworkImage = preview;
            showingOriginal = false;
            UpdateImageView();
            progress.Value = 100;
            status.Text = quick ? "Preview ready · generate for full quality" : $"Saved: {destination}";
        }
        catch (OperationCanceledException) { status.Text = "Render cancelled."; }
        catch (Exception ex)
        {
            status.Text = "Render failed.";
            MessageBox.Show(this, ex.Message, "PrismArt render failed", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            activeProcess = null;
            cancellation.Dispose(); cancellation = null;
            UpdateButtons(false);
            try { Directory.Delete(work, recursive: true); } catch { /* Temporary files can be cleared by Windows. */ }
        }
    }

    private int AnalysisSize() => new[] { 128, 256, 512, 1024 }[Math.Max(0, analysis.SelectedIndex)];
    private int OutputSize() => new[] { 1024, 1536, 2048, 4096, 8192 }[Math.Max(0, output.SelectedIndex)];

    private static void SaveWorkingImage(Image original, string path, int maxSize)
    {
        var scale = Math.Min(1.0, (double)maxSize / Math.Max(original.Width, original.Height));
        var width = Math.Max(1, (int)Math.Round(original.Width * scale));
        var height = Math.Max(1, (int)Math.Round(original.Height * scale));
        using var bitmap = new Bitmap(width, height, PixelFormat.Format32bppArgb);
        using (var graphics = Graphics.FromImage(bitmap))
        {
            graphics.Clear(Color.White);
            graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
            graphics.CompositingQuality = CompositingQuality.HighQuality;
            graphics.SmoothingMode = SmoothingMode.HighQuality;
            graphics.DrawImage(original, new Rectangle(0, 0, width, height));
        }
        bitmap.Save(path, ImageFormat.Png);
    }

    private static Image LoadDisplayImage(string path)
    {
        using var full = Image.FromFile(path);
        var scale = Math.Min(1.0, 1800.0 / Math.Max(full.Width, full.Height));
        var width = Math.Max(1, (int)Math.Round(full.Width * scale));
        var height = Math.Max(1, (int)Math.Round(full.Height * scale));
        var preview = new Bitmap(width, height);
        using var graphics = Graphics.FromImage(preview);
        graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
        graphics.DrawImage(full, 0, 0, width, height);
        return preview;
    }

    private async Task RunEngineAsync(string input, string result, string display, int mode, int shapes, int alpha, int inputSize, int outputSize, CancellationToken token)
    {
        var engine = Path.Combine(AppContext.BaseDirectory, "primitive.exe");
        if (!File.Exists(engine)) throw new FileNotFoundException("primitive.exe is missing from the PrismArt folder.", engine);
        using var process = new Process();
        var start = new ProcessStartInfo(engine)
        {
            UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true,
            RedirectStandardError = true, WorkingDirectory = Path.GetDirectoryName(input)!
        };
        foreach (var arg in new[] { "-i", input, "-n", shapes.ToString(), "-m", mode.ToString(), "-a", alpha.ToString(), "-r", inputSize.ToString(), "-s", outputSize.ToString(), "-j", "0", "-o", result })
            start.ArgumentList.Add(arg);
        if (display != result) { start.ArgumentList.Add("-o"); start.ArgumentList.Add(display); }
        start.ArgumentList.Add("-v");
        process.StartInfo = start;
        var errors = new StringBuilder();
        var logGate = new object();
        int lastPercent = -1;
        void HandleLine(string? line)
        {
            if (line is null) return;
            lock (logGate)
            {
                errors.AppendLine(line);
                if (errors.Length > 8000) errors.Remove(0, errors.Length - 6000);
            }
            var colon = line.IndexOf(':');
            if (colon <= 0 || !int.TryParse(line[..colon].Trim(), out var step)) return;
            var percent = Math.Clamp(step * 100 / shapes, 0, 100);
            lock (logGate)
            {
                if (percent <= lastPercent) return;
                lastPercent = percent;
            }
            if (!IsDisposed && IsHandleCreated)
                BeginInvoke((Action)(() => { progress.Value = percent; status.Text = $"Drawing shape {step:N0} of {shapes:N0}…"; }));
        }
        process.OutputDataReceived += (_, e) => HandleLine(e.Data);
        process.ErrorDataReceived += (_, e) => HandleLine(e.Data);
        if (!process.Start()) throw new InvalidOperationException("Could not start the rendering engine.");
        activeProcess = process;
        process.BeginOutputReadLine(); process.BeginErrorReadLine();
        try { await process.WaitForExitAsync(token); }
        catch (OperationCanceledException)
        {
            if (!process.HasExited) process.Kill(entireProcessTree: true);
            await process.WaitForExitAsync();
            throw;
        }
        if (process.ExitCode != 0)
        {
            string log;
            lock (logGate) log = errors.ToString();
            throw new InvalidOperationException($"Primitive exited with code {process.ExitCode}.\n{log}");
        }
        if (!File.Exists(result) || !File.Exists(display))
            throw new IOException("The renderer finished but did not produce the expected output files.");
    }

    private void CancelRender()
    {
        cancellation?.Cancel();
        try { if (activeProcess is { HasExited: false }) activeProcess.Kill(entireProcessTree: true); }
        catch (InvalidOperationException) { }
    }
}
