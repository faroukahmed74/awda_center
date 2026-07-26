import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/users/users_screen.dart';
import '../screens/appointments/appointments_screen.dart';
import '../screens/appointments/my_appointments_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/users/user_profile_screen.dart';
import '../screens/patients/patients_screen.dart';
import '../screens/patients/patient_detail_screen.dart';
import '../screens/patients/patient_sessions_packages_admin_screen.dart';
import '../screens/income_expenses/income_expenses_screen.dart';
import '../screens/income_expenses/finance_summary_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/doctors/doctors_list_screen.dart';
import '../screens/doctors/my_doctor_profile_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/requirements/requirements_screen.dart';
import '../screens/admin_todos/admin_todos_screen.dart';
import '../screens/rooms/rooms_screen.dart';
import '../screens/services/services_screen.dart';
import '../screens/packages/packages_screen.dart';
import '../screens/price_quote/price_quote_screen.dart';
import '../screens/audit/audit_log_screen.dart';
import '../screens/doctors/doctors_admin_screen.dart';
import '../screens/chat/chat_inbox_screen.dart';
import '../screens/chat/chat_thread_screen.dart';
import '../screens/chat/chat_new_screen.dart';
import '../screens/chat/chat_settings_screen.dart';
import '../screens/chat/chat_broadcast_screen.dart';
import '../screens/chat/chat_group_new_screen.dart';
import '../screens/chat/chat_group_info_screen.dart';

final GlobalKey<NavigatorState> appRootNavigatorKey = GlobalKey<NavigatorState>();

/// Pending deep-link path (e.g. `/chat/xyz`) set by notification taps before router is ready.
String? pendingNotificationRoute;

void goPendingNotificationRoute(GoRouter router) {
  final path = pendingNotificationRoute;
  if (path == null || path.isEmpty) return;
  pendingNotificationRoute = null;
  router.go(path);
}

void handleNotificationNavigation(Map<String, dynamic>? data) {
  if (data == null || data.isEmpty) return;
  final type = data['type']?.toString() ?? '';
  String? path;
  if (type == 'chat_message' || type == 'chat_broadcast') {
    final id = data['conversationId']?.toString();
    if (id != null && id.isNotEmpty) path = '/chat/$id';
  } else if (type.startsWith('appointment')) {
    path = '/appointments';
  }
  if (path == null) return;
  final ctx = appRootNavigatorKey.currentContext;
  if (ctx != null) {
    try {
      GoRouter.of(ctx).go(path);
      return;
    } catch (_) {}
  }
  pendingNotificationRoute = path;
}

GoRouter createAppRouter(BuildContext context) {
  final authProvider = context.read<AuthProvider>();
  return GoRouter(
    navigatorKey: appRootNavigatorKey,
    initialLocation: '/login',
    // Re-run redirect on login/logout only — not when locale/theme rebuilds the app.
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isLoggedIn = authProvider.currentUser != null;
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register' || state.matchedLocation == '/forgot-password';
      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      final user = authProvider.currentUser;
      if (user != null && !user.isActive && !isAuthRoute) return '/login';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/users',
        builder: (context, state) => const UsersScreen(),
      ),
      GoRoute(
        path: '/appointments',
        builder: (context, state) => const AppointmentsScreen(),
      ),
      GoRoute(
        path: '/my-appointments',
        builder: (context, state) => const MyAppointmentsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/users/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return UserProfileScreen(userId: id);
        },
      ),
      GoRoute(
        path: '/patients',
        builder: (context, state) => PatientsScreen(
          initialSearchQuery: state.uri.queryParameters['q'],
          focusSearch: state.uri.queryParameters['focus'] == 'search',
        ),
      ),
      GoRoute(
        path: '/patients/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PatientDetailScreen(patientId: id);
        },
      ),
      GoRoute(
        path: '/patients/:id/sessions-admin',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PatientSessionsPackagesAdminScreen(patientId: id);
        },
      ),
      GoRoute(
        path: '/income-expenses',
        builder: (context, state) => const IncomeExpensesScreen(),
      ),
      GoRoute(
        path: '/income-expenses-summary',
        builder: (context, state) => const FinanceSummaryScreen(),
      ),
      GoRoute(
        path: '/doctors',
        builder: (context, state) => const DoctorsListScreen(),
      ),
      GoRoute(
        path: '/my-doctor-profile',
        builder: (context, state) => const MyDoctorProfileScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/requirements',
        builder: (context, state) => const RequirementsScreen(),
      ),
      GoRoute(
        path: '/admin-todos',
        builder: (context, state) => const AdminTodosScreen(),
      ),
      GoRoute(
        path: '/rooms',
        builder: (context, state) => const RoomsScreen(),
      ),
      GoRoute(
        path: '/services',
        builder: (context, state) => const ServicesScreen(),
      ),
      GoRoute(
        path: '/packages',
        builder: (context, state) => const PackagesScreen(),
      ),
      GoRoute(
        path: '/price-quote',
        builder: (context, state) => const PriceQuoteScreen(),
      ),
      GoRoute(
        path: '/audit-log',
        builder: (context, state) => const AuditLogScreen(),
      ),
      GoRoute(
        path: '/doctors-admin',
        builder: (context, state) => const DoctorsAdminScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatInboxScreen(),
      ),
      GoRoute(
        path: '/chat/new',
        builder: (context, state) => const ChatNewScreen(),
      ),
      GoRoute(
        path: '/chat/settings',
        builder: (context, state) => const ChatSettingsScreen(),
      ),
      GoRoute(
        path: '/chat/broadcast',
        builder: (context, state) => const ChatBroadcastScreen(),
      ),
      GoRoute(
        path: '/chat/group/new',
        builder: (context, state) => const ChatGroupNewScreen(),
      ),
      GoRoute(
        path: '/chat/:id/info',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ChatGroupInfoScreen(conversationId: id);
        },
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ChatThreadScreen(conversationId: id);
        },
      ),
    ],
  );
}

/// Access by user: uses per-feature permission (or role defaults) so specific privileges appear correctly.
bool canAccessRoute(UserModel? user, String path) {
  if (user == null) return false;
  switch (path) {
    case '/dashboard':
    case '/doctors':
    case '/price-quote':
      return true;
    case '/my-doctor-profile':
      return user.hasRole(UserRole.doctor);
    case '/my-appointments':
      return user.hasRole(UserRole.patient);
    case '/profile':
      return true;
    case '/admin-dashboard':
      return user.canAccessFeature('admin_dashboard');
    case '/users':
      return user.canAccessFeature('users');
    case '/appointments':
      return user.canAccessFeature('appointments') || user.canAccessFeature('appointments_view_all');
    case '/patients':
      return user.canAccessFeature('patients');
    case '/income-expenses':
      return user.canAccessFeature('income_expenses');
    case '/income-expenses-summary':
      return user.canAccessFeature('finance_summary');
    case '/reports':
      return user.canAccessFeature('reports');
    case '/requirements':
      return user.canAccessFeature('requirements');
    case '/admin-todos':
      return user.canAccessFeature('admin_todos');
    case '/chat':
    case '/chat/new':
    case '/chat/settings':
    case '/chat/broadcast':
    case '/chat/group/new':
      return user.canAccessChat;
    case '/rooms':
    case '/services':
    case '/packages':
    case '/audit-log':
    case '/doctors-admin':
      return user.canAccessFeature('admin_dashboard');
    default:
      if (path.startsWith('/users/')) return user.canAccessFeature('users');
      if (path.startsWith('/chat/')) return user.canAccessChat;
      return false;
  }
}
