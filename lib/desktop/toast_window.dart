import 'package:flutter/material.dart';

class ToastWindow extends StatelessWidget {
  final String title;
  final String body;
  final int durationMs;

  const ToastWindow({super.key, required this.title, required this.body, this.durationMs = 4000});

  @override
  Widget build(BuildContext context) {
    // Use small, compact design similar to Steam
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 20, bottom: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // small indicator
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(body, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

