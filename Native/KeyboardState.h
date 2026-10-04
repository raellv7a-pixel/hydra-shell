#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

struct wl_callback;

// A Wayland barrier makes the focus-enter modifier snapshot observable before
// checking a held shortcut. No raw devices, polling, grabs or global key logger.
class KeyboardState : public QObject {
  Q_OBJECT
  QML_ELEMENT
public:
  explicit KeyboardState(QObject *parent = nullptr) : QObject(parent) {}
  ~KeyboardState() override;
  Q_INVOKABLE void check(int token);
  Q_INVOKABLE void cancel();
signals:
  void checked(int modifiers, int token);
private:
  static void done(void *data, wl_callback *callback, unsigned int serial);
  wl_callback *m_callback = nullptr;
  int m_token = 0;
};
