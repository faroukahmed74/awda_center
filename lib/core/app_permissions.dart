/// Feature keys that admins can grant to any user (dynamic privileges).
const List<String> kAllFeatureKeys = [
  'admin_dashboard',
  'users',
  'appointments',
  'appointments_see_all', // When granted to a doctor: they see all appointments; otherwise only their own.
  'appointments_view_all', // View all appointments (list + schedule) with no create/edit/status change.
  'patients',
  'income_expenses',
  'finance_summary',
  'reports',
  'requirements',
  'admin_todos',
];

/// Path to feature key for permission check.
String? pathToFeatureKey(String path) {
  switch (path) {
    case '/admin-dashboard':
      return 'admin_dashboard';
    case '/users':
      return 'users';
    case '/appointments':
      return 'appointments';
    case '/patients':
      return 'patients';
    case '/income-expenses':
      return 'income_expenses';
    case '/income-expenses-summary':
      return 'finance_summary';
    case '/reports':
      return 'reports';
    case '/requirements':
      return 'requirements';
    case '/admin-todos':
      return 'admin_todos';
    default:
      return null;
  }
}

/// Default feature keys granted by role when user has no explicit permissions.
List<String> defaultFeaturesForRole(String roleValue) {
  switch (roleValue) {
    case 'admin':
      return List.from(kAllFeatureKeys);
    case 'supervisor':
      return ['admin_dashboard', 'users', 'appointments', 'patients', 'income_expenses', 'reports'];
    case 'secretary':
      return ['users', 'appointments', 'reports'];
    case 'doctor':
      return ['appointments', 'patients', 'reports'];
    case 'patient':
      return []; // patient-only screens (my_appointments, profile) by role
    case 'trainee':
      return [];
    default:
      return [];
  }
}
