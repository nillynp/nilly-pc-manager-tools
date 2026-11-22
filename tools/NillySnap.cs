// Nilly QuickSnap — Ultra-Fast Screen Capture, Pixel Ruler & Quick Markup (0 MB when closed!)
// Backup / side-by-side alternative to Windows Snipping Tool (never touches Win+Shift+S!)
// Features: Drag Region + WxH Pixel Ruler, Fullscreen (F), Arrow (A), Box (R), Pen (P), Highlighter (H),
//           Blur/Pixelate (B), Undo (Ctrl+Z), Copy PNG (Enter/Ctrl+C), Save PNG (Ctrl+S), Delay (-delay N)
// created by Nilly graphics (Sotiris Christos) — https://nillygraphics.com/

using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace NillySnap {
    internal enum DrawTool { None, Arrow, Rect, Pen, Highlight, Blur }

    internal class MarkupItem {
        public DrawTool Tool;
        public Color Color;
        public Point Start;
        public Point End;
        public List<Point> Points;
    }

    internal sealed class SnapForm : Form {
        [DllImport("user32.dll")] private static extern bool SetProcessDPIAware();
        [DllImport("user32.dll")] private static extern IntPtr GetDC(IntPtr hwnd);
        [DllImport("user32.dll")] private static extern int ReleaseDC(IntPtr hwnd, IntPtr hdc);
        [DllImport("gdi32.dll")]  private static extern bool BitBlt(IntPtr dst, int x, int y, int w, int h, IntPtr src, int sx, int sy, int rop);

        private Bitmap _screenBmp;
        private Rectangle _vScreen;
        private bool _selecting = false;
        private bool _hasSelection = false;
        private Point _selStart;
        private Point _selCurr;
        private Rectangle _selRect;

        private DrawTool _activeTool = DrawTool.Arrow;
        private Color _activeColor = Color.FromArgb(244, 63, 94); // Crisp Rose Red
        private bool _drawing = false;
        private MarkupItem _currentItem = null;
        private readonly List<MarkupItem> _items = new List<MarkupItem>();

        private Panel _toolbar;
        private readonly Dictionary<DrawTool, Button> _toolBtns = new Dictionary<DrawTool, Button>();
        private readonly List<Button> _colorBtns = new List<Button>();
        private string _outPreviewPath;
        private bool _editMode;

        public bool InitOk { get; private set; }

        public SnapForm(int delaySec, string outPreviewPath, bool editMode) {
            _outPreviewPath = outPreviewPath;
            _editMode = editMode;
            try { SetProcessDPIAware(); } catch {}

            if (delaySec > 0) Thread.Sleep(delaySec * 1000);

            _vScreen = SystemInformation.VirtualScreen;
            _screenBmp = CaptureDesktop(_vScreen);
            if (_screenBmp == null) {
                InitOk = false;
                return;
            }
            InitOk = true;

            this.FormBorderStyle = FormBorderStyle.None;
            this.StartPosition = FormStartPosition.Manual;
            this.Bounds = _vScreen;
            this.TopMost = true;
            this.ShowInTaskbar = false;
            this.DoubleBuffered = true;
            this.Cursor = Cursors.Cross;
            this.KeyPreview = true;
            this.Text = "Nilly QuickSnap";

            BuildToolbar();
        }

        private static Bitmap CaptureDesktop(Rectangle bounds) {
            if (bounds.Width <= 0 || bounds.Height <= 0) return null;
            Bitmap bmp = new Bitmap(bounds.Width, bounds.Height, PixelFormat.Format32bppArgb);
            try {
                IntPtr srcDc = GetDC(IntPtr.Zero);
                if (srcDc != IntPtr.Zero) {
                    try {
                        using (Graphics g = Graphics.FromImage(bmp)) {
                            IntPtr dstDc = g.GetHdc();
                            try {
                                if (BitBlt(dstDc, 0, 0, bounds.Width, bounds.Height, srcDc, bounds.Left, bounds.Top, 0x00CC0020 | 0x40000000))
                                    return bmp;
                            } finally { g.ReleaseHdc(dstDc); }
                        }
                    } finally { ReleaseDC(IntPtr.Zero, srcDc); }
                }
            } catch {}
            try {
                using (Graphics g = Graphics.FromImage(bmp)) g.CopyFromScreen(bounds.Left, bounds.Top, 0, 0, bounds.Size);
                return bmp;
            } catch { bmp.Dispose(); return null; }
        }

        private Button MakeBtn(string text, string tip, int width, Color bg, Color fg, EventHandler onClick) {
            Button b = new Button();
            b.Text = text;
            b.Width = width;
            b.Height = 28;
            b.FlatStyle = FlatStyle.Flat;
            b.FlatAppearance.BorderColor = Color.FromArgb(44, 56, 77);
            b.FlatAppearance.BorderSize = 1;
            b.BackColor = bg;
            b.ForeColor = fg;
            b.Font = new Font("Segoe UI", 8.5f, FontStyle.Bold);
            b.Cursor = Cursors.Hand;
            b.Margin = new Padding(2, 3, 2, 3);
            b.TabStop = false;
            b.Click += onClick;
            ToolTip tt = new ToolTip();
            tt.SetToolTip(b, tip);
            return b;
        }

        private void BuildToolbar() {
            _toolbar = new Panel();
            _toolbar.Height = 38;
            _toolbar.BackColor = Color.FromArgb(245, 15, 20, 31);
            _toolbar.Padding = new Padding(6, 2, 6, 2);
            _toolbar.Visible = false;
            _toolbar.Cursor = Cursors.Default;

            FlowLayoutPanel flow = new FlowLayoutPanel();
            flow.Dock = DockStyle.Fill;
            flow.WrapContents = false;
            flow.BackColor = Color.Transparent;

            AddToolBtn(flow, DrawTool.Arrow,     "↗ Βέλος",   "Βέλος (A)", 68);
            AddToolBtn(flow, DrawTool.Rect,      "▢ Πλαίσιο", "Πλαίσιο (R)", 74);
            AddToolBtn(flow, DrawTool.Pen,       "✎ Στυλό",   "Ελεύθερη σχεδίαση (P)", 68);
            AddToolBtn(flow, DrawTool.Highlight, "▮ Marker",  "Μαρκαδόρος (H)", 70);
            AddToolBtn(flow, DrawTool.Blur,      "▦ Blur",    "Θόλωμα / Απόκρυψη ευαίσθητων στοιχείων (B)", 60);

            Color[] palette = new Color[] {
                Color.FromArgb(244, 63, 94),  // Red
                Color.FromArgb(56, 189, 248), // Cyan
                Color.FromArgb(250, 204, 21), // Yellow
                Color.FromArgb(34, 197, 94),  // Green
                Color.White
            };
            foreach (Color c in palette) {
                Color col = c;
                Button cb = new Button();
                cb.Width = 22; cb.Height = 22;
                cb.FlatStyle = FlatStyle.Flat;
                cb.FlatAppearance.BorderSize = 2;
                cb.BackColor = col;
                cb.Margin = new Padding(2, 6, 2, 3);
                cb.Cursor = Cursors.Hand;
                cb.TabStop = false;
                cb.Tag = col;
                cb.Click += delegate { _activeColor = col; UpdateToolbarStyles(); };
                _colorBtns.Add(cb);
                flow.Controls.Add(cb);
            }

            Button btnUndo = MakeBtn("↶ Undo", "Αναίρεση (Ctrl+Z)", 60, Color.FromArgb(28, 36, 51), Color.FromArgb(226, 232, 240), delegate { DoUndo(); });
            Button btnCopy = MakeBtn("✓ Copy", "Αντιγραφή PNG & Κλείσιμο (Enter / Ctrl+C)", 68, Color.FromArgb(56, 189, 248), Color.FromArgb(7, 34, 53), delegate { DoCopyAndClose(); });
            Button btnSave = MakeBtn("💾 PNG",  "Αποθήκευση PNG (Ctrl+S)", 62, Color.FromArgb(16, 185, 129), Color.FromArgb(3, 34, 25), delegate { DoSaveAndClose(); });
            Button btnEsc  = MakeBtn("✕",      "Ακύρωση (Esc)", 30, Color.FromArgb(52, 24, 33), Color.FromArgb(253, 164, 175), delegate { this.Close(); });

            flow.Controls.Add(btnUndo);
            flow.Controls.Add(btnCopy);
            flow.Controls.Add(btnSave);
            flow.Controls.Add(btnEsc);

            _toolbar.Controls.Add(flow);
            _toolbar.Width = 735;
            this.Controls.Add(_toolbar);
            UpdateToolbarStyles();
        }

        private void AddToolBtn(FlowLayoutPanel flow, DrawTool t, string label, string tip, int width) {
            Button b = MakeBtn(label, tip, width, Color.FromArgb(28, 36, 51), Color.FromArgb(226, 232, 240), delegate {
                _activeTool = t;
                UpdateToolbarStyles();
            });
            _toolBtns[t] = b;
            flow.Controls.Add(b);
        }

        private void UpdateToolbarStyles() {
            foreach (KeyValuePair<DrawTool, Button> kv in _toolBtns) {
                if (kv.Key == _activeTool) {
                    kv.Value.BackColor = Color.FromArgb(24, 58, 95);
                    kv.Value.ForeColor = Color.FromArgb(56, 189, 248);
                    kv.Value.FlatAppearance.BorderColor = Color.FromArgb(56, 189, 248);
                } else {
                    kv.Value.BackColor = Color.FromArgb(28, 36, 51);
                    kv.Value.ForeColor = Color.FromArgb(226, 232, 240);
                    kv.Value.FlatAppearance.BorderColor = Color.FromArgb(44, 56, 77);
                }
            }
            foreach (Button cb in _colorBtns) {
                Color c = (Color)cb.Tag;
                cb.FlatAppearance.BorderColor = (c.ToArgb() == _activeColor.ToArgb()) ? Color.White : Color.FromArgb(30, 41, 59);
            }
        }

        private void PositionToolbar() {
            int tx = Math.Max(8, Math.Min(_screenBmp.Width - _toolbar.Width - 8, _selRect.Right - _toolbar.Width));
            int ty = (_selRect.Bottom + 10 + _toolbar.Height <= _screenBmp.Height)
                ? (_selRect.Bottom + 10)
                : Math.Max(8, _selRect.Top - _toolbar.Height - 10);
            _toolbar.Location = new Point(tx, ty);
            _toolbar.Visible = true;
            _toolbar.BringToFront();
        }

        private Rectangle GetDragRect() {
            int x = Math.Min(_selStart.X, _selCurr.X);
            int y = Math.Min(_selStart.Y, _selCurr.Y);
            int w = Math.Abs(_selCurr.X - _selStart.X);
            int h = Math.Abs(_selCurr.Y - _selStart.Y);
            return Rectangle.Intersect(new Rectangle(x, y, w, h), new Rectangle(0, 0, _screenBmp.Width, _screenBmp.Height));
        }

        private Bitmap RenderFinalCrop() {
            Rectangle r = Rectangle.Intersect(_selRect, new Rectangle(0, 0, _screenBmp.Width, _screenBmp.Height));
            if (r.Width < 2 || r.Height < 2) return null;
            Bitmap crop = _screenBmp.Clone(r, PixelFormat.Format32bppArgb);
            using (Graphics g = Graphics.FromImage(crop)) {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                foreach (MarkupItem item in _items) {
                    RenderMarkupItem(g, crop, item, r.Left, r.Top);
                }
            }
            return crop;
        }

        private static void PixelateRegion(Bitmap target, Rectangle rect, int blockSize) {
            Rectangle r = Rectangle.Intersect(rect, new Rectangle(0, 0, target.Width, target.Height));
            if (r.Width < 2 || r.Height < 2) return;
            using (Graphics g = Graphics.FromImage(target)) {
                for (int y = r.Top; y < r.Bottom; y += blockSize) {
                    int bh = Math.Min(blockSize, r.Bottom - y);
                    for (int x = r.Left; x < r.Right; x += blockSize) {
                        int bw = Math.Min(blockSize, r.Right - x);
                        Color sample = target.GetPixel(x + bw / 2, y + bh / 2);
                        using (SolidBrush br = new SolidBrush(sample)) {
                            g.FillRectangle(br, x, y, bw, bh);
                        }
                    }
                }
            }
        }

        private void RenderMarkupItem(Graphics g, Bitmap blurTarget, MarkupItem item, int offX, int offY) {
            if (item == null) return;
            if (item.Tool == DrawTool.Blur) {
                Rectangle br = new Rectangle(
                    Math.Min(item.Start.X, item.End.X) - offX,
                    Math.Min(item.Start.Y, item.End.Y) - offY,
                    Math.Abs(item.End.X - item.Start.X),
                    Math.Abs(item.End.Y - item.Start.Y)
                );
                if (blurTarget != null) {
                    PixelateRegion(blurTarget, br, 10);
                } else {
                    // Live preview on overlay: pixelated crop from _screenBmp!
                    Rectangle srcR = Rectangle.Intersect(br, new Rectangle(0, 0, _screenBmp.Width, _screenBmp.Height));
                    if (srcR.Width >= 4 && srcR.Height >= 4) {
                        using (Bitmap tmp = _screenBmp.Clone(srcR, PixelFormat.Format32bppArgb)) {
                            PixelateRegion(tmp, new Rectangle(0, 0, tmp.Width, tmp.Height), 10);
                            g.DrawImageUnscaled(tmp, srcR.Left, srcR.Top);
                        }
                    }
                }
                return;
            }
            if (item.Tool == DrawTool.Rect) {
                Rectangle rr = new Rectangle(
                    Math.Min(item.Start.X, item.End.X) - offX,
                    Math.Min(item.Start.Y, item.End.Y) - offY,
                    Math.Abs(item.End.X - item.Start.X),
                    Math.Abs(item.End.Y - item.Start.Y)
                );
                using (Pen p = new Pen(item.Color, 3f)) g.DrawRectangle(p, rr);
            } else if (item.Tool == DrawTool.Arrow) {
                Point p1 = new Point(item.Start.X - offX, item.Start.Y - offY);
                Point p2 = new Point(item.End.X - offX, item.End.Y - offY);
                using (Pen p = new Pen(item.Color, 3.5f)) {
                    p.StartCap = LineCap.Round;
                    p.EndCap = LineCap.Round;
                    g.DrawLine(p, p1, p2);
                    double ang = Math.Atan2(p2.Y - p1.Y, p2.X - p1.X);
                    double headLen = 15.0;
                    PointF a1 = new PointF((float)(p2.X - headLen * Math.Cos(ang - Math.PI / 6.5)), (float)(p2.Y - headLen * Math.Sin(ang - Math.PI / 6.5)));
                    PointF a2 = new PointF((float)(p2.X - headLen * Math.Cos(ang + Math.PI / 6.5)), (float)(p2.Y - headLen * Math.Sin(ang + Math.PI / 6.5)));
                    using (SolidBrush br = new SolidBrush(item.Color)) {
                        g.FillPolygon(br, new PointF[] { p2, a1, a2 });
                    }
                }
            } else if ((item.Tool == DrawTool.Pen || item.Tool == DrawTool.Highlight) && item.Points != null && item.Points.Count > 1) {
                Color col = (item.Tool == DrawTool.Highlight) ? Color.FromArgb(110, item.Color) : item.Color;
                float w = (item.Tool == DrawTool.Highlight) ? 16f : 3f;
                Point[] pts = new Point[item.Points.Count];
                for (int i = 0; i < pts.Length; i++) pts[i] = new Point(item.Points[i].X - offX, item.Points[i].Y - offY);
                using (Pen p = new Pen(col, w)) {
                    p.StartCap = LineCap.Round;
                    p.EndCap = LineCap.Round;
                    p.LineJoin = LineJoin.Round;
                    g.DrawLines(p, pts);
                }
            }
        }

        private void WritePreviewIfRequested(Bitmap crop) {
            if (!string.IsNullOrEmpty(_outPreviewPath)) {
                try {
                    crop.Save(_outPreviewPath, ImageFormat.Png);
                    File.WriteAllText(_outPreviewPath + ".meta", string.Format("{0}|{1}|{2}|{3}", _selRect.Width, _selRect.Height, _selRect.X, _selRect.Y));
                } catch {}
            }
        }

        private void DoUndo() {
            if (_items.Count > 0) {
                _items.RemoveAt(_items.Count - 1);
                this.Invalidate();
            }
        }

        private void DoCopyAndClose() {
            if (!_hasSelection) return;
            using (Bitmap crop = RenderFinalCrop()) {
                if (crop != null) {
                    WritePreviewIfRequested(crop);
                    try { Clipboard.SetImage(crop); } catch {}
                }
            }
            this.Close();
        }

        private void DoSaveAndClose() {
            if (!_hasSelection) return;
            using (Bitmap crop = RenderFinalCrop()) {
                if (crop == null) return;
                WritePreviewIfRequested(crop);
                try { Clipboard.SetImage(crop); } catch {}
                this.TopMost = false;
                using (SaveFileDialog dlg = new SaveFileDialog()) {
                    dlg.Filter = "PNG Image (*.png)|*.png";
                    dlg.FileName = "nilly-snap-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".png";
                    if (dlg.ShowDialog(this) == DialogResult.OK) {
                        crop.Save(dlg.FileName, ImageFormat.Png);
                    }
                }
            }
            this.Close();
        }

        protected override void OnShown(EventArgs e) { base.OnShown(e); this.Activate(); this.Focus(); }

        protected override void OnKeyDown(KeyEventArgs e) {
            if (e.KeyCode == Keys.Escape) { this.Close(); return; }
            if (!_hasSelection && e.KeyCode == Keys.F) {
                _selRect = new Rectangle(0, 0, _screenBmp.Width, _screenBmp.Height);
                _hasSelection = true;
                if (_editMode || e.Shift) {
                    PositionToolbar();
                    this.Invalidate();
                } else {
                    DoCopyAndClose();
                }
                return;
            }
            if (_hasSelection) {
                if (e.KeyCode == Keys.Enter || (e.Control && e.KeyCode == Keys.C)) { DoCopyAndClose(); return; }
                if (e.Control && e.KeyCode == Keys.S) { DoSaveAndClose(); return; }
                if (e.Control && e.KeyCode == Keys.Z) { DoUndo(); return; }
                if (e.KeyCode == Keys.A) { _activeTool = DrawTool.Arrow; UpdateToolbarStyles(); }
                else if (e.KeyCode == Keys.R) { _activeTool = DrawTool.Rect; UpdateToolbarStyles(); }
                else if (e.KeyCode == Keys.P) { _activeTool = DrawTool.Pen; UpdateToolbarStyles(); }
                else if (e.KeyCode == Keys.H) { _activeTool = DrawTool.Highlight; UpdateToolbarStyles(); }
                else if (e.KeyCode == Keys.B) { _activeTool = DrawTool.Blur; UpdateToolbarStyles(); }
            }
            base.OnKeyDown(e);
        }

        protected override void OnMouseDown(MouseEventArgs e) {
            if (e.Button == MouseButtons.Right) {
                if (_hasSelection && _items.Count > 0) { DoUndo(); }
                else { this.Close(); }
                return;
            }
            if (e.Button == MouseButtons.Left) {
                if (!_hasSelection) {
                    _selecting = true;
                    _selStart = e.Location;
                    _selCurr = e.Location;
                    this.Invalidate();
                } else if (_selRect.Contains(e.Location)) {
                    _drawing = true;
                    _currentItem = new MarkupItem();
                    _currentItem.Tool = _activeTool;
                    _currentItem.Color = _activeColor;
                    _currentItem.Start = e.Location;
                    _currentItem.End = e.Location;
                    if (_activeTool == DrawTool.Pen || _activeTool == DrawTool.Highlight) {
                        _currentItem.Points = new List<Point>();
                        _currentItem.Points.Add(e.Location);
                    }
                    this.Invalidate();
                }
            }
            base.OnMouseDown(e);
        }

        protected override void OnMouseMove(MouseEventArgs e) {
            if (_selecting) {
                _selCurr = e.Location;
                this.Invalidate();
            } else if (_drawing && _currentItem != null) {
                Point clamped = new Point(
                    Math.Max(_selRect.Left, Math.Min(_selRect.Right, e.X)),
                    Math.Max(_selRect.Top, Math.Min(_selRect.Bottom, e.Y))
                );
                _currentItem.End = clamped;
                if (_currentItem.Points != null) _currentItem.Points.Add(clamped);
                this.Invalidate();
            }
            base.OnMouseMove(e);
        }

        protected override void OnMouseUp(MouseEventArgs e) {
            if (_selecting && e.Button == MouseButtons.Left) {
                _selecting = false;
                Rectangle r = GetDragRect();
                if (r.Width >= 8 && r.Height >= 8) {
                    _selRect = r;
                    _hasSelection = true;
                    bool wantEdit = _editMode || ((Control.ModifierKeys & Keys.Shift) == Keys.Shift);
                    if (wantEdit) {
                        PositionToolbar();
                    } else {
                        DoCopyAndClose();
                        return;
                    }
                }
                this.Invalidate();
            } else if (_drawing && e.Button == MouseButtons.Left) {
                _drawing = false;
                if (_currentItem != null) {
                    _items.Add(_currentItem);
                    _currentItem = null;
                }
                this.Invalidate();
            }
            base.OnMouseUp(e);
        }

        protected override void OnPaint(PaintEventArgs e) {
            if (_screenBmp == null) return;
            Graphics g = e.Graphics;
            g.DrawImageUnscaled(_screenBmp, 0, 0);

            using (SolidBrush dim = new SolidBrush(Color.FromArgb(105, 7, 11, 18))) {
                g.FillRectangle(dim, 0, 0, _screenBmp.Width, _screenBmp.Height);
            }

            Rectangle activeRect = _hasSelection ? _selRect : (_selecting ? GetDragRect() : Rectangle.Empty);
            if (activeRect.Width > 0 && activeRect.Height > 0) {
                g.DrawImage(_screenBmp, activeRect, activeRect, GraphicsUnit.Pixel);

                // Draw committed & in-progress markup clipped to selection
                g.SetClip(activeRect);
                g.SmoothingMode = SmoothingMode.AntiAlias;
                foreach (MarkupItem item in _items) RenderMarkupItem(g, null, item, 0, 0);
                if (_currentItem != null) RenderMarkupItem(g, null, _currentItem, 0, 0);
                g.ResetClip();

                using (Pen p = new Pen(Color.FromArgb(255, 56, 189, 248), 2)) g.DrawRectangle(p, activeRect);

                string ratio = activeRect.Height > 0 ? string.Format("{0:F2}:1", (double)activeRect.Width / activeRect.Height) : "-";
                string badge = _hasSelection
                    ? string.Format("{0} × {1} px ({2})  |  Enter = Copy  |  Ctrl+S = Save  |  Esc = Cancel", activeRect.Width, activeRect.Height, ratio)
                    : string.Format("{0} × {1} px ({2})  |  Άφησε = Άμεσο Copy  |  Shift+Άφησε = Σχεδίαση", activeRect.Width, activeRect.Height, ratio);
                using (Font f = new Font("Consolas", 9.5f, FontStyle.Bold)) {
                    SizeF sz = g.MeasureString(badge, f);
                    int bx = Math.Max(8, Math.Min(_screenBmp.Width - (int)sz.Width - 20, activeRect.Left));
                    int by = (activeRect.Top - 30 > 8) ? (activeRect.Top - 30) : (activeRect.Top + 6);
                    using (SolidBrush bg = new SolidBrush(Color.FromArgb(240, 11, 15, 23)))
                    using (Pen bp = new Pen(Color.FromArgb(255, 56, 189, 248), 1))
                    using (SolidBrush fg = new SolidBrush(Color.FromArgb(248, 250, 252))) {
                        g.FillRectangle(bg, bx, by, sz.Width + 12, 24);
                        g.DrawRectangle(bp, bx, by, sz.Width + 12, 24);
                        g.DrawString(badge, f, fg, bx + 6, by + 4);
                    }
                }
            } else {
                string hint = _editMode
                    ? "Nilly QuickSnap (Σχεδίαση)  •  Σύρε Περιοχή για Βέλος/Πλαίσιο/Blur  |  F = Όλη η Οθόνη  |  Esc = Ακύρωση"
                    : "Nilly QuickSnap  •  Σύρε & Άφησε = Άμεσο Copy (Ctrl+V)  |  Κράτα Shift = Σχεδίαση  |  F = Όλη η Οθόνη  |  Esc = Ακύρωση";
                using (Font f = new Font("Segoe UI", 11f, FontStyle.Bold)) {
                    SizeF sz = g.MeasureString(hint, f);
                    int bx = (_screenBmp.Width - (int)sz.Width) / 2 - 14;
                    using (SolidBrush bg = new SolidBrush(Color.FromArgb(238, 11, 15, 23)))
                    using (Pen bp = new Pen(Color.FromArgb(255, 56, 189, 248), 1))
                    using (SolidBrush fg = new SolidBrush(Color.FromArgb(248, 250, 252))) {
                        g.FillRectangle(bg, bx, 24, sz.Width + 28, 34);
                        g.DrawRectangle(bp, bx, 24, sz.Width + 28, 34);
                        g.DrawString(hint, f, fg, bx + 14, 31);
                    }
                }
            }
        }

        protected override void Dispose(bool disposing) {
            if (disposing && _screenBmp != null) { _screenBmp.Dispose(); _screenBmp = null; }
            base.Dispose(disposing);
        }

        [STAThread]
        public static int Main(string[] args) {
            bool createdNew;
            using (Mutex m = new Mutex(true, "Local\\NillyQuickSnap_SingleInstance", out createdNew)) {
                if (!createdNew) return 0;

                int delaySec = 0;
                string outPath = null;
                bool editMode = false;
                for (int i = 0; i < args.Length; i++) {
                    if (args[i].Equals("-delay", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) {
                        int.TryParse(args[++i], out delaySec);
                    } else if (args[i].Equals("-out", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) {
                        outPath = args[++i];
                    } else if (args[i].Equals("-edit", StringComparison.OrdinalIgnoreCase)) {
                        editMode = true;
                    }
                }

                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                using (SnapForm frm = new SnapForm(delaySec, outPath, editMode)) {
                    if (frm.InitOk) Application.Run(frm);
                }
                return 0;
            }
        }
    }
}
