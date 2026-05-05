/// Fatigue Dashboard App
///
/// Real-time mobile dashboard for the Screen Fatigue Monitoring System.
/// Connects to the Python backend via HTTP to display fatigue status,
/// eye aspect ratio, blink count, and fatigue score.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const FatigueDashboardApp());
}

class FatigueDashboardApp extends StatelessWidget {
  const FatigueDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fatigue Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF58A6FF),
          secondary: const Color(0xFF7EE787),
          surface: const Color(0xFF161B22),
          error: const Color(0xFFFF6B6B),
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF161B22),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        // Smooth page transitions
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case '/login':
            page = const LoginScreen();
            break;
          case '/home':
            page = const HomeScreen();
            break;
          case '/stats':
            page = const StatsScreen();
            break;
          case '/settings':
            page = const SettingsScreen();
            break;
          default:
            page = const LoginScreen();
        }

        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;
            final tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            final fadeTween = Tween<double>(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 350),
        );
      },
    );
  }
}
