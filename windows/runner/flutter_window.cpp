#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Courtboard: if the Dart side has not shown the window this long after the
// first frame (it normally does so right after restoring the saved window
// position), the runner shows it itself so that the app never stays
// invisible because of an error.
constexpr UINT_PTR kShowFallbackTimerId = 0xC0B0;
constexpr UINT kShowFallbackDelayMs = 4000;

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Courtboard: the window is not shown on the first frame any more: the Dart
  // side (lib/desktop/desktop_integration.dart) first moves it to the saved
  // position and then shows it, avoiding a visible jump. The timer is only a
  // safety net.
  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    if (!start_hidden_) {
      SetTimer(GetHandle(), kShowFallbackTimerId, kShowFallbackDelayMs,
               nullptr);
    }
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (message == WM_GETMINMAXINFO) {
      // Courtboard: window_manager answers WM_GETMINMAXINFO itself (without
      // a minimum unless Dart sets one); keep the runner's DPI-aware minimum.
      ApplyMinimumTrackSize(hwnd, reinterpret_cast<MINMAXINFO*>(lparam));
      return 0;
    }
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_SHOWWINDOW:
      if (wparam) {
        shown_once_ = true;
      }
      break;
    case WM_TIMER:
      if (wparam == kShowFallbackTimerId) {
        KillTimer(hwnd, kShowFallbackTimerId);
        if (!shown_once_ && !start_hidden_ && !IsWindowVisible(hwnd)) {
          Show();
        }
        return 0;
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
