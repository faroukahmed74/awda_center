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
import '../screens/audit/audit_log_screen.dart';
import '../screens/doctors/doctors_admin_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter(BuildContext context) {
  final authProvider = context.read<AuthProvider>();
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
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
        path: '/audit-log',
        builder: (context, state) => const AuditLogScreen(),
      ),
      GoRoute(
        path: '/doctors-admin',
        builder: (context, state) => const DoctorsAdminScreen(),
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
      return user.canAccessFeature('appointments');
    case '/patients':
      return user.canAccessFeature('patients');
    case '/income-expenses':
    case '/income-expenses-summary':
      return user.canAccessFeature('income_expenses');
    case '/reports':
      return user.canAccessFeature('reports');
    case '/requirements':
      return user.canAccessFeature('requirements');
    case '/admin-todos':
      return user.canAccessFeature('admin_todos');
    case '/rooms':
    case '/services':
    case '/packages':
    case '/audit-log':
    case '/doctors-admin':
      return user.canAccessFeature('admin_dashboard');
    default:
      if (path.startsWith('/users/')) return user.canAccessFeature('users');
      return false;
  }
}
