import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/vfx_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/scale_provider.dart';
import 'providers/local_library_provider.dart';
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
        ChangeNotifierProvider(create: (_) => VfxProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProxyProvider<SettingsProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, settings, chat) => chat!..updateSettings(settings),
        ),
        ChangeNotifierProvider(create: (_) => ScaleProvider()),
        ChangeNotifierProvider(create: (_) => LocalLibraryProvider()),
      ],
      child: const AIRP(),
    ),
  );
}

/// The root widget of the application.
///
/// Configures the global theme, typography, and initial navigation route, and
/// flushes the debounced session autosave when the app leaves the foreground.
class AIRP extends StatefulWidget {
  const AIRP({super.key});

  @override
  State<AIRP> createState() => _AIRPState();
}

class _AIRPState extends State<AIRP> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      context.read<ChatProvider>().flushPendingSave();
    }
  }

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
        drawerTheme: DrawerThemeData(
          backgroundColor: themeProvider.surfaceColor,
        ),
      ),
      home: const ChatScreen(),
    );
  }
}
