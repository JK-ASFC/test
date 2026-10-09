import 'package:flutter/material.dart';

const colorChoices = [
  0xFFE53935, 0xFFD81B60, 0xFF8E24AA, 0xFF5E35B1, 0xFF3949AB, 0xFF1E88E5,
  0xFF039BE5, 0xFF00ACC1, 0xFF00897B, 0xFF43A047, 0xFF7CB342, 0xFFC0CA33,
  0xFFFDD835, 0xFFEDB400, 0xFFFF7A00, 0xFFF4511E, 0xFF6D4C41, 0xFF546E7A,
  0xFF263238, 0xFF000000,
];

/// Row of round colour swatches.
class ColorChoice extends StatelessWidget {
  const ColorChoice({super.key, required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final all = colorChoices.contains(selected) ? colorChoices : [selected, ...colorChoices];
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final c in all)
        GestureDetector(
          onTap: () => onChanged(c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color(c),
              shape: BoxShape.circle,
              border: Border.all(
                color: c == selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                width: 3,
              ),
            ),
            child: c == selected
                ? Icon(Icons.check,
                    size: 18,
                    color: ThemeData.estimateBrightnessForColor(Color(c)) == Brightness.dark
                        ? Colors.white
                        : Colors.black)
                : null,
          ),
        ),
    ]);
  }
}
