import 'package:flutter/material.dart';

/// A customizable slider widget used for adjusting numeric settings.
///
/// This widget includes a descriptive label, a numeric input field for
/// precise adjustments, and a visual slider.
class SettingsSlider extends StatelessWidget {
  /// The title/label for the slider.
  final String title;

  /// The current value of the slider.
  final double value;

  /// The minimum possible value.
  final double min;

  /// The maximum possible value.
  final double max;

  /// The number of discrete intervals.
  final int? divisions;

  /// The color of the active portion of the slider.
  final Color activeColor;

  /// Callback triggered when the value changes.
  final Function(double) onChanged;

  /// Whether the value should be treated as an integer.
  final bool isInt;

  /// The font size for the labels and input.
  final double fontSize;

  const SettingsSlider({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.activeColor,
    required this.onChanged,
    this.isInt = false,
    this.fontSize = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: fontSize, color: Colors.grey),
            ),
            SizedBox(
              width: 60,
              height: 30,
              child: TextField(
                controller: TextEditingController(
                  text: isInt
                      ? value.toInt().toString()
                      : value.toStringAsFixed(2),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(fontSize: fontSize, color: Colors.white),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (val) {
                  double? parsed = double.tryParse(val);
                  if (parsed != null) {
                    if (parsed < min) parsed = min;
                    if (parsed > max) parsed = max;
                    onChanged(parsed);
                  }
                },
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: activeColor,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
