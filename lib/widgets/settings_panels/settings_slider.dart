import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

/// A customizable slider widget used for adjusting numeric settings.
///
/// This widget includes a descriptive label, a numeric input field for
/// precise adjustments, and a visual slider.
class SettingsSlider extends StatefulWidget {
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

  /// Optional color for the title text.
  final Color? titleColor;

  /// Optional font weight for the title text.
  final FontWeight? titleFontWeight;

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
    this.titleColor,
    this.titleFontWeight,
  });

  @override
  State<SettingsSlider> createState() => _SettingsSliderState();
}

class _SettingsSliderState extends State<SettingsSlider> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  String _formatValue(double val) =>
      widget.isInt ? val.toInt().toString() : val.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue(widget.value));
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(SettingsSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus &&
        (oldWidget.value != widget.value || oldWidget.isInt != widget.isInt)) {
      _controller.text = _formatValue(widget.value);
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _submit(_controller.text);
    }
  }

  void _submit(String val) {
    double? parsed = double.tryParse(val);
    if (parsed != null) {
      if (parsed < widget.min) parsed = widget.min;
      if (parsed > widget.max) parsed = widget.max;
      widget.onChanged(parsed);
      _controller.text = _formatValue(parsed);
    } else {
      _controller.text = _formatValue(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: widget.titleFontWeight,
                  color: widget.titleColor ?? Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              height: 32,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(
                  fontSize: widget.fontSize,
                  color: themeProvider.textColor,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  filled: true,
                  fillColor: themeProvider.dividerColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  double? parsed = double.tryParse(val);
                  if (parsed != null &&
                      parsed >= widget.min &&
                      parsed <= widget.max) {
                    widget.onChanged(parsed);
                  }
                },
                onSubmitted: _submit,
              ),
            ),
          ],
        ),
        Slider(
          value: widget.value.clamp(widget.min, widget.max),
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions,
          activeColor: widget.activeColor,
          onChanged: (v) {
            widget.onChanged(v);
            _controller.text = _formatValue(v);
          },
        ),
      ],
    );
  }
}
