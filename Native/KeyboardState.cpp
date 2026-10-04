#include "KeyboardState.h"

#include <QGuiApplication>
#include <wayland-client.h>

KeyboardState::~KeyboardState() { cancel(); }

void KeyboardState::cancel() {
  if (m_callback) {
    wl_callback_destroy(m_callback);
    m_callback = nullptr;
  }
}

void KeyboardState::check(int token) {
  if (m_callback) return;
  auto *native = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>();
  if (!native) return; // Hydra's interactive runtime requires Wayland.
  m_token = token;
  m_callback = wl_display_sync(native->display());
  static const wl_callback_listener listener = { &KeyboardState::done };
  wl_callback_add_listener(m_callback, &listener, this);
  wl_display_flush(native->display());
}

void KeyboardState::done(void *data, wl_callback *callback, unsigned int) {
  auto *self = static_cast<KeyboardState *>(data);
  if (callback != self->m_callback) return;
  self->m_callback = nullptr;
  wl_callback_destroy(callback);
  // queryKeyboardModifiers reads the platform state rather than the last
  // QKeyEvent (which may predate the overlay's focus).
  emit self->checked(int(QGuiApplication::queryKeyboardModifiers()), self->m_token);
}
