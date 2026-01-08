// system_tray removed - causes segfaults on Linux
// import 'package:system_tray/system_tray.dart';

/// TrayService - currently disabled due to stability issues on Linux.
/// The system_tray plugin causes segmentation faults.
class TrayService {
  bool _initialized = false;

  Future<void> init({required void Function() onShow, required void Function() onQuit}) async {
    // System tray disabled due to crashes on Linux
    // ignore: avoid_print
    print('TrayService: disabled (system_tray plugin removed for Linux stability)');
    _initialized = true;
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    _initialized = false;
  }
}
