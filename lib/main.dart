import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'providers/app_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'widgets/security_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safely attempt to initialize Firebase
  try {
    await Firebase.initializeApp();
    debugPrint("Firebase Initialized Successfully!");
  } catch (e) {
    // If Firebase fails, the app won't freeze. It will print the error here.
    debugPrint("Firebase Initialization Error: $e");
  }

  // Force 120Hz / highest available refresh rate on Android
  if (Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      debugPrint('Could not set high refresh rate: $e');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const HelyTvApp(),
    ),
  );
}

class HelyTvApp extends StatelessWidget {
  const HelyTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(builder: (context, themeProvider, child) {
      return MaterialApp(
        title: 'HelyTV.me',
        debugShowCheckedModeBanner: false,
        themeMode: themeProvider.themeMode,
        theme: ThemeData(
          brightness: Brightness.light,
          primaryColor: const Color(0xFF2563EB),
          scaffoldBackgroundColor: const Color(0xFFF3F4F6),
          cardColor: Colors.white,
          useMaterial3: true,
          textTheme:
              GoogleFonts.robotoCondensedTextTheme(ThemeData.light().textTheme),
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF2563EB),
          scaffoldBackgroundColor: const Color(0xFF0f0f0f),
          cardColor: const Color(0xFF1a1a1a),
          useMaterial3: true,
          textTheme:
              GoogleFonts.robotoCondensedTextTheme(ThemeData.dark().textTheme),
        ),
        home: const SecurityWrapper(
          child: SplashScreen(),
        ),
      );
    });
  }
}
