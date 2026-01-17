import 'package:flutter/material.dart';

class SettingsSlider extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final Color activeColor;
  final Function(double) onChanged;
  final bool isInt;

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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            SizedBox(
              width: 60,
              height: 30,
              child: TextField(
                controller: TextEditingController(
                    text: isInt ? value.toInt().toString() : value.toStringAsFixed(2)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 12, color: Colors.white),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
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
