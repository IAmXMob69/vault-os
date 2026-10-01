// vaultos-screensaver-proxy — owns org.freedesktop.ScreenSaver and forwards
// to xfce4-screensaver, so Firefox/mpv/VLC inhibits actually stop idle-lock.
// Also inhibits while a known media player is fullscreen.
// C++ port of the old Python proxy: GIO for D-Bus, plain Xlib for the
// fullscreen check (no Wnck/GTK), polled every 8 s.
#include <gio/gio.h>
#include <glib-unix.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>
#include <algorithm>
#include <cctype>
#include <csignal>
#include <cstdio>
#include <string>

namespace {

constexpr const char* kXfceName = "org.xfce.ScreenSaver";
constexpr const char* kXfcePath = "/org/xfce/ScreenSaver";
constexpr const char* kXfceIface = "org.xfce.ScreenSaver";
constexpr const char* kFdoName = "org.freedesktop.ScreenSaver";
constexpr const char* kFdoPaths[] = {"/org/freedesktop/ScreenSaver", "/ScreenSaver"};
constexpr const char* kPlayers[] = {"firefox", "firefox-bin", "mpv", "vlc", "celluloid", "smplayer",
                                    "chromium", "chromium-browser", "google-chrome",
                                    "org.gnome.totem", "totem"};

constexpr const char* kXml = R"(<node>
  <interface name="org.freedesktop.ScreenSaver">
    <method name="Inhibit">
      <arg direction="in" type="s" name="application_name"/>
      <arg direction="in" type="s" name="reason_for_inhibit"/>
      <arg direction="out" type="u" name="cookie"/>
    </method>
    <method name="UnInhibit"><arg direction="in" type="u" name="cookie"/></method>
    <method name="Lock"/>
    <method name="GetActive"><arg direction="out" type="b" name="active"/></method>
    <method name="GetActiveTime"><arg direction="out" type="u" name="seconds"/></method>
    <method name="SimulateUserActivity"/>
  </interface>
</node>)";

GMainLoop* loop = nullptr;
GDBusProxy* xfce = nullptr;
GDBusNodeInfo* node = nullptr;
Display* dpy = nullptr;
guint32 fs_cookie = 0;

GDBusProxy* xfce_proxy() {
  if (xfce) return xfce;
  GError* err = nullptr;
  xfce = g_dbus_proxy_new_for_bus_sync(G_BUS_TYPE_SESSION, G_DBUS_PROXY_FLAGS_DO_NOT_LOAD_PROPERTIES,
                                       nullptr, kXfceName, kXfcePath, kXfceIface, nullptr, &err);
  if (!xfce) {
    std::fprintf(stderr, "vaultos-screensaver-proxy: xfce proxy: %s\n", err ? err->message : "?");
    g_clear_error(&err);
  }
  return xfce;
}

// Returns a new reference (or nullptr with *err set).
GVariant* xfce_call(const char* method, GVariant* args, GError** err) {
  GDBusProxy* p = xfce_proxy();
  if (!p) {
    if (args) g_variant_unref(g_variant_ref_sink(args));
    g_set_error_literal(err, G_DBUS_ERROR, G_DBUS_ERROR_SERVICE_UNKNOWN, "xfce4-screensaver not on the bus");
    return nullptr;
  }
  return g_dbus_proxy_call_sync(p, method, args, G_DBUS_CALL_FLAGS_NONE, 4000, nullptr, err);
}

void set_presentation(bool on) {
  const char* argv[] = {"xfconf-query", "-c", "xfce4-power-manager", "-p",
                        "/xfce4-power-manager/presentation-mode", "-s", on ? "true" : "false", nullptr};
  g_spawn_async(nullptr, const_cast<char**>(argv), nullptr,
                GSpawnFlags(G_SPAWN_SEARCH_PATH | G_SPAWN_STDOUT_TO_DEV_NULL | G_SPAWN_STDERR_TO_DEV_NULL),
                nullptr, nullptr, nullptr, nullptr);
}

std::string lower(const char* s) {
  std::string r = s ? s : "";
  std::transform(r.begin(), r.end(), r.begin(), [](unsigned char c) { return std::tolower(c); });
  return r;
}

bool is_player(const std::string& s) {
  for (auto p : kPlayers) if (s == p) return true;
  return s.find("firefox") != std::string::npos || s.find("mpv") != std::string::npos ||
         s.find("vlc") != std::string::npos;
}

bool media_fullscreen() {
  if (!dpy) return false;
  Atom client_list = XInternAtom(dpy, "_NET_CLIENT_LIST", True);
  Atom wm_state = XInternAtom(dpy, "_NET_WM_STATE", True);
  Atom fullscreen = XInternAtom(dpy, "_NET_WM_STATE_FULLSCREEN", True);
  if (client_list == None || wm_state == None || fullscreen == None) return false;

  Atom type; int fmt; unsigned long n = 0, after = 0; unsigned char* data = nullptr;
  if (XGetWindowProperty(dpy, DefaultRootWindow(dpy), client_list, 0, 4096, False, XA_WINDOW,
                         &type, &fmt, &n, &after, &data) != Success || !data)
    return false;
  Window* wins = reinterpret_cast<Window*>(data);
  bool found = false;
  for (unsigned long i = 0; i < n && !found; ++i) {
    unsigned char* sdata = nullptr; unsigned long sn = 0;
    if (XGetWindowProperty(dpy, wins[i], wm_state, 0, 64, False, XA_ATOM, &type, &fmt, &sn, &after,
                           &sdata) != Success || !sdata)
      continue;
    Atom* st = reinterpret_cast<Atom*>(sdata);
    bool fs = std::find(st, st + sn, fullscreen) != st + sn;
    XFree(sdata);
    if (!fs) continue;
    XClassHint hint{};
    if (XGetClassHint(dpy, wins[i], &hint)) {
      found = is_player(lower(hint.res_class)) || is_player(lower(hint.res_name));
      if (hint.res_class) XFree(hint.res_class);
      if (hint.res_name) XFree(hint.res_name);
    }
  }
  XFree(data);
  return found;
}

gboolean poll_fullscreen(gpointer) {
  bool want = media_fullscreen();
  GError* err = nullptr;
  if (want && !fs_cookie) {
    if (GVariant* r = xfce_call("Inhibit", g_variant_new("(ss)", "vaultos-media", "fullscreen player"), &err)) {
      g_variant_get(r, "(u)", &fs_cookie);
      g_variant_unref(r);
      set_presentation(true);
    } else {
      std::fprintf(stderr, "vaultos-screensaver-proxy: fullscreen inhibit: %s\n", err->message);
    }
  } else if (!want && fs_cookie) {
    if (GVariant* r = xfce_call("UnInhibit", g_variant_new("(u)", fs_cookie), &err)) g_variant_unref(r);
    fs_cookie = 0;
    set_presentation(false);
  }
  g_clear_error(&err);
  return G_SOURCE_CONTINUE;
}

void on_method(GDBusConnection*, const char*, const char*, const char*, const char* method,
               GVariant* params, GDBusMethodInvocation* inv, gpointer) {
  static const char* known[] = {"Inhibit", "UnInhibit", "Lock", "GetActive", "GetActiveTime",
                                "SimulateUserActivity"};
  if (std::none_of(std::begin(known), std::end(known), [&](const char* k) { return g_str_equal(k, method); })) {
    g_dbus_method_invocation_return_error(inv, G_DBUS_ERROR, G_DBUS_ERROR_UNKNOWN_METHOD, "%s", method);
    return;
  }
  // Forward with the same signature; the xfce interface mirrors the fdo one.
  GVariant* args = g_variant_n_children(params) ? g_variant_ref(params) : nullptr;
  GError* err = nullptr;
  GVariant* r = xfce_call(method, args, &err);
  if (!r) {
    g_dbus_method_invocation_return_error_literal(inv, G_DBUS_ERROR, G_DBUS_ERROR_FAILED, err->message);
    g_clear_error(&err);
    return;
  }
  bool has_out = g_variant_n_children(r) > 0;
  g_dbus_method_invocation_return_value(inv, has_out ? r : nullptr);  // takes its own ref
  g_variant_unref(r);
}

const GDBusInterfaceVTable kVtable = {on_method, nullptr, nullptr, {}};

void on_bus(GDBusConnection* conn, const char*, gpointer) {
  for (auto path : kFdoPaths) {
    GError* err = nullptr;
    if (!g_dbus_connection_register_object(conn, path, node->interfaces[0], &kVtable, nullptr, nullptr, &err)) {
      std::fprintf(stderr, "vaultos-screensaver-proxy: register %s: %s\n", path, err->message);
      g_clear_error(&err);
    }
  }
}

void on_lost(GDBusConnection*, const char*, gpointer) {
  std::fprintf(stderr, "vaultos-screensaver-proxy: lost %s\n", kFdoName);
  g_main_loop_quit(loop);
}

gboolean on_signal(gpointer) {
  if (fs_cookie) {
    GError* err = nullptr;
    if (GVariant* r = xfce_call("UnInhibit", g_variant_new("(u)", fs_cookie), &err)) g_variant_unref(r);
    g_clear_error(&err);
    set_presentation(false);
  }
  g_main_loop_quit(loop);
  return G_SOURCE_REMOVE;
}

}  // namespace

int main() {
  if (!g_getenv("DISPLAY")) g_setenv("DISPLAY", ":0", TRUE);
  dpy = XOpenDisplay(nullptr);  // optional: proxy still works without X
  node = g_dbus_node_info_new_for_xml(kXml, nullptr);
  loop = g_main_loop_new(nullptr, FALSE);
  g_unix_signal_add(SIGTERM, on_signal, nullptr);
  g_unix_signal_add(SIGINT, on_signal, nullptr);
  guint owner = g_bus_own_name(G_BUS_TYPE_SESSION, kFdoName, G_BUS_NAME_OWNER_FLAGS_NONE, on_bus, nullptr,
                               on_lost, nullptr, nullptr);
  g_timeout_add_seconds(8, poll_fullscreen, nullptr);
  std::printf("vaultos-screensaver-proxy listening on %s\n", kFdoName);
  std::fflush(stdout);
  g_main_loop_run(loop);
  g_bus_unown_name(owner);
  if (dpy) XCloseDisplay(dpy);
  return 0;
}
