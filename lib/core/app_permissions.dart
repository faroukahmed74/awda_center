/// Feature keys that admins can grant to any user (dynamic privileges).
const List<String> kAllFeatureKeys = [
  'admin_dashboard',
  'users',
  'appointments',
  'patients',
  'income_expenses',
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
    case '/income-expenses-summary':
      return 'income_expenses';
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
