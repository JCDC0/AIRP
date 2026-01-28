import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class SettingsHeader extends StatelessWidget {
  const SettingsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Text("Main Settings", 
          style: TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.bold, 
            color: themeProvider.appThemeColor,
            shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [],
          )
        ),
        const Text("v0.3.4", 
          style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold, 
            color: Colors.grey
            )),
        const Divider(),
      ],
    );
  }
}
