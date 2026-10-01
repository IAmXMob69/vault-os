// vaultos-close-all — close every application window (libwnck-3), skipping
// the panel, desktop, WM, notification daemons and non-app window types.
// Native port of bin/vault-os-close-all; same filters, same notification,
// same "closed N" line on stdout.
//
//   --dry-run   list each window and whether it would be closed; closes
//               nothing and sends no notification.
#define WNCK_I_KNOW_THIS_IS_UNSTABLE 1
#include <gtk/gtk.h>
#include <libnotify/notify.h>
#include <libwnck/libwnck.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

namespace {

const char* const kSkipClasses[] = {
    "xfce4-panel", "xfdesktop", "xfwm4", "wrapper-2.0", "xfce4-notifyd", "notify-osd", "plasmashell",
};
const char* const kSkipSubstrings[] = {"panel", "xfdesktop", "notify"};

const char* type_name(WnckWindowType t) {
  switch (t) {
    case WNCK_WINDOW_NORMAL: return "normal";
    case WNCK_WINDOW_DESKTOP: return "desktop";
    case WNCK_WINDOW_DOCK: return "dock";
    case WNCK_WINDOW_DIALOG: return "dialog";
    case WNCK_WINDOW_TOOLBAR: return "toolbar";
    case WNCK_WINDOW_MENU: return "menu";
    case WNCK_WINDOW_UTILITY: return "utility";
    case WNCK_WINDOW_SPLASHSCREEN: return "splash";
  }
  return "?";
}

// nullptr = close it, otherwise the reason it is skipped.
const char* skip_reason(WnckWindow* w, const std::string& cls) {
  for (const char* s : kSkipClasses)
    if (cls == s) return "skip-class";
  for (const char* s : kSkipSubstrings)
    if (cls.find(s) != std::string::npos) return "skip-class";
  switch (wnck_window_get_window_type(w)) {
    case WNCK_WINDOW_DESKTOP:
    case WNCK_WINDOW_DOCK:
    case WNCK_WINDOW_SPLASHSCREEN:
    case WNCK_WINDOW_MENU:
    case WNCK_WINDOW_TOOLBAR:
    case WNCK_WINDOW_UTILITY:
      return "skip-type";
    default:
      return nullptr;
  }
}

gboolean quit_loop(gpointer) {
  gtk_main_quit();
  return G_SOURCE_REMOVE;
}

}  // namespace

int main(int argc, char** argv) {
  bool dry = false;
  for (int i = 1; i < argc; ++i) {
    if (!std::strcmp(argv[i], "--dry-run") || !std::strcmp(argv[i], "-n")) dry = true;
    else if (!std::strcmp(argv[i], "-h") || !std::strcmp(argv[i], "--help")) {
      std::puts("usage: vaultos-close-all [--dry-run]");
      return 0;
    }
  }
  setenv("DISPLAY", ":0", 0);  // same defaults as the Python version
  setenv("GDK_BACKEND", "x11", 0);
  if (!gtk_init_check(&argc, &argv)) {
    std::fputs("no wnck screen\n", stderr);
    return 1;
  }
  // Application client type, the same libwnck default the Python version uses.
  WnckHandle* handle = wnck_handle_new(WNCK_CLIENT_TYPE_APPLICATION);
  WnckScreen* screen = wnck_handle_get_default_screen(handle);
  if (!screen) {
    std::fputs("no wnck screen\n", stderr);
    return 1;
  }
  wnck_screen_force_update(screen);

  guint32 ts = gtk_get_current_event_time();
  int closed = 0;
  // Copy the list: closing can change the screen's list under us.
  GList* wins = g_list_copy(wnck_screen_get_windows(screen));
  for (GList* l = wins; l; l = l->next) {
    WnckWindow* w = WNCK_WINDOW(l->data);
    const char* cg = wnck_window_get_class_group_name(w);
    std::string cls = cg ? cg : "";
    for (auto& c : cls) c = char(g_ascii_tolower(c));
    const char* why = skip_reason(w, cls);
    if (dry) {
      const char* name = wnck_window_get_name(w);
      std::printf("%-10s 0x%08lx  %-8s %-24s %s\n", why ? why : "CLOSE", wnck_window_get_xid(w),
                  type_name(wnck_window_get_window_type(w)), cls.c_str(), name ? name : "");
    }
    if (why) continue;
    if (!dry) wnck_window_close(w, ts);
    ++closed;
  }
  g_list_free(wins);

  if (dry) {
    std::printf("would close %d\n", closed);
    return 0;
  }

  g_timeout_add(200, quit_loop, nullptr);
  gtk_main();

  if (notify_init("Vault-OS")) {
    std::string body = "Closed " + std::to_string(closed) + " window(s)";
    NotifyNotification* n = notify_notification_new("Close All", body.c_str(), "nuclear_waste");
    notify_notification_show(n, nullptr);
    g_object_unref(n);
    notify_uninit();
  }
  std::printf("closed %d\n", closed);
  return 0;
}
