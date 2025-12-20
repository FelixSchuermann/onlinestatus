import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'toast_window.dart';

void main(List<String> args) {
  // args[0] contains JSON encoded arguments from createWindow
  String title = 'Notification';
  String body = '';
  int durationMs = 4000;

  if (args.isNotEmpty) {
    try {
      final decoded = jsonDecode(args[0]) as Map<String, dynamic>;
      title = decoded['title'] as String? ?? 'Notification';
      body = decoded['body'] as String? ?? '';
      durationMs = decoded['durationMs'] as int? ?? 4000;
    } catch (e) {
      // Fallback to old format if JSON parse fails
      title = args[0];
      body = args.length > 1 ? args[1] : '';
      durationMs = args.length > 2 ? int.tryParse(args[2]) ?? 4000 : 4000;
    }
  }

  runApp(_ToastApp(title: title, body: body, durationMs: durationMs));
}

class _ToastApp extends StatefulWidget {
  final String title;
  final String body;
  final int durationMs;
  const _ToastApp({required this.title, required this.body, required this.durationMs});

  @override
  State<_ToastApp> createState() => _ToastAppState();
}

class _ToastAppState extends State<_ToastApp> {
  @override
  void initState() {
    super.initState();
    // close the window after duration
    Timer(Duration(milliseconds: widget.durationMs), () async {
      try {
        // Get current window and hide it
        final controller = await WindowController.fromCurrentEngine();
        await controller.hide();
        // Exit this window's isolate
        exit(0);
      } catch (e) {
        // ignore: avoid_print
        print('Toast close error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: ToastWindow(title: widget.title, body: widget.body, durationMs: widget.durationMs),
      ),
    );
  }
}
