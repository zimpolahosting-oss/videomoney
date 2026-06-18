import 'package:flutter/material.dart';

import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/payout/payout_history_screen.dart';
import 'screens/payout/payout_request_screen.dart';
import 'screens/support/about_screen.dart';
import 'screens/support/help_support_screen.dart';
import 'screens/support/report_bug_screen.dart';
import 'screens/support/settings_screen.dart';

class AppRoutes {
  static const String authGate = '/';
  static const String settings = '/settings';
  static const String helpSupport = '/help-support';
  static const String reportBug = '/report-bug';
  static const String about = '/about';
  static const String adminDashboard = '/admin-dashboard';
  static const String payoutRequest = '/payout-request';
  static const String payoutHistory = '/payout-history';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case authGate:
        return MaterialPageRoute<void>(
          builder: (_) => const AuthGate(),
          settings: settings,
        );
      case AppRoutes.settings:
        return MaterialPageRoute<void>(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );
      case AppRoutes.helpSupport:
        return MaterialPageRoute<void>(
          builder: (_) => const HelpSupportScreen(),
          settings: settings,
        );
      case AppRoutes.reportBug:
        return MaterialPageRoute<void>(
          builder: (_) => const ReportBugScreen(),
          settings: settings,
        );
      case AppRoutes.about:
        return MaterialPageRoute<void>(
          builder: (_) => const AboutScreen(),
          settings: settings,
        );
      case AppRoutes.adminDashboard:
        return MaterialPageRoute<void>(
          builder: (_) => const AdminDashboardScreen(),
          settings: settings,
        );
      case AppRoutes.payoutHistory:
        return MaterialPageRoute<void>(
          builder: (_) => const PayoutHistoryScreen(),
          settings: settings,
        );
      case AppRoutes.payoutRequest:
        final initialMethod = settings.arguments is String
            ? settings.arguments as String
            : null;
        return MaterialPageRoute<void>(
          builder: (_) => PayoutRequestScreen(initialMethod: initialMethod),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const AuthGate(),
          settings: settings,
        );
    }
  }
}
