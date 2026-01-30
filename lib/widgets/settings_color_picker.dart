import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../../providers/scale_provider.dart';

class SettingsColorPicker extends StatelessWidget {
  final String label;
  final Color color;
  final Function(Color) onSave;

  const SettingsColorPicker({
    super.key,
    required this.label,
    required this.color,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final scaleProvider = Provider.of<ScaleProvider>(context);
    return Column(
      children: [
        GestureDetector(
          onTap: () => _showColorPickerDialog(context, color, onSave, scaleProvider), 
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.7, color: Colors.grey)),
      ],
    );
  }

  void _showColorPickerDialog(BuildContext context, Color initialColor, Function(Color) onSave, ScaleProvider scaleProvider) {
    Color tempColor = initialColor;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2C2C2C),
            title: Text("Pick a Color", style: TextStyle(color: Colors.white, fontSize: scaleProvider.systemFontSize)),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: tempColor,
                onColorChanged: (c) => setDialogState(() => tempColor = c),
                pickerAreaHeightPercent: 0.7,
                enableAlpha: false,
                displayThumbColor: true,
                paletteType: PaletteType.hsvWithHue,
              ),
            ),
            actions: [
              TextButton(child: const Text("Cancel"), onPressed: () => Navigator.pop(context)),
              TextButton(
                child: Text("Done", style: TextStyle(color: Colors.cyanAccent, fontSize: scaleProvider.systemFontSize * 0.8)),
                onPressed: () {
                  onSave(tempColor);
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
