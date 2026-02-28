import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/scale_provider.dart';
import 'screens/chat_screen.dart';

/// The entry point for the AIRP application.
///
/// This file initializes the application's state management using Provider
/// and sets up the root Material application with the appropriate theme.
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ScaleProvider()),
      ],
      child: const AIRP(),
    ),
  );
}

/// The root widget of the application.
///
/// Configures the global theme, typography, and initial navigation route.
class AIRP extends StatelessWidget {
  const AIRP({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'AIRP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: themeProvider.brightness,
        textTheme: themeProvider.currentTextTheme,
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.appThemeColor,
          brightness: themeProvider.brightness,
        ),
        useMaterial3: true,
        drawerTheme: DrawerThemeData(backgroundColor: themeProvider.surfaceColor),
      ),
      home: const ChatScreen(),
    );
  }
}
