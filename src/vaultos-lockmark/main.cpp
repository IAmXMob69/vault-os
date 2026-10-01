// vaultos-lockmark — Vault.OS lock/screensaver surface in C++ (GTK3 + cairo).
// Embeds into xfce4-screensaver via GtkPlug on $XSCREENSAVER_WINDOW, or runs
// fullscreen on its own. Arch code mark spins on vault-black with a phosphor
// halo, the overseer line and a clock underneath.
//
// The logo is scaled and baked once per window size, so each frame is a
// single image blit. 20 fps, clock text only re-baked when the minute turns.
//
// Flags: --full (spin) | --reduced-phosphor (still)   [default: spin unless Vault.OS-Reduced]
#include <gtk/gtk.h>
#include <gtk/gtkx.h>
#include <cairo.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <fstream>
#include <string>

namespace {

constexpr double kPhosR = 0x1A / 255.0, kPhosG = 0xFF / 255.0, kPhosB = 0x6B / 255.0;
constexpr double kSteel = 0x8A / 255.0;
constexpr double kBlack[] = {7 / 255.0, 8 / 255.0, 7 / 255.0};
constexpr int kPad = 14;

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

struct Lock {
  bool animate = true;
  cairo_surface_t* src = nullptr;   // original PNG
  cairo_surface_t* comp = nullptr;  // halo + logo at current size
  cairo_surface_t* cap = nullptr;   // caption + clock
  int cw = 0, ch = 0;               // comp size
  int for_w = 0, for_h = 0;         // window size comp was baked for
  int cap_min = -1;
  std::string overseer;
  gint64 t0 = 0;
  GtkWidget* area = nullptr;
};

void bake_logo(Lock& L, int w, int h) {
  if (L.comp && L.for_w == w && L.for_h == h) return;
  if (L.comp) cairo_surface_destroy(L.comp);
  int sw = cairo_image_surface_get_width(L.src), sh = cairo_image_surface_get_height(L.src);
  double target = std::min(w, h) * 0.28;
  double s = target / std::max(sw, sh);
  int lw = int(sw * s), lh = int(sh * s);
  cairo_surface_t* logo = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, lw, lh);
  cairo_t* c = cairo_create(logo);
  cairo_scale(c, s, s);
  cairo_set_source_surface(c, L.src, 0, 0);
  cairo_pattern_set_filter(cairo_get_source(c), CAIRO_FILTER_BEST);
  cairo_paint(c);
  cairo_destroy(c);

  L.cw = lw + kPad * 2; L.ch = lh + kPad * 2;
  L.comp = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, L.cw, L.ch);
  c = cairo_create(L.comp);
  for (int r = kPad; r > 0; r -= 3)
    for (int a = 0; a < 8; ++a) {
      double ang = a * M_PI / 4;
      cairo_set_source_rgba(c, kPhosR, kPhosG, kPhosB, 0.02);
      cairo_mask_surface(c, logo, kPad + r * std::cos(ang), kPad + r * std::sin(ang));
    }
  cairo_set_source_surface(c, logo, kPad, kPad);
  cairo_paint(c);
  cairo_destroy(c);
  cairo_surface_destroy(logo);
  L.for_w = w; L.for_h = h;
  L.cap_min = -1;  // width changed, re-bake caption too
}

void bake_caption(Lock& L, int w) {
  time_t now = time(nullptr);
  struct tm lt{};
  localtime_r(&now, &lt);
  int key = lt.tm_hour * 60 + lt.tm_min;
  if (L.cap && L.cap_min == key) return;
  if (L.cap) cairo_surface_destroy(L.cap);
  L.cap = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, 96);
  cairo_t* c = cairo_create(L.cap);
  cairo_select_font_face(c, "Share Tech Mono", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
  auto center = [&](const char* s, double size, double y) {
    cairo_set_font_size(c, size);
    cairo_text_extents_t e;
    cairo_text_extents(c, s, &e);
    cairo_move_to(c, (w - e.x_advance) / 2.0, y);
    cairo_show_text(c, s);
  };
  char clock[16];
  strftime(clock, sizeof clock, "%H:%M", &lt);
  cairo_set_source_rgb(c, kSteel, kSteel + 0.02, kSteel - 0.01);
  center("VAULT.OS", 14, 18);
  cairo_set_source_rgb(c, kPhosR, kPhosG, kPhosB);
  center(L.overseer.c_str(), 18, 44);
  center(clock, 34, 82);
  cairo_destroy(c);
  L.cap_min = key;
}

gboolean on_draw(GtkWidget* w, cairo_t* cr, gpointer data) {
  Lock& L = *static_cast<Lock*>(data);
  int W = gtk_widget_get_allocated_width(w), H = gtk_widget_get_allocated_height(w);
  bake_logo(L, W, H);
  bake_caption(L, W);

  cairo_set_source_rgb(cr, kBlack[0], kBlack[1], kBlack[2]);
  cairo_paint(cr);

  double cx = W / 2.0, cy = H / 2.0;
  double sx = 1.0;
  if (L.animate) {
    double t = (g_get_monotonic_time() - L.t0) / 1e6;
    double c = std::cos(std::fmod(t / 8.0, 1.0) * 2 * M_PI);
    sx = (c < 0 ? -1 : 1) * std::max(0.08, std::fabs(c));
  }
  cairo_save(cr);
  cairo_translate(cr, cx, cy);
  cairo_scale(cr, sx, 1.0);
  cairo_set_source_surface(cr, L.comp, -L.cw / 2.0, -L.ch / 2.0);
  cairo_pattern_set_filter(cairo_get_source(cr), sx == 1.0 ? CAIRO_FILTER_NEAREST : CAIRO_FILTER_FAST);
  cairo_paint(cr);
  cairo_restore(cr);

  cairo_set_source_surface(cr, L.cap, 0, cy + L.ch / 2.0 + 8);
  cairo_paint(cr);
  return FALSE;
}

gboolean tick(gpointer data) {
  Lock& L = *static_cast<Lock*>(data);
  if (L.area) gtk_widget_queue_draw(L.area);
  return G_SOURCE_CONTINUE;
}

gboolean still_tick(gpointer data) {  // static mode: only wake for the clock
  return tick(data);
}

}  // namespace

int main(int argc, char** argv) {
  bool force_full = false, force_reduced = false;
  for (int i = 1; i < argc; ++i) {
    std::string a = argv[i];
    if (a == "--full" || a == "--force-spin") force_full = true;
    else if (a == "--reduced-phosphor") force_reduced = true;
  }
  gtk_init(&argc, &argv);
  g_set_prgname("vaultos-lockmark");

  Lock L;
  std::string logo = home() + "/.local/share/backgrounds/Vault.OS/arch-logo-code.png";
  L.src = cairo_image_surface_create_from_png(logo.c_str());
  if (cairo_surface_status(L.src) != CAIRO_STATUS_SUCCESS) {
    std::fprintf(stderr, "vaultos-lockmark: missing %s\n", logo.c_str());
    return 1;
  }
  L.overseer = "OVERSEER " + read_line(home() + "/.config/Vault.OS/overseer", "XMOB");

  if (force_full) L.animate = true;
  else if (force_reduced) L.animate = false;
  else {
    GtkSettings* s = gtk_settings_get_default();
    gchar* theme = nullptr;
    g_object_get(s, "gtk-theme-name", &theme, nullptr);
    L.animate = !(theme && g_str_equal(theme, "Vault.OS-Reduced"));
    g_free(theme);
  }

  GtkWidget* host = nullptr;
  const char* env = g_getenv("XSCREENSAVER_WINDOW");
  Window xid = env && *env ? Window(std::strtoul(env, nullptr, 0)) : 0;
  if (xid) host = gtk_plug_new(xid);
  if (!host) {
    host = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(host), "Vault.OS Arch Lock");
    gtk_window_set_decorated(GTK_WINDOW(host), FALSE);
    gtk_window_set_skip_taskbar_hint(GTK_WINDOW(host), TRUE);
    gtk_window_set_skip_pager_hint(GTK_WINDOW(host), TRUE);
    gtk_window_fullscreen(GTK_WINDOW(host));
  }
  gtk_widget_set_app_paintable(host, TRUE);
  g_signal_connect(host, "destroy", G_CALLBACK(gtk_main_quit), nullptr);

  L.area = gtk_drawing_area_new();
  gtk_widget_set_hexpand(L.area, TRUE);
  gtk_widget_set_vexpand(L.area, TRUE);
  g_signal_connect(L.area, "draw", G_CALLBACK(on_draw), &L);
  gtk_container_add(GTK_CONTAINER(host), L.area);

  L.t0 = g_get_monotonic_time();
  if (L.animate) g_timeout_add(50, tick, &L);
  else g_timeout_add_seconds(15, still_tick, &L);

  std::printf("vaultos-lockmark animate=%d xid=0x%lx\n", int(L.animate), (unsigned long)xid);
  std::fflush(stdout);
  gtk_widget_show_all(host);
  gtk_main();
  return 0;
}
