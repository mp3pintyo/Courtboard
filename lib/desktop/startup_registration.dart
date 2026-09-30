import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// A tálcára minimalizált indítás parancssori kapcsolója (a „Windows-zal
/// indítás” bejegyzése ezzel indítja az appot, ha a felhasználó kéri).
const minimizedLaunchArgument = '--minimized';

/// Az indítási paraméterek értelmezése.
class LaunchOptions {
  const LaunchOptions({this.minimized = false});

  /// Igaz, ha az app a tálcán, ablak nélkül indul.
  final bool minimized;

  static LaunchOptions parse(List<String> arguments) => LaunchOptions(
    minimized: arguments.any(
      (argument) => argument.trim().toLowerCase() == minimizedLaunchArgument,
    ),
  );
}

/// A „Run” bejegyzés értéke: az idézőjelbe tett exe-útvonal, igény szerint
/// a [minimizedLaunchArgument] kapcsolóval.
String startupCommand(String executablePath, {required bool minimized}) =>
    '"$executablePath"${minimized ? ' $minimizedLaunchArgument' : ''}';

/// Igaz, ha a [command] bejegyzés ezt az [executablePath]-ot indítja
/// (kis- és nagybetűtől függetlenül, idézőjellel vagy anélkül).
bool startupCommandTargets(String command, String executablePath) {
  final trimmed = command.trim();
  final String target;
  if (trimmed.startsWith('"')) {
    final end = trimmed.indexOf('"', 1);
    target = end > 0 ? trimmed.substring(1, end) : trimmed.substring(1);
  } else {
    final lower = trimmed.toLowerCase();
    final exe = lower.indexOf('.exe');
    target = exe >= 0 ? trimmed.substring(0, exe + 4) : trimmed;
  }
  return target.toLowerCase() == executablePath.toLowerCase();
}

/// Igaz, ha a [command] a tálcára minimalizált indítást kéri.
bool startupCommandIsMinimized(String command) =>
    command.toLowerCase().contains(minimizedLaunchArgument);

/// „Indítás a Windows-zal” kapcsoló.
abstract interface class StartupRegistration {
  /// Hamis, ha ezen a telepítésen nem állítható (például MSIX-csomagban,
  /// ahol a rendszerleíró adatbázis virtualizált).
  bool get supported;

  /// Rövid magyarázat, ha nem támogatott.
  String? get unsupportedReason;

  /// Igaz, ha a bejegyzés létezik és ezt az exe-t indítja.
  Future<bool> isEnabled();

  /// A bejegyzés létrehozása / frissítése ([minimized]: tálcára indul) vagy
  /// törlése. Hibánál [StartupRegistrationException]-t dob.
  Future<void> setEnabled(bool enabled, {required bool minimized});
}

class StartupRegistrationException implements Exception {
  const StartupRegistrationException(this.message);
  final String message;

  @override
  String toString() => 'StartupRegistrationException: $message';
}

/// A `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` alatti
/// `Courtboard` érték. Rendszergazdai jog nem kell, és csak az aktuális
/// felhasználót érinti. (A `launch_at_startup` csomag újabb változatai a
/// `win32` 5-öt igénylik, ezért közvetlen `advapi32`-hívást használunk.)
class RegistryStartupRegistration implements StartupRegistration {
  RegistryStartupRegistration({
    String? executablePath,
    this.valueName = 'Courtboard',
  }) : executablePath = executablePath ?? Platform.resolvedExecutable;

  final String executablePath;
  final String valueName;

  static const runKey = r'Software\Microsoft\Windows\CurrentVersion\Run';

  static bool? _packaged;

  /// Igaz, ha az app MSIX-csomagból fut (csomagazonosítója van).
  static bool get isPackaged {
    final cached = _packaged;
    if (cached != null) return cached;
    final packaged = using<bool>((arena) {
      final length = arena<Uint32>()..value = 0;
      final int result = GetCurrentPackageFullName(length, null);
      // APPMODEL_ERROR_NO_PACKAGE (15700): nincs csomagazonosító.
      return result != 15700;
    });
    return _packaged = packaged;
  }

  @override
  bool get supported => Platform.isWindows && !isPackaged;

  @override
  String? get unsupportedReason => !Platform.isWindows
      ? 'Csak Windows alatt érhető el.'
      : isPackaged
      ? 'Az MSIX-csomagból telepített változatnál a Windows Beállítások → '
            'Alkalmazások → Indítás oldalon kapcsolható.'
      : null;

  /// A jelenlegi bejegyzés, vagy `null`, ha nincs.
  String? readCommand() => using((arena) {
    final size = arena<Uint32>()..value = 0;
    final subKey = runKey.toPcwstr(allocator: arena);
    final name = valueName.toPcwstr(allocator: arena);
    var result = RegGetValue(
      HKEY_CURRENT_USER,
      subKey,
      name,
      RRF_RT_REG_SZ,
      null,
      null,
      size,
    );
    if (result == ERROR_FILE_NOT_FOUND) return null;
    if (result != ERROR_SUCCESS) {
      throw StartupRegistrationException('Olvasás sikertelen ($result)');
    }
    final buffer = arena<Uint8>(size.value + 2);
    result = RegGetValue(
      HKEY_CURRENT_USER,
      subKey,
      name,
      RRF_RT_REG_SZ,
      null,
      buffer,
      size,
    );
    if (result != ERROR_SUCCESS) {
      throw StartupRegistrationException('Olvasás sikertelen ($result)');
    }
    return buffer.cast<Utf16>().toDartString();
  });

  @override
  Future<bool> isEnabled() async {
    if (!supported) return false;
    try {
      final command = readCommand();
      return command != null && startupCommandTargets(command, executablePath);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setEnabled(bool enabled, {required bool minimized}) async {
    if (!supported) {
      throw StartupRegistrationException(
        unsupportedReason ?? 'Nem támogatott.',
      );
    }
    using((arena) {
      final key = arena<Pointer>();
      var result = RegCreateKeyEx(
        HKEY_CURRENT_USER,
        runKey.toPcwstr(allocator: arena),
        null,
        REG_OPTION_NON_VOLATILE,
        KEY_SET_VALUE,
        null,
        key,
        null,
      );
      if (result != ERROR_SUCCESS) {
        throw StartupRegistrationException('Megnyitás sikertelen ($result)');
      }
      final handle = HKEY(key.value);
      try {
        final name = valueName.toPcwstr(allocator: arena);
        if (enabled) {
          final command = startupCommand(executablePath, minimized: minimized);
          final data = command.toPcwstr(allocator: arena);
          result = RegSetValueEx(
            handle,
            name,
            REG_SZ,
            data.cast<Uint8>(),
            (command.length + 1) * 2,
          );
        } else {
          result = RegDeleteValue(handle, name);
          if (result == ERROR_FILE_NOT_FOUND) result = ERROR_SUCCESS;
        }
        if (result != ERROR_SUCCESS) {
          throw StartupRegistrationException('Írás sikertelen ($result)');
        }
      } finally {
        RegCloseKey(handle);
      }
    });
  }
}

/// Memóriában élő megvalósítás (tesztekhez és nem Windows platformhoz).
class MemoryStartupRegistration implements StartupRegistration {
  MemoryStartupRegistration({this.supported = true, this.command});

  @override
  final bool supported;

  /// A „bejegyzés” értéke; `null`: nincs.
  String? command;

  static const executablePath = r'C:\Program Files\Courtboard\courtboard.exe';

  @override
  String? get unsupportedReason =>
      supported ? null : 'Ezen a telepítésen nem érhető el.';

  @override
  Future<bool> isEnabled() async => command != null;

  @override
  Future<void> setEnabled(bool enabled, {required bool minimized}) async {
    command = enabled
        ? startupCommand(executablePath, minimized: minimized)
        : null;
  }
}
