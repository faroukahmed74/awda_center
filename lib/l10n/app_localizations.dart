import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ar'),
  ];

  bool get isArabic => locale.languageCode == 'ar';

  /// Display label for a role value (e.g. 'secretary' -> 'Secretary').
  String roleDisplay(String roleValue) => _map[roleValue] ?? roleValue;

  // App
  String get appTitle => _map['appTitle']!;
  String get login => _map['login']!;
  String get signInWithGoogle => _map['signInWithGoogle']!;
  String get orContinueWithEmail => _map['orContinueWithEmail']!;
  String get register => _map['register']!;
  String get forgotPassword => _map['forgotPassword']!;
  String get resetPassword => _map['resetPassword']!;
  String get checkYourEmail => _map['checkYourEmail']!;
  String get personalData => _map['personalData']!;
  String get viewProfile => _map['viewProfile']!;
  String get editMyInfo => _map['editMyInfo']!;
  String get logout => _map['logout']!;
  String get email => _map['email']!;
  String get password => _map['password']!;
  String get changePassword => _map['changePassword']!;
  String get currentPassword => _map['currentPassword']!;
  String get newPassword => _map['newPassword']!;
  String get confirmNewPassword => _map['confirmNewPassword']!;
  String get passwordChanged => _map['passwordChanged']!;
  String get changePasswordGoogleHint => _map['changePasswordGoogleHint']!;
  String get fullNameAr => _map['fullNameAr']!;
  String get fullNameEn => _map['fullNameEn']!;
  String get phone => _map['phone']!;
  String get dashboard => _map['dashboard']!;
  String get users => _map['users']!;
  String get appointments => _map['appointments']!;
  String get myAppointments => _map['myAppointments']!;
  String get profile => _map['profile']!;
  String get patients => _map['patients']!;
  String get patientDetail => _map['patientDetail']!;
  String get incomeAndExpenses => _map['incomeAndExpenses']!;
  String get income => _map['income']!;
  String get expenses => _map['expenses']!;
  String get net => _map['net']!;
  String get totalIncome => _map['totalIncome']!;
  String get totalExpenses => _map['totalExpenses']!;
  String get addIncome => _map['addIncome']!;
  String get addExpense => _map['addExpense']!;
  String get role => _map['role']!;
  String get active => _map['active']!;
  String get inactive => _map['inactive']!;
  String get date => _map['date']!;
  String get time => _map['time']!;
  String get status => _map['status']!;
  String get doctor => _map['doctor']!;
  String get patient => _map['patient']!;
  String get notes => _map['notes']!;
  String get sessions => _map['sessions']!;
  String get documents => _map['documents']!;
  String get amount => _map['amount']!;
  String get source => _map['source']!;
  String get category => _map['category']!;
  String get description => _map['description']!;
  String get employeeOptional => _map['employeeOptional']!;
  String get save => _map['save']!;
  String get cancel => _map['cancel']!;
  String get confirm => _map['confirm']!;
  String get welcome => _map['welcome']!;
  String get noData => _map['noData']!;
  String get filterByRole => _map['filterByRole']!;
  String get filterAll => _map['filterAll']!;
  String get allRoles => _map['allRoles']!;
  String get admin => _map['admin']!;
  String get secretary => _map['secretary']!;
  String get trainee => _map['trainee']!;
  String get pending => _map['pending']!;
  String get confirmed => _map['confirmed']!;
  String get completed => _map['completed']!;
  String get cancelled => _map['cancelled']!;
  String get noShow => _map['noShow']!;
  String get updateStatus => _map['updateStatus']!;
  String get name => _map['name']!;
  String get service => _map['service']!;
  String get currency => _map['currency']!;
  String get adminDashboard => _map['adminDashboard']!;
  String get inviteUser => _map['inviteUser']!;
  String get totalUsers => _map['totalUsers']!;
  String get activeUsers => _map['activeUsers']!;
  String get todayAppointments => _map['todayAppointments']!;
  String get thisWeekAppointments => _map['thisWeekAppointments']!;
  String get openTodos => _map['openTodos']!;
  String get manageUsers => _map['manageUsers']!;
  String get inviteUserHint => _map['inviteUserHint']!;
  String get ourDoctors => _map['ourDoctors']!;
  String get myDoctorProfile => _map['myDoctorProfile']!;
  String get qualifications => _map['qualifications']!;
  String get certifications => _map['certifications']!;
  String get specialization => _map['specialization']!;
  String get medicalHistory => _map['medicalHistory']!;
  String get treatmentProgress => _map['treatmentProgress']!;
  String get progressNotes => _map['progressNotes']!;
  String get editProfile => _map['editProfile']!;
  String get editUser => _map['editUser']!;
  String get deleteUser => _map['deleteUser']!;
  String get search => _map['search']!;
  String get about => _map['about']!;
  String get addNote => _map['addNote']!;
  String get addImage => _map['addImage']!;
  String get addPdf => _map['addPdf']!;
  String get addedAt => _map['addedAt']!;
  String get updatedAt => _map['updatedAt']!;
  String get salary => _map['salary']!;
  String get availableTime => _map['availableTime']!;
  String get uploadFileImageOrPdf => _map['uploadFileImageOrPdf']!;
  String get uploading => _map['uploading']!;
  String get orPasteUrlImageOrPdf => _map['orPasteUrlImageOrPdf']!;
  String get titleOrFileName => _map['titleOrFileName']!;
  String get type => _map['type']!;
  String get required => _map['required']!;
  String get uploadOrPasteUrl => _map['uploadOrPasteUrl']!;
  String get editDocument => _map['editDocument']!;
  String get reports => _map['reports']!;
  String get requirements => _map['requirements']!;
  String get toDoList => _map['toDoList']!;
  String get patientsReport => _map['patientsReport']!;
  String get incomeReport => _map['incomeReport']!;
  String get incomeExpensesReport => _map['incomeExpensesReport']!;
  String get appointmentsReport => _map['appointmentsReport']!;
  String get usersReport => _map['usersReport']!;
  String get exportPatients => _map['exportPatients']!;
  String get exportUsers => _map['exportUsers']!;
  String get exportAuditLog => _map['exportAuditLog']!;
  String get byStatus => _map['byStatus']!;
  String get occupation => _map['occupation']!;
  String get referredBy => _map['referredBy']!;
  String get maritalStatus => _map['maritalStatus']!;
  String get areasToTreat => _map['areasToTreat']!;
  String get feesType => _map['feesType']!;
  String get diagnosis => _map['diagnosis']!;
  String get gender => _map['gender']!;
  String get dateOfBirth => _map['dateOfBirth']!;
  String get addRequirement => _map['addRequirement']!;
  String get addTodo => _map['addTodo']!;
  String get dueDate => _map['dueDate']!;
  String get reminder => _map['reminder']!;
  String get day => _map['day']!;
  String get month => _map['month']!;
  String get year => _map['year']!;
  String get total => _map['total']!;
  String get createAppointment => _map['createAppointment']!;
  String get bookAppointment => _map['bookAppointment']!;
  String get editAppointment => _map['editAppointment']!;
  String get room => _map['room']!;
  String get rooms => _map['rooms']!;
  String get addRoom => _map['addRoom']!;
  String get editRoom => _map['editRoom']!;
  String get deleteConfirm => _map['deleteConfirm']!;
  String get confirmAction => _map['confirmAction']!;
  String get quantity => _map['quantity']!;
  String get address => _map['address']!;
  String get auditLog => _map['auditLog']!;
  String get export => _map['export']!;
  String get exportIncomeExpense => _map['exportIncomeExpense']!;
  String get exportAppointments => _map['exportAppointments']!;
  String get openLink => _map['openLink']!;
  String get viewImage => _map['viewImage']!;
  String get viewPdf => _map['viewPdf']!;
  String get createProfile => _map['createProfile']!;
  String get manageDoctors => _map['manageDoctors']!;
  String get addDoctor => _map['addDoctor']!;
  String get edit => _map['edit']!;
  String get quickAccess => _map['quickAccess']!;
  String get notifications => _map['notifications']!;
  String get noNotifications => _map['noNotifications']!;
  String get retry => _map['retry']!;
  // Notification text (used in push and local notifications)
  String get notificationReminderTitle => _map['notificationReminderTitle']!;
  String get notificationReminderBody => _map['notificationReminderBody']!;
  String get notificationAppointmentConfirmed => _map['notificationAppointmentConfirmed']!;
  String get notificationAppointmentCompleted => _map['notificationAppointmentCompleted']!;
  String get notificationAppointmentCancelled => _map['notificationAppointmentCancelled']!;
  String get notificationAppointmentNoShow => _map['notificationAppointmentNoShow']!;
  String get notificationTodoReminderTitle => _map['notificationTodoReminderTitle']!;

  /// User-friendly auth error message for login/register. Returns localized text for known keys, or [key] if unknown.
  String authErrorMessage(String? key) => key == null ? '' : (_map[key] ?? key);

  Map<String, String> get _map => locale.languageCode == 'ar' ? _ar : _en;

  static const Map<String, String> _en = {
    'appTitle': 'Awda Center',
    'login': 'Login',
    'signInWithGoogle': 'Sign in with Google',
    'orContinueWithEmail': 'Or continue with email',
    'register': 'Register',
    'forgotPassword': 'Forgot password?',
    'resetPassword': 'Reset password',
    'checkYourEmail': 'Check your email for a link to reset your password.',
    'personalData': 'Personal data',
    'viewProfile': 'View profile',
    'editMyInfo': 'Edit my info',
    'logout': 'Logout',
    'email': 'Email',
    'password': 'Password',
    'changePassword': 'Change password',
    'currentPassword': 'Current password',
    'newPassword': 'New password',
    'confirmNewPassword': 'Confirm new password',
    'passwordChanged': 'Password changed successfully.',
    'changePasswordGoogleHint': 'You signed in with Google. Change your password in your Google account settings.',
    'fullNameAr': 'Full name (Arabic)',
    'fullNameEn': 'Full name (English)',
    'phone': 'Phone',
    'dashboard': 'Dashboard',
    'users': 'Users',
    'appointments': 'Appointments',
    'myAppointments': 'My Appointments',
    'profile': 'Profile',
    'patients': 'Patients',
    'patientDetail': 'Patient detail',
    'incomeAndExpenses': 'Income & Expenses',
    'income': 'Income',
    'expenses': 'Expenses',
    'net': 'Net',
    'totalIncome': 'Total income',
    'totalExpenses': 'Total expenses',
    'addIncome': 'Add income',
    'addExpense': 'Add expense',
    'role': 'Role',
    'active': 'Active',
    'inactive': 'Inactive',
    'date': 'Date',
    'time': 'Time',
    'status': 'Status',
    'doctor': 'Doctor',
    'patient': 'Patient',
    'notes': 'Notes',
    'sessions': 'Sessions',
    'documents': 'Documents',
    'amount': 'Amount',
    'source': 'Source',
    'category': 'Category',
    'description': 'Description',
    'employeeOptional': 'Employee (optional)',
    'save': 'Save',
    'cancel': 'Cancel',
    'confirm': 'Confirm',
    'welcome': 'Welcome',
    'noData': 'No data',
    'filterByRole': 'Filter by role',
    'filterAll': 'All',
    'allRoles': 'All roles',
    'admin': 'Admin',
    'secretary': 'Secretary',
    'trainee': 'Trainee',
    'pending': 'Pending',
    'confirmed': 'Confirmed',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
    'noShow': 'No show',
    'updateStatus': 'Update status',
    'name': 'Name',
    'service': 'Service',
    'currency': 'Currency',
    'adminDashboard': 'Admin Dashboard',
    'inviteUser': 'Invite user',
    'totalUsers': 'Total users',
    'activeUsers': 'Active users',
    'todayAppointments': 'Today\'s appointments',
    'thisWeekAppointments': 'This week\'s appointments',
    'openTodos': 'Open to-dos',
    'manageUsers': 'Manage users',
    'inviteUserHint': 'User will get this role when they register with this email.',
    'ourDoctors': 'Our doctors',
    'myDoctorProfile': 'My doctor profile',
    'qualifications': 'Qualifications',
    'certifications': 'Certifications',
    'specialization': 'Specialization',
    'medicalHistory': 'Medical history',
    'treatmentProgress': 'Treatment progress',
    'progressNotes': 'Progress notes',
    'editProfile': 'Edit profile',
    'editUser': 'Edit user',
    'deleteUser': 'Delete user',
    'search': 'Search',
    'about': 'About',
    'addNote': 'Add note',
    'addImage': 'Add image',
    'addPdf': 'Add PDF',
    'addedAt': 'Added',
    'updatedAt': 'Updated',
    'salary': 'Salary',
    'availableTime': 'Available',
    'uploadFileImageOrPdf': 'Upload file (image or PDF)',
    'uploading': 'Uploading...',
    'orPasteUrlImageOrPdf': 'Or paste URL (image or PDF link)',
    'titleOrFileName': 'Title / file name',
    'type': 'Type',
    'required': 'Required',
    'uploadOrPasteUrl': 'Upload a file or paste URL',
    'editDocument': 'Edit',
    'reports': 'Reports',
    'requirements': 'Requirements to buy',
    'toDoList': 'To-do list',
    'patientsReport': 'Patients report',
    'incomeReport': 'Income report',
    'incomeExpensesReport': 'Income & expenses',
    'appointmentsReport': 'Appointments report',
    'usersReport': 'Users summary',
    'exportPatients': 'Export patients',
    'exportUsers': 'Export users',
    'exportAuditLog': 'Export audit log',
    'byStatus': 'By status',
    'occupation': 'Occupation',
    'referredBy': 'Referred by',
    'maritalStatus': 'Marital status',
    'areasToTreat': 'Areas to treat',
    'feesType': 'Fees type',
    'diagnosis': 'Diagnosis',
    'gender': 'Gender',
    'dateOfBirth': 'Date of birth',
    'addRequirement': 'Add requirement',
    'addTodo': 'Add to-do',
    'dueDate': 'Due date',
    'reminder': 'Reminder',
    'day': 'Day',
    'month': 'Month',
    'year': 'Year',
    'total': 'Total',
    'createAppointment': 'Create appointment',
    'bookAppointment': 'Book appointment',
    'editAppointment': 'Edit appointment',
    'room': 'Room',
    'rooms': 'Rooms',
    'addRoom': 'Add room',
    'editRoom': 'Edit room',
    'deleteConfirm': 'Delete?',
    'confirmAction': 'Confirm',
    'quantity': 'Quantity',
    'address': 'Address',
    'auditLog': 'Audit log',
    'export': 'Export',
    'exportIncomeExpense': 'Export income & expense',
    'exportAppointments': 'Export appointments',
    'openLink': 'Open link',
    'viewImage': 'View image',
    'viewPdf': 'View PDF',
    'createProfile': 'Create profile',
    'manageDoctors': 'Manage doctors',
    'addDoctor': 'Add doctor',
    'edit': 'Edit',
    'quickAccess': 'Quick access',
    'notifications': 'Notifications',
    'noNotifications': 'No notifications',
    'retry': 'Retry',
    'notificationReminderTitle': 'Appointment reminder',
    'notificationReminderBody': 'Session on {date} at {time}',
    'notificationAppointmentConfirmed': 'Appointment confirmed',
    'notificationAppointmentCompleted': 'Appointment completed',
    'notificationAppointmentCancelled': 'Appointment cancelled',
    'notificationAppointmentNoShow': 'Appointment marked no-show',
    'notificationTodoReminderTitle': 'To-do reminder',
    'authErrorInvalidEmail': 'Please enter a valid email address.',
    'authErrorInvalidCredentials': 'Invalid email or password. Please try again.',
    'authErrorEmailAlreadyInUse': 'This email is already registered. Try logging in or use another email.',
    'authErrorWeakPassword': 'Password is too weak. Use at least 6 characters.',
    'authErrorAccountDeactivated': 'This account has been deactivated. Contact support.',
    'authErrorUserDisabled': 'This account has been disabled. Contact support.',
    'authErrorTooManyRequests': 'Too many attempts. Please try again later.',
    'authErrorNetwork': 'Connection error. Check your internet and try again.',
    'authErrorTryAgain': 'Something went wrong. Please try again.',
    'authErrorNoAccountWithEmail': 'No account found with this email.',
  };

  static const Map<String, String> _ar = {
    'appTitle': 'مركز عودة',
    'login': 'تسجيل الدخول',
    'signInWithGoogle': 'تسجيل الدخول بـ Google',
    'orContinueWithEmail': 'أو متابعة بالبريد الإلكتروني',
    'register': 'إنشاء حساب',
    'forgotPassword': 'نسيت كلمة المرور؟',
    'resetPassword': 'إعادة تعيين كلمة المرور',
    'checkYourEmail': 'تحقق من بريدك للحصول على رابط إعادة التعيين.',
    'personalData': 'البيانات الشخصية',
    'viewProfile': 'عرض الملف',
    'editMyInfo': 'تعديل بياناتي',
    'logout': 'تسجيل الخروج',
    'email': 'البريد الإلكتروني',
    'password': 'كلمة المرور',
    'changePassword': 'تغيير كلمة المرور',
    'currentPassword': 'كلمة المرور الحالية',
    'newPassword': 'كلمة المرور الجديدة',
    'confirmNewPassword': 'تأكيد كلمة المرور الجديدة',
    'passwordChanged': 'تم تغيير كلمة المرور بنجاح.',
    'changePasswordGoogleHint': 'تم تسجيل الدخول بحساب Google. غيّر كلمة المرور من إعدادات حساب Google.',
    'fullNameAr': 'الاسم الكامل (عربي)',
    'fullNameEn': 'الاسم الكامل (إنجليزي)',
    'phone': 'الهاتف',
    'dashboard': 'لوحة التحكم',
    'users': 'المستخدمون',
    'appointments': 'المواعيد',
    'myAppointments': 'مواعيدي',
    'profile': 'الملف الشخصي',
    'patients': 'المرضى',
    'patientDetail': 'تفاصيل المريض',
    'incomeAndExpenses': 'الإيرادات والمصروفات',
    'income': 'الإيرادات',
    'expenses': 'المصروفات',
    'net': 'صافي',
    'totalIncome': 'إجمالي الإيرادات',
    'totalExpenses': 'إجمالي المصروفات',
    'addIncome': 'إضافة إيراد',
    'addExpense': 'إضافة مصروف',
    'role': 'الدور',
    'active': 'نشط',
    'inactive': 'غير نشط',
    'date': 'التاريخ',
    'time': 'الوقت',
    'status': 'الحالة',
    'doctor': 'الطبيب',
    'patient': 'المريض',
    'notes': 'ملاحظات',
    'sessions': 'الجلسات',
    'documents': 'المستندات',
    'amount': 'المبلغ',
    'source': 'المصدر',
    'category': 'الفئة',
    'description': 'الوصف',
    'employeeOptional': 'الموظف (اختياري)',
    'save': 'حفظ',
    'cancel': 'إلغاء',
    'confirm': 'تأكيد',
    'welcome': 'مرحباً',
    'noData': 'لا توجد بيانات',
    'filterByRole': 'تصفية حسب الدور',
    'filterAll': 'الكل',
    'allRoles': 'جميع الأدوار',
    'admin': 'مدير',
    'secretary': 'سكرتير',
    'trainee': 'متدرب',
    'pending': 'قيد الانتظار',
    'confirmed': 'مؤكد',
    'completed': 'مكتمل',
    'cancelled': 'ملغي',
    'noShow': 'لم يحضر',
    'updateStatus': 'تحديث الحالة',
    'name': 'الاسم',
    'service': 'الخدمة',
    'currency': 'العملة',
    'adminDashboard': 'لوحة إدارة النظام',
    'inviteUser': 'دعوة مستخدم',
    'totalUsers': 'إجمالي المستخدمين',
    'activeUsers': 'المستخدمون النشطون',
    'todayAppointments': 'مواعيد اليوم',
    'thisWeekAppointments': 'مواعيد هذا الأسبوع',
    'openTodos': 'مهام مفتوحة',
    'manageUsers': 'إدارة المستخدمين',
    'inviteUserHint': 'سيحصل المستخدم على هذا الدور عند التسجيل بهذا البريد.',
    'ourDoctors': 'أطباؤنا',
    'myDoctorProfile': 'ملفي كطبيب',
    'qualifications': 'المؤهلات',
    'certifications': 'الشهادات',
    'specialization': 'التخصص',
    'medicalHistory': 'التاريخ الطبي',
    'treatmentProgress': 'تقدم العلاج',
    'progressNotes': 'ملاحظات التقدم',
    'editProfile': 'تعديل الملف',
    'editUser': 'تعديل المستخدم',
    'deleteUser': 'حذف المستخدم',
    'search': 'بحث',
    'about': 'نبذة',
    'addNote': 'إضافة ملاحظة',
    'addImage': 'إضافة صورة',
    'addPdf': 'إضافة PDF',
    'addedAt': 'أضيف في',
    'updatedAt': 'حدث في',
    'salary': 'الراتب',
    'availableTime': 'متاح',
    'uploadFileImageOrPdf': 'رفع ملف (صورة أو PDF)',
    'uploading': 'جاري الرفع...',
    'orPasteUrlImageOrPdf': 'أو لصق الرابط (صورة أو PDF)',
    'titleOrFileName': 'العنوان / اسم الملف',
    'type': 'النوع',
    'required': 'مطلوب',
    'uploadOrPasteUrl': 'ارفع ملفاً أو الصق الرابط',
    'editDocument': 'تعديل',
    'reports': 'التقارير',
    'requirements': 'المتطلبات للشراء',
    'toDoList': 'قائمة المهام',
    'patientsReport': 'تقرير المرضى',
    'incomeReport': 'تقرير الإيرادات',
    'incomeExpensesReport': 'الإيرادات والمصروفات',
    'appointmentsReport': 'تقرير المواعيد',
    'usersReport': 'ملخص المستخدمين',
    'exportPatients': 'تصدير المرضى',
    'exportUsers': 'تصدير المستخدمين',
    'exportAuditLog': 'تصدير سجل التدقيق',
    'byStatus': 'حسب الحالة',
    'occupation': 'المهنة',
    'referredBy': 'الإحالة من',
    'maritalStatus': 'الحالة الاجتماعية',
    'areasToTreat': 'مناطق العلاج',
    'feesType': 'نوع الرسوم',
    'diagnosis': 'التشخيص',
    'gender': 'الجنس',
    'dateOfBirth': 'تاريخ الميلاد',
    'addRequirement': 'إضافة متطلب',
    'addTodo': 'إضافة مهمة',
    'dueDate': 'تاريخ الاستحقاق',
    'reminder': 'تذكير',
    'day': 'يوم',
    'month': 'شهر',
    'year': 'سنة',
    'total': 'الإجمالي',
    'createAppointment': 'إنشاء موعد',
    'bookAppointment': 'حجز موعد',
    'editAppointment': 'تعديل الموعد',
    'room': 'غرفة',
    'rooms': 'الغرف',
    'addRoom': 'إضافة غرفة',
    'editRoom': 'تعديل الغرفة',
    'deleteConfirm': 'حذف؟',
    'confirmAction': 'تأكيد',
    'quantity': 'الكمية',
    'address': 'العنوان',
    'auditLog': 'سجل التدقيق',
    'export': 'تصدير',
    'exportIncomeExpense': 'تصدير الإيرادات والمصروفات',
    'exportAppointments': 'تصدير المواعيد',
    'openLink': 'فتح الرابط',
    'viewImage': 'عرض الصورة',
    'viewPdf': 'عرض PDF',
    'createProfile': 'إنشاء الملف الشخصي',
    'manageDoctors': 'إدارة الأطباء',
    'addDoctor': 'إضافة طبيب',
    'edit': 'تعديل',
    'quickAccess': 'وصول سريع',
    'notifications': 'الإشعارات',
    'noNotifications': 'لا توجد إشعارات',
    'retry': 'إعادة المحاولة',
    'notificationReminderTitle': 'تذكير موعد',
    'notificationReminderBody': 'جلسة في {date} الساعة {time}',
    'notificationAppointmentConfirmed': 'تم تأكيد الموعد',
    'notificationAppointmentCompleted': 'تم إكمال الموعد',
    'notificationAppointmentCancelled': 'تم إلغاء الموعد',
    'notificationAppointmentNoShow': 'تم تسجيل عدم الحضور',
    'notificationTodoReminderTitle': 'تذكير مهمة',
    'authErrorInvalidEmail': 'يرجى إدخال بريد إلكتروني صحيح.',
    'authErrorInvalidCredentials': 'البريد الإلكتروني أو كلمة المرور غير صحيحة. حاول مرة أخرى.',
    'authErrorEmailAlreadyInUse': 'هذا البريد مسجل مسبقاً. سجّل الدخول أو استخدم بريداً آخر.',
    'authErrorWeakPassword': 'كلمة المرور ضعيفة. استخدم 6 أحرف على الأقل.',
    'authErrorAccountDeactivated': 'تم إلغاء تفعيل هذا الحساب. تواصل مع الدعم.',
    'authErrorUserDisabled': 'تم تعطيل هذا الحساب. تواصل مع الدعم.',
    'authErrorTooManyRequests': 'محاولات كثيرة. حاول لاحقاً.',
    'authErrorNetwork': 'خطأ في الاتصال. تحقق من الإنترنت وحاول مرة أخرى.',
    'authErrorTryAgain': 'حدث خطأ. حاول مرة أخرى.',
    'authErrorNoAccountWithEmail': 'لا يوجد حساب بهذا البريد الإلكتروني.',
  };
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
