// vaultos-mark — Vault.OS desktop mark in C++ (GTK3 + cairo).
// Replaces the Python spinner. Default "boot" plays a short CRT power-on,
// types the overseer line, then goes fully static: no timer, ~0% CPU.
//
// Modes:  --boot (default)  --spin  --pulse  --static
// Config: ~/.config/Vault.OS/overseer   one line, e.g. "XMOB"
//         ~/.config/Vault.OS/desktop-spin  boot|full|pulse|static|off
#include <gtk/gtk.h>
#include <cairo.h>
#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <string>

namespace {

constexpr double kPhosR = 0x1A / 255.0, kPhosG = 0xFF / 255.0, kPhosB = 0x6B / 255.0;
constexpr int kLogoPx = 360;
constexpr int kCaptionH = 64;

enum class Mode { Boot, Spin, Pulse, Static };

std::string home() { const char* h = g_get_home_dir(); return h ? h : "."; }

std::string read_line(const std::string& path, const std::string& fallback) {
  std::ifstream f(path);
  std::string s;
  if (f && std::getline(f, s)) {
    while (!s.empty() && (s.back() == ' ' || s.back() == '\r')) s.pop_back();
    if (!s.empty()) return s;
  }
  return fallback;
}

struct Mark {
  Mode mode = Mode::Boot;
  cairo_surface_t* logo = nullptr;   // pre-scaled, tinted
  cairo_surface_t* halo = nullptr;   // pre-rendered glow
  cairo_surface_t* comp = nullptr;   // halo+logo baked once (spin/pulse/static)
  cairo_surface_t* cap = nullptr;    // full caption baked once
  int lw = 0, lh = 0, ww = 0, wh = 0;
  gint64 t0 = 0;
  guint timer = 0;
  std::string line1 = "VAULT-TEC INDUSTRIES";
  std::string line2;
  GtkWidget* win = nullptr;
};

cairo_surface_t* scale_png(const std::string& path, int target, int* w, int* h) {
  cairo_surface_t* src = cairo_image_surface_create_from_png(path.c_str());
  if (cairo_surface_status(src) != CAIRO_STATUS_SUCCESS) return nullptr;
  int sw = cairo_image_surface_get_width(src), sh = cairo_image_surface_get_height(src);
  double s = sw > target ? double(target) / sw : 1.0;
  *w = int(sw * s); *h = int(sh * s);
  cairo_surface_t* out = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, *w, *h);
  cairo_t* cr = cairo_create(out);
  cairo_scale(cr, s, s);
  cairo_set_source_surface(cr, src, 0, 0);
  cairo_pattern_set_filter(cairo_get_source(cr), CAIRO_FILTER_BEST);
  cairo_paint(cr);
  cairo_destroy(cr);
  cairo_surface_destroy(src);
  return out;
}

// Cheap halo: stack a few offset copies of the logo mask in phosphor at low alpha.
cairo_surface_t* make_halo(cairo_surface_t* logo, int w, int h) {
  const int pad = 12;
  cairo_surface_t* out = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w + pad * 2, h + pad * 2);
  cairo_t* cr = cairo_create(out);
  for (int r = pad; r > 0; r -= 3) {
    for (int a = 0; a < 8; ++a) {
      double ang = a * M_PI / 4;
      cairo_set_source_rgba(cr, kPhosR, kPhosG, kPhosB, 0.018);
      cairo_mask_surface(cr, logo, pad + r * std::cos(ang), pad + r * std::sin(ang));
    }
  }
  cairo_destroy(cr);
  return out;
}

void draw_caption(cairo_t* cr, const Mark& m, double y, size_t n1, size_t n2, bool cursor) {
  cairo_select_font_face(cr, "Share Tech Mono", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
  auto line = [&](const std::string& s, size_t n, double size, double yy, double alpha, bool cur) {
    cairo_set_font_size(cr, size);
    cairo_text_extents_t full;
    cairo_text_extents(cr, s.c_str(), &full);
    double x = (m.ww - full.x_advance) / 2.0;
    std::string part = s.substr(0, std::min(n, s.size()));
    cairo_set_source_rgba(cr, kPhosR, kPhosG, kPhosB, alpha);
    cairo_move_to(cr, x, yy);
    cairo_show_text(cr, part.c_str());
    if (cur) {
      cairo_text_extents_t pe;
      cairo_text_extents(cr, part.c_str(), &pe);
      cairo_rectangle(cr, x + pe.x_advance + 2, yy - size * 0.8, size * 0.55, size * 0.95);
      cairo_fill(cr);
    }
  };
  line(m.line1, n1, 13, y + 20, 0.55, false);
  line(m.line2, n2, 18, y + 46, 0.95, cursor);
}

void bake(Mark& m) {
  m.comp = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, m.lw + 24, m.lh + 24);
  cairo_t* c = cairo_create(m.comp);
  cairo_set_source_surface(c, m.halo, 0, 0); cairo_paint(c);
  cairo_set_source_surface(c, m.logo, 12, 12); cairo_paint(c);
  cairo_destroy(c);
  m.cap = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, m.ww, kCaptionH);
  c = cairo_create(m.cap);
  draw_caption(c, m, 0, m.line1.size(), m.line2.size(), false);
  cairo_destroy(c);
}

void render(cairo_t* cr, Mark& m, double t) {
  cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
  cairo_set_source_rgba(cr, 0, 0, 0, 0);
  cairo_paint(cr);
  cairo_set_operator(cr, CAIRO_OPERATOR_OVER);
  double cx = m.ww / 2.0, cy = m.lh / 2.0;

  auto paint_logo = [&](double alpha, double sx) {
    cairo_save(cr);
    cairo_translate(cr, cx, cy);
    cairo_scale(cr, sx, 1.0);
    cairo_set_source_surface(cr, m.comp, -m.lw / 2.0 - 12, -m.lh / 2.0 - 12);
    cairo_pattern_set_filter(cairo_get_source(cr), sx == 1.0 ? CAIRO_FILTER_NEAREST : CAIRO_FILTER_FAST);
    if (alpha >= 1.0) cairo_paint(cr); else cairo_paint_with_alpha(cr, alpha);
    cairo_restore(cr);
  };
  auto paint_cap = [&]() {
    cairo_set_source_surface(cr, m.cap, 0, m.lh);
    cairo_paint(cr);
  };

  switch (m.mode) {
    case Mode::Static:
      paint_logo(1.0, 1.0);
      paint_cap();
      break;
    case Mode::Spin: {
      double a = std::fmod(t / 8.0, 1.0) * 2 * M_PI;
      double sx = std::cos(a);
      paint_logo(1.0, (sx < 0 ? -1 : 1) * std::max(0.08, std::fabs(sx)));
      paint_cap();
      break;
    }
    case Mode::Pulse: {
      double a = 0.78 + 0.22 * (0.5 + 0.5 * std::sin(t * 2 * M_PI / 4.0));
      paint_logo(a, 1.0);
      paint_cap();
      break;
    }
    case Mode::Boot: {
      if (t < 0.35) {  // CRT line grows from center
        double k = t / 0.35;
        double w = m.ww * 0.9 * k;
        cairo_set_source_rgba(cr, kPhosR, kPhosG, kPhosB, 0.9);
        cairo_rectangle(cr, cx - w / 2, cy - 1, w, 2);
        cairo_fill(cr);
      } else if (t < 0.95) {  // vertical open, flicker overshoot
        double k = (t - 0.35) / 0.6;
        double ease = 1 - std::pow(1 - k, 3);
        double hh = m.lh * ease;
        double flick = (int(t * 30) % 3 == 0) ? 0.7 : 1.0;
        cairo_save(cr);
        cairo_rectangle(cr, 0, cy - hh / 2, m.ww, hh);
        cairo_clip(cr);
        paint_logo(flick, 1.0);
        cairo_restore(cr);
        cairo_set_source_rgba(cr, kPhosR, kPhosG, kPhosB, 0.6 * (1 - k));
        cairo_rectangle(cr, 0, cy - hh / 2 - 1, m.ww, 2);
        cairo_rectangle(cr, 0, cy + hh / 2 - 1, m.ww, 2);
        cairo_fill(cr);
      } else {  // type the overseer line
        paint_logo(1.0, 1.0);
        double tt = t - 0.95;
        size_t n1 = size_t(tt / 0.025);
        double t2 = tt - m.line1.size() * 0.025 - 0.15;
        size_t n2 = t2 > 0 ? size_t(t2 / 0.06) : 0;
        bool done = n2 >= m.line2.size();
        bool cur = !done || (int(t * 2.5) % 2 == 0);
        draw_caption(cr, m, m.lh, n1, n2, cur && t2 > 0);
      }
      break;
    }
  }
}

gboolean on_draw(GtkWidget*, cairo_t* cr, gpointer data) {
  Mark& m = *static_cast<Mark*>(data);
  render(cr, m, m.t0 ? (g_get_monotonic_time() - m.t0) / 1e6 : 1e9);
  return FALSE;
}

gboolean tick(gpointer data) {
  Mark& m = *static_cast<Mark*>(data);
  if (m.mode == Mode::Boot) {
    double t = (g_get_monotonic_time() - m.t0) / 1e6;
    double end = 0.95 + m.line1.size() * 0.025 + 0.15 + m.line2.size() * 0.06 + 1.6;
    if (t > end) {  // settle: static, kill timer — zero CPU from here on
      m.mode = Mode::Static;
      gtk_widget_queue_draw(m.win);
      m.timer = 0;
      return G_SOURCE_REMOVE;
    }
  }
  gtk_widget_queue_draw(m.win);
  return G_SOURCE_CONTINUE;
}

void on_realize(GtkWidget* w, gpointer) {
  cairo_region_t* empty = cairo_region_create();
  gdk_window_input_shape_combine_region(gtk_widget_get_window(w), empty, 0, 0);
  cairo_region_destroy(empty);
  gdk_window_set_pass_through(gtk_widget_get_window(w), TRUE);
}

int lock_instance(const std::string& inst) {
  std::string dir = home() + "/.cache";
  g_mkdir_with_parents(dir.c_str(), 0700);
  std::string p = dir + "/vaultos-mark-" + inst + ".lock";
  int fd = open(p.c_str(), O_CREAT | O_RDWR, 0600);
  if (fd < 0 || flock(fd, LOCK_EX | LOCK_NB) != 0) return -1;
  return fd;  // held for process lifetime
}

}  // namespace

int main(int argc, char** argv) {
  Mark m;
  double png_t = -1; std::string png_out;
  std::string inst = "desktop";
  std::string cfg = home() + "/.config/Vault.OS/";
  std::string want = read_line(cfg + "desktop-spin", "boot");
  if (want == "off") return 0;
  if (want == "full" || want == "spin") m.mode = Mode::Spin;
  else if (want == "pulse") m.mode = Mode::Pulse;
  else if (want == "static" || want == "reduced") m.mode = Mode::Static;
  for (int i = 1; i < argc; ++i) {
    std::string a = argv[i];
    if (a == "--boot") m.mode = Mode::Boot;
    else if (a == "--spin" || a == "--full") m.mode = Mode::Spin;
    else if (a == "--pulse") m.mode = Mode::Pulse;
    else if (a == "--static" || a == "--reduced-phosphor") m.mode = Mode::Static;
    else if (a == "--instance" && i + 1 < argc) inst = argv[++i];
    else if (a == "--png" && i + 2 < argc) { png_t = std::atof(argv[++i]); png_out = argv[++i]; }
  }
  m.line2 = "OVERSEER " + read_line(cfg + "overseer", "XMOB");

  gtk_init(&argc, &argv);
  g_set_prgname("vaultos-mark");

  std::string logo = home() + "/.local/share/backgrounds/Vault.OS/arch-logo-code.png";
  m.logo = scale_png(logo, kLogoPx, &m.lw, &m.lh);
  if (!m.logo) { std::fprintf(stderr, "vaultos-mark: missing %s\n", logo.c_str()); return 1; }
  m.halo = make_halo(m.logo, m.lw, m.lh);
  m.ww = m.lw + 80;
  m.wh = m.lh + kCaptionH;
  bake(m);
  if (!png_out.empty()) {  // offscreen frame for previews/docs, no window
    cairo_surface_t* s = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, m.ww, m.wh);
    cairo_t* c = cairo_create(s);
    cairo_set_source_rgb(c, 0.02, 0.05, 0.03); cairo_paint(c);
    cairo_push_group(c); render(c, m, png_t); cairo_pop_group_to_source(c); cairo_paint(c);
    cairo_destroy(c);
    cairo_surface_write_to_png(s, png_out.c_str());
    return 0;
  }

  if (lock_instance(inst) < 0) { std::puts("vaultos-mark: already running"); return 0; }

  GtkWidget* w = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  m.win = w;
  gtk_window_set_title(GTK_WINDOW(w), "Vault.OS Arch Code");
  gtk_window_set_decorated(GTK_WINDOW(w), FALSE);
  gtk_widget_set_app_paintable(w, TRUE);
  gtk_window_set_resizable(GTK_WINDOW(w), FALSE);
  gtk_window_set_skip_taskbar_hint(GTK_WINDOW(w), TRUE);
  gtk_window_set_skip_pager_hint(GTK_WINDOW(w), TRUE);
  gtk_window_set_accept_focus(GTK_WINDOW(w), FALSE);
  gtk_window_set_focus_on_map(GTK_WINDOW(w), FALSE);
  gtk_window_set_keep_below(GTK_WINDOW(w), TRUE);
  gtk_window_stick(GTK_WINDOW(w));
  GdkScreen* scr = gtk_widget_get_screen(w);
  if (GdkVisual* v = gdk_screen_get_rgba_visual(scr); v && gdk_screen_is_composited(scr))
    gtk_widget_set_visual(w, v);

  GdkMonitor* mon = gdk_display_get_primary_monitor(gdk_display_get_default());
  if (!mon) mon = gdk_display_get_monitor(gdk_display_get_default(), 0);
  GdkRectangle geo{};
  gdk_monitor_get_geometry(mon, &geo);
  gtk_window_set_default_size(GTK_WINDOW(w), m.ww, m.wh);
  gtk_window_move(GTK_WINDOW(w), geo.x + (geo.width - m.ww) / 2, geo.y + (geo.height - m.lh) / 2 - 40);

  g_signal_connect(w, "draw", G_CALLBACK(on_draw), &m);
  g_signal_connect(w, "realize", G_CALLBACK(on_realize), nullptr);
  g_signal_connect(w, "destroy", G_CALLBACK(gtk_main_quit), nullptr);

  if (m.mode != Mode::Static) {
    m.t0 = g_get_monotonic_time();
    guint ms = m.mode == Mode::Boot ? 33 : (m.mode == Mode::Pulse ? 125 : 66);
    m.timer = g_timeout_add(ms, tick, &m);
  }
  std::printf("vaultos-mark mode=%d overseer=%s\n", int(m.mode), m.line2.c_str());
  std::fflush(stdout);
  gtk_widget_show_all(w);
  gtk_main();
  return 0;
}
