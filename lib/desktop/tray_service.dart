import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:system_tray/system_tray.dart';

class TrayService {
  final SystemTray _systemTray = SystemTray();
  bool _initialized = false;
  
  // Store callbacks
  void Function()? _onShow;
  void Function()? _onQuit;

  // 1x1 transparent PNG base64 (used as fallback icon when assets missing)
  static const _kFallbackPngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=';

  Future<void> init({required void Function() onShow, required void Function() onQuit}) async {
    if (!(Platform.isWindows || Platform.isLinux)) return;
    if (_initialized) return;
    
    _onShow = onShow;
    _onQuit = onQuit;

    try {
      String? iconPath = await _resolveIconPath();
      if (iconPath == null) {
        // couldn't find or create an icon; for Windows, skip to avoid PlatformException
        if (Platform.isWindows) {
          // ignore: avoid_print
          print('TrayService: no icon available for Windows, skipping tray initialization');
          return;
        }
        // For Linux try fallback
        final tmp = File('${Directory.systemTemp.path}/onlinestatus_fallback.png');
        if (!tmp.existsSync()) {
          final bytes = base64Decode(_kFallbackPngBase64);
          await tmp.writeAsBytes(bytes, flush: true);
        }
        iconPath = tmp.path;
        // ignore: avoid_print
        print('TrayService: using fallback icon at $iconPath');
      }

      // Initialize system tray with the icon
      await _systemTray.initSystemTray(
        title: "OnlineStatus",
        iconPath: iconPath,
        toolTip: "Online Status App",
      );
      
      // Create popup menu items
      final List<MenuItemBase> menuItems = [
        MenuItem(label: 'Open', onClicked: () => _onShow?.call()),
        MenuSeparator(),
        MenuItem(label: 'Quit', onClicked: () => _onQuit?.call()),
      ];
      
      await _systemTray.setContextMenu(menuItems);

      // Register click handler
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == 'leftMouseUp' || eventName == 'click') {
          _onShow?.call();
        }
      });

      _initialized = true;
      // ignore: avoid_print
      print('TrayService: initialized with icon $iconPath');
    } catch (e) {
      // ignore errors to avoid crashing app when tray cannot be initialized
      // ignore: avoid_print
      print('TrayService.init error: $e');
    }
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    try {
      // Note: system_tray 0.1.1 doesn't have a destroy method, just reset state
      _initialized = false;
      _onShow = null;
      _onQuit = null;
    } catch (e) {
      // ignore: avoid_print
      print('TrayService.dispose error: $e');
    }
  }

  // Try to find a usable icon path. Preference order:
  // 1) a real file at 'assets/app_icon.png' or 'assets/icon.ico' or 'assets/icon.png'
  // 2) copy 'assets/app_icon.png' from asset bundle to a temp file and return that path
  // 3) null if nothing could be produced
  Future<String?> _resolveIconPath() async {
    final candidates = ['assets/app_icon.png', 'assets/icon.ico', 'assets/icon.png'];

    // 1) check if any candidate exists as a file in the local filesystem (useful during development)
    for (final c in candidates) {
      final f = File(c);
      if (f.existsSync()) {
        // if it's a png and we're on windows, try to create .ico alongside it
        if (Platform.isWindows && c.toLowerCase().endsWith('.png')) {
          final ico = await _ensureIcoFromPngFile(f);
          if (ico != null) return ico.path;
        }
        return f.absolute.path;
      }
    }

    // 2) try to load the primary asset from the bundle and write to temp
    try {
      final asset = 'assets/app_icon.png';
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List();
      final tmp = File('${Directory.systemTemp.path}/onlinestatus_app_icon.png');
      await tmp.writeAsBytes(bytes, flush: true);
      // On Windows, also write an ICO wrapper
      if (Platform.isWindows) {
        final ico = await _writeIcoWrapper(tmp);
        if (ico != null) return ico.path;
      }
      // ignore: avoid_print
      print('TrayService: wrote asset $asset to temp ${tmp.path}');
      return tmp.path;
    } catch (e) {
      // ignore: avoid_print
      print('TrayService: failed to write asset to temp: $e');
    }

    // nothing available
    return null;
  }

  // If a given PNG file exists, write a .ico wrapper next to it and return the file.
  Future<File?> _ensureIcoFromPngFile(File pngFile) async {
    try {
      final icoPath = '${pngFile.parent.path}/${pngFile.uri.pathSegments.last.split('.').first}.ico';
      final icoFile = File(icoPath);
      if (icoFile.existsSync()) return icoFile;
      return await _writeIcoWrapper(pngFile);
    } catch (e) {
      // ignore: avoid_print
      print('TrayService._ensureIcoFromPngFile error: $e');
      return null;
    }
  }

  // Create a minimal ICO that contains the PNG as a single image entry.
  // Many Windows APIs accept an .ico file whose image data is a PNG image with an ICO header.
  Future<File?> _writeIcoWrapper(File pngFile) async {
    try {
      final pngBytes = await pngFile.readAsBytes();
      final tmpIco = File('${Directory.systemTemp.path}/onlinestatus_app_icon.ico');
      final sink = tmpIco.openWrite();
      // ICO header: reserved (2 bytes), type (2 bytes: 1 for icon), count (2 bytes)
      sink.add([0x00, 0x00, 0x01, 0x00, 0x01, 0x00]);
      // Image entry: width(1), height(1), colors(1), reserved(1), planes(2), bitcount(2), bytesize(4), offset(4)
      // We'll write zeros for width/height (0 means 256) and colors/reserved, planes/bitcount zero.
      final bytesize = pngBytes.length;
      final offset = 6 + 16; // header + directory entry size
      sink.add([0x00]); // width = 0 (256)
      sink.add([0x00]); // height = 0
      sink.add([0x00]); // colors
      sink.add([0x00]); // reserved
      // planes (2 bytes)
      sink.add([0x00, 0x00]);
      // bitcount (2 bytes)
      sink.add([0x00, 0x00]);
      // bytesize (4 bytes little endian)
      sink.add([bytesize & 0xFF, (bytesize >> 8) & 0xFF, (bytesize >> 16) & 0xFF, (bytesize >> 24) & 0xFF]);
      // offset (4 bytes little endian)
      sink.add([offset & 0xFF, (offset >> 8) & 0xFF, (offset >> 16) & 0xFF, (offset >> 24) & 0xFF]);
      // now write png bytes
      sink.add(pngBytes);
      await sink.flush();
      await sink.close();
      // ignore: avoid_print
      print('TrayService: wrote ico to ${tmpIco.path}');
      return tmpIco;
    } catch (e) {
      // ignore: avoid_print
      print('TrayService._writeIcoWrapper error: $e');
      return null;
    }
  }
}
