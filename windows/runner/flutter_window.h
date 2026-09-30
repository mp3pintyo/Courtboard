#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  // Courtboard: started with --minimized (the app lives in the tray), so the
  // fallback timer must not show the window.
  void SetStartHidden(bool start_hidden) { start_hidden_ = start_hidden; }

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Courtboard: see SetStartHidden.
  bool start_hidden_ = false;

  // Courtboard: true once the window has been shown (normally by the Dart
  // side, after it restored the saved position).
  bool shown_once_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
