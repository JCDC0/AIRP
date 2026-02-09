import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/scale_provider.dart';
import 'screens/chat_screen.dart';

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

class AIRP extends StatelessWidget {
  const AIRP({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'AIRP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        textTheme: themeProvider.currentTextTheme,
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.appThemeColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF1E1E1E),
        ),
      ),
      home: const ChatScreen(),
    );
  }
}