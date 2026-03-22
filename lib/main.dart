import 'package:flutter/material.dart';
import 'auth_gate.dart';

import 'ui/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

import 'screens/onboarding_screen.dart';

final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EssenzaApp());
}

class EssenzaApp extends StatelessWidget {
  const EssenzaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // Tema central (la “marca” de tu app)
      theme: AppTheme.theme(),

      // Snackbars globales si los necesitas
      scaffoldMessengerKey: appMessengerKey,

      // Rutas (te simplifica la vida)
      routes: {
        '/': (_) => const AuthGate(),
        '/login': (_) => const LoginScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/dashboard': (_) => const DashboardScreen(),
      },

      // Si quieres controlar el comportamiento del scroll (estética más limpia)
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: const _NoGlowScrollBehavior(),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

// Quita el brillo azul de Android al llegar al límite de scroll (más “premium”)
class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    
    BuildContext context,
    Widget child,
    ScrollableDetails condetails,
  ) {
    return child;
  }
}
