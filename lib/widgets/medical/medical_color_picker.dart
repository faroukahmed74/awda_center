import 'package:flutter/material.dart';

/// Compact color swatches for medical field labels / format tools.
Future<Color?> showMedicalColorPicker(
  BuildContext context, {
  Color? current,
}) async {
  const swatches = <Color>[
    Color(0xFFE53935), // red
    Color(0xFFD81B60), // pink
    Color(0xFF8E24AA), // purple
    Color(0xFF3949AB), // indigo
    Color(0xFF1E88E5), // blue
    Color(0xFF00897B), // teal
    Color(0xFF43A047), // green
    Color(0xFFFDD835), // yellow
    Color(0xFFFB8C00), // orange
    Color(0xFF6D4C41), // brown
    Color(0xFF546E7A), // blue grey
    Color(0xFF212121), // near black
  ];

  return showDialog<Color?>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        title: const Text('Label color'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in swatches)
              InkWell(
                onTap: () => Navigator.of(ctx).pop(c),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: current == c
                          ? theme.colorScheme.primary
                          : theme.dividerColor,
                      width: current == c ? 3 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(const Color(0x00000000)),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}

String? colorToHex(Color? color) {
  if (color == null) return null;
  final r = (color.r * 255.0).round().clamp(0, 255);
  final g = (color.g * 255.0).round().clamp(0, 255);
  final b = (color.b * 255.0).round().clamp(0, 255);
  return '#${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

Color? colorFromHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final n = int.tryParse(h, radix: 16);
  if (n == null) return null;
  return Color(n);
}

/// Transparent sentinel from the Clear action in [showMedicalColorPicker].
bool isClearColor(Color? c) => c != null && c.a == 0.0;
