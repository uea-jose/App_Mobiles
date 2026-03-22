import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  static const _kOnboardingDoneKey = 'onboarding_done';

  Future<_AuthGateTarget> _resolveTarget(AuthService auth) async {
    final loggedIn = await auth.isLoggedIn();
    if (loggedIn) {
      return _AuthGateTarget.dashboard;
    }

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool(_kOnboardingDoneKey) ?? false;
    if (!onboardingDone) {
      return _AuthGateTarget.onboarding;
    }

    return _AuthGateTarget.login;
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    return FutureBuilder<_AuthGateTarget>(
      future: _resolveTarget(auth),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.data == _AuthGateTarget.dashboard) {
          return const DashboardScreen();
        }

        if (snap.data == _AuthGateTarget.onboarding) {
          return const OnboardingScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

enum _AuthGateTarget {
  onboarding,
  login,
  dashboard,
}
