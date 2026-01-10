import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
class TrayService {
  static final TrayService _instance = TrayService._internal();
  factory TrayService() => _instance;
  TrayService._internal();
  SystemTray? _systemTray;
  bool _initialized = false;
  void Function()? _onQuit;
  bool get _isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  Future<void> init({required void Function() onQuit}) async {
    if (!_isDesktop) {
      print('TrayService: Nicht auf Desktop-Plattform');
      return;
    }

    _onQuit = onQuit;

    try {
      await windowManager.ensureInitialized();
      await windowManager.setPreventClose(true);

      // Icon aus Assets in temp-Datei schreiben
      final iconPath = await _copyIconToTemp();
      print('TrayService: Icon-Pfad: $iconPath');

      _systemTray = SystemTray();
      await _systemTray!.initSystemTray(
        title: 'OnlineStatus',
        iconPath: iconPath,
        toolTip: 'OnlineStatus',
      );

      final menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(
          label: 'Anzeigen',
          onClicked: (_) => showWindow(),
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: 'Beenden',
          onClicked: (_) => _onQuit?.call(),
        ),
      ]);
      await _systemTray!.setContextMenu(menu);

      _systemTray!.registerSystemTrayEventHandler((eventType) {
        if (eventType == kSystemTrayEventClick ||
            eventType == kSystemTrayEventDoubleClick) {
          showWindow();
        } else if (eventType == kSystemTrayEventRightClick) {
          _systemTray!.popUpContextMenu();
        }
      });

      _initialized = true;
      print('TrayService: Erfolgreich initialisiert');
    } catch (e) {
      print('TrayService init Fehler: $e');
      _initialized = false;
    }
  }
  Future<String> _copyIconToTemp() async {
    try {
      final tempDir = Directory.systemTemp;

      if (Platform.isWindows) {
        // Windows benötigt .ico Format
        final tempFile = File(path.join(tempDir.path, 'onlinestatus_icon.ico'));
        final byteData = await rootBundle.load('assets/app_icon.ico');
        await tempFile.writeAsBytes(byteData.buffer.asUint8List());
        print('TrayService: Icon geschrieben nach ${tempFile.path}');
        return tempFile.path;
      } else {
        // Linux verwendet .png
        final tempFile = File(path.join(tempDir.path, 'onlinestatus_icon.png'));
        final byteData = await rootBundle.load('assets/app_icon.png');
        await tempFile.writeAsBytes(byteData.buffer.asUint8List());
        print('TrayService: Icon geschrieben nach ${tempFile.path}');
        return tempFile.path;
      }
    } catch (e) {
      print('TrayService: Icon-Fehler: $e');
      return '';
    }
  }
  Future<void> showWindow() async {
    if (!_isDesktop) return;
    await windowManager.show();
    await windowManager.focus();
  }
  Future<void> minimizeToTray() async {
    if (!_isDesktop || !_initialized) return;
    await windowManager.hide();
  }
  bool get isAvailable => _isDesktop && _initialized;
  Future<void> dispose() async {
    if (_systemTray != null) {
      await _systemTray!.destroy();
    }
    _initialized = false;
  }
}
