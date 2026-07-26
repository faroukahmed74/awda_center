/// Feature keys that admins can grant to any user (dynamic privileges).
const List<String> kAllFeatureKeys = [
  'admin_dashboard',
  'users',
  'appointments',
  'appointments_see_all', // When granted to a doctor: they see all appointments; otherwise only their own.
  'appointments_view_all', // View all appointments (list + schedule) with no create/edit/status change.
  'patients',
  'patients_edit', // Allows editing patient profile (personal + medical) from patient detail screen.
  'income_expenses',
  'finance_summary',
  'reports',
  'requirements',
  'admin_todos',
  // Chat (admin can grant any of these to any user)
  'chat',
  'chat_start',
  'chat_message_anyone',
  'chat_send_text',
  'chat_send_image',
  'chat_send_video',
  'chat_send_audio',
  'chat_send_voice',
  'chat_send_document',
  'chat_send_any_media',
  'chat_save_media',
  'chat_view_all',
  'chat_broadcast',
  'chat_create_group',
  'chat_manage_group',
  'chat_manage_retention',
  'chat_delete_any',
  'chat_delete',
  'chat_settings',
];

/// Default chat features for staff/patients when using role defaults.
const List<String> kDefaultChatFeatures = [
  'chat',
  'chat_start',
  'chat_message_anyone',
  'chat_send_text',
  'chat_send_image',
  'chat_send_video',
  'chat_send_audio',
  'chat_send_voice',
  'chat_send_document',
  'chat_send_any_media',
  'chat_save_media',
  'chat_create_group',
  'chat_delete',
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
    case '/chat':
    case '/chat/settings':
      return 'chat';
    default:
      if (path.startsWith('/chat/')) return 'chat';
      return null;
  }
}

/// Default feature keys granted by role when user has no explicit permissions.
List<String> defaultFeaturesForRole(String roleValue) {
  switch (roleValue) {
    case 'admin':
      return List.from(kAllFeatureKeys);
    case 'supervisor':
      return [
        'admin_dashboard',
        'users',
        'appointments',
        'patients',
        'income_expenses',
        'reports',
        ...kDefaultChatFeatures,
        'chat_view_all',
        'chat_broadcast',
        'chat_create_group',
        'chat_manage_group',
        'chat_settings',
      ];
    case 'secretary':
      return [
        'users',
        'appointments',
        'reports',
        ...kDefaultChatFeatures,
        'chat_view_all',
        'chat_manage_group',
      ];
    case 'doctor':
      return [
        'appointments',
        'patients',
        'reports',
        ...kDefaultChatFeatures,
      ];
    case 'patient':
      return List.from(kDefaultChatFeatures);
    case 'trainee':
      return List.from(kDefaultChatFeatures);
    default:
      return [];
  }
}
