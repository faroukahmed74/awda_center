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
  String get emailOrPatientCode => _map['emailOrPatientCode']!;
  String get emailOrPatientCodeHint => _map['emailOrPatientCodeHint']!;
  String get changePassword => _map['changePassword']!;
  String get currentPassword => _map['currentPassword']!;
  String get newPassword => _map['newPassword']!;
  String get confirmNewPassword => _map['confirmNewPassword']!;
  String get passwordChanged => _map['passwordChanged']!;
  String get changePasswordGoogleHint => _map['changePasswordGoogleHint']!;
  String get fullNameAr => _map['fullNameAr']!;
  String get fullNameEn => _map['fullNameEn']!;
  String get phone => _map['phone']!;
  /// Secondary / alternate phone (optional field stored as `phone2` in Firestore).
  String get secondaryPhone => _map['secondaryPhone']!;
  String get dashboard => _map['dashboard']!;
  String get users => _map['users']!;
  String get appointments => _map['appointments']!;
  String get appointmentsSeeAll => _map['appointmentsSeeAll']!;
  String get appointmentsViewAll => _map['appointmentsViewAll']!;
  String get myAppointments => _map['myAppointments']!;
  String get profile => _map['profile']!;
  String get patients => _map['patients']!;
  String get patientDetail => _map['patientDetail']!;
  String get incomeAndExpenses => _map['incomeAndExpenses']!;
  String get income => _map['income']!;
  String get expenses => _map['expenses']!;
  String get net => _map['net']!;
  String get netProfit => _map['netProfit']!;
  String get totalIncome => _map['totalIncome']!;
  String get totalExpenses => _map['totalExpenses']!;
  String get financeSummary => _map['financeSummary']!;
  String get target => _map['target']!;
  String get rentGuard => _map['rentGuard']!;
  String get receptionist => _map['receptionist']!;
  String get bonus => _map['bonus']!;
  String get percent30Target => _map['percent30Target']!;
  String get profitForEach => _map['profitForEach']!;
  String get commission => _map['commission']!;
  String get slice => _map['slice']!;
  String get incomeRange => _map['incomeRange']!;
  String get periodQuarter => _map['periodQuarter']!;
  String get periodSixMonths => _map['periodSixMonths']!;
  String get financeSummaryLoadError => _map['financeSummaryLoadError']!;
  String get loadSampleData => _map['loadSampleData']!;
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
  String get discountPercent => _map['discountPercent']!;
  String get amountAfterDiscount => _map['amountAfterDiscount']!;
  String get sessionPayment => _map['sessionPayment']!;
  String get paid => _map['paid']!;
  String get partialPaid => _map['partialPaid']!;
  String get notPaid => _map['notPaid']!;
  String get prepaid => _map['prepaid']!;
  String get amountPaid => _map['amountPaid']!;
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
  String get supervisor => _map['supervisor']!;
  String get secretary => _map['secretary']!;
  String get trainee => _map['trainee']!;
  String get pending => _map['pending']!;
  String get confirmed => _map['confirmed']!;
  String get completed => _map['completed']!;
  String get attended => _map['attended']!;
  String get apologized => _map['apologized']!;
  String get cancelled => _map['cancelled']!;
  String get noShow => _map['noShow']!;
  String get absent => _map['absent']!;
  String get absentWithCause => _map['absentWithCause']!;
  String get absentWithoutCause => _map['absentWithoutCause']!;
  String get absentAll => _map['absentAll']!;
  String get newPatient => _map['newPatient']!;
  String get starredPatientVip => _map['starredPatientVip']!;
  String get starredSessionVip => _map['starredSessionVip']!;
  String get filterDay => _map['filterDay']!;
  String get previousDay => _map['previousDay']!;
  String get nextDay => _map['nextDay']!;
  String get filterByDoctor => _map['filterByDoctor']!;
  String get incomeByDoctor => _map['incomeByDoctor']!;
  String get expenseByDoctor => _map['expenseByDoctor']!;
  String get paidByDoctor => _map['paidByDoctor']!;
  String get filterMonth => _map['filterMonth']!;
  String get filterYear => _map['filterYear']!;
  String get sessionsFiltered => _map['sessionsFiltered']!;
  String get sessionsThisWeek => _map['sessionsThisWeek']!;
  String get extraSlot => _map['extraSlot']!;
  String get scheduleView => _map['scheduleView']!;
  String get listView => _map['listView']!;
  String get showFilters => _map['showFilters']!;
  String get hideFilters => _map['hideFilters']!;
  String get slotFull => _map['slotFull']!;
  String get roomTimeConflict => _map['roomTimeConflict']!;
  String get doctorTimeConflict => _map['doctorTimeConflict']!;
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
  String get thisMonthAppointments => _map['thisMonthAppointments']!;
  String get thisYearAppointments => _map['thisYearAppointments']!;
  String get filterToday => _map['filterToday']!;
  String get filterThisWeek => _map['filterThisWeek']!;
  String get filterThisMonth => _map['filterThisMonth']!;
  String get filterThisYear => _map['filterThisYear']!;
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
  String get searchAppointmentsHint => _map['searchAppointmentsHint']!;
  String get searchUsersHint => _map['searchUsersHint']!;
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
  String get optional => _map['optional']!;
  String get addDoctorInviteHint => _map['addDoctorInviteHint']!;
  String get doctorProfile => _map['doctorProfile']!;
  String get sendInvite => _map['sendInvite']!;
  String get inviteNewDoctor => _map['inviteNewDoctor']!;
  String get inviteNewDoctorHint => _map['inviteNewDoctorHint']!;
  String get linkExistingUser => _map['linkExistingUser']!;
  String get linkExistingUserDoctorHint => _map['linkExistingUserDoctorHint']!;
  String get inviteSent => _map['inviteSent']!;
  String get noUsersWithDoctorRoleToLink => _map['noUsersWithDoctorRoleToLink']!;
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
  String get medicalDetails => _map['medicalDetails']!;
  String get chiefComplaint => _map['chiefComplaint']!;
  String get painLevel => _map['painLevel']!;
  String get treatmentGoals => _map['treatmentGoals']!;
  String get contraindications => _map['contraindications']!;
  String get previousTreatment => _map['previousTreatment']!;
  String get gender => _map['gender']!;
  String get male => _map['male']!;
  String get female => _map['female']!;
  String get dateOfBirth => _map['dateOfBirth']!;
  String get age => _map['age']!;
  String get yearsOld => _map['yearsOld']!;
  String get ageIfNoDateOfBirth => _map['ageIfNoDateOfBirth']!;
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
  String get generateReport => _map['generateReport']!;
  String get generatingReport => _map['generatingReport']!;
  String get reportReady => _map['reportReady']!;
  String get reportError => _map['reportError']!;
  String get editAppointment => _map['editAppointment']!;
  String get room => _map['room']!;
  String get rooms => _map['rooms']!;
  String get addRoom => _map['addRoom']!;
  String get editRoom => _map['editRoom']!;
  String get services => _map['services']!;
  String get addService => _map['addService']!;
  String get editService => _map['editService']!;
  String get serviceAmount => _map['serviceAmount']!;
  String get packages => _map['packages']!;
  String get priceQuote => _map['priceQuote']!;
  String get addPackage => _map['addPackage']!;
  String get editPackage => _map['editPackage']!;
  String get editSession => _map['editSession']!;
  String get sessionsAndPackages => _map['sessionsAndPackages']!;
  String get viewDetails => _map['viewDetails']!;
  String get deleteSession => _map['deleteSession']!;
  String get numberOfSessions => _map['numberOfSessions']!;
  String get packageAmount => _map['packageAmount']!;
  String get packageServices => _map['packageServices']!;
  String get linkToPackageOptional => _map['linkToPackageOptional']!;
  String get packageCompleted => _map['packageCompleted']!;
  String get delete => _map['delete']!;
  String get deleteConfirm => _map['deleteConfirm']!;
  String get deleteAppointmentAndIncomeConfirm => _map['deleteAppointmentAndIncomeConfirm']!;
  String get confirmAction => _map['confirmAction']!;
  String get quantity => _map['quantity']!;
  String get address => _map['address']!;
  String get auditLog => _map['auditLog']!;
  String get auditWho => _map['auditWho']!;
  String get auditWhen => _map['auditWhen']!;
  String get auditAction => _map['auditAction']!;
  String get export => _map['export']!;
  String get exportIncomeExpense => _map['exportIncomeExpense']!;
  String get exportAppointments => _map['exportAppointments']!;
  String get openLink => _map['openLink']!;
  String get viewImage => _map['viewImage']!;
  String get viewPdf => _map['viewPdf']!;
  String get createProfile => _map['createProfile']!;
  String get manageDoctors => _map['manageDoctors']!;
  String get migrateStaffCreatedPatients => _map['migrateStaffCreatedPatients']!;
  String get migrateStaffCreatedPatientsDialogTitle => _map['migrateStaffCreatedPatientsDialogTitle']!;
  String migrateStaffCreatedPatientsDialogMessage(int count) => (_map['migrateStaffCreatedPatientsDialogMessage']!).replaceAll('{count}', '$count');
  String migrateStaffCreatedPatientsProgress(int current, int total) => (_map['migrateStaffCreatedPatientsProgress']!).replaceAll('{current}', '$current').replaceAll('{total}', '$total');
  String get migrateStaffCreatedPatientsDone => _map['migrateStaffCreatedPatientsDone']!;
  String get migrateStaffCreatedPatientsNone => _map['migrateStaffCreatedPatientsNone']!;
  String get migrateStaffCreatedPatientsError => _map['migrateStaffCreatedPatientsError']!;
  String get addDoctor => _map['addDoctor']!;
  String get edit => _map['edit']!;
  String get quickAccess => _map['quickAccess']!;
  String get statistics => _map['statistics']!;
  String get appointmentsLast7Days => _map['appointmentsLast7Days']!;
  /// e.g. "Appointments (last 3 months)" — {period} is a phrase like chartPeriodPhrase3Months.
  String appointmentsChartTitle(String period) => _map['appointmentsChartTitle']!.replaceAll('{period}', period);
  /// e.g. "Income vs expenses (last 6 months)"
  String incomeExpenseChartTitle(String period) => _map['incomeExpenseChartTitle']!.replaceAll('{period}', period);
  String get chartPeriodPhraseDay => _map['chartPeriodPhraseDay']!;
  String get chartPeriodPhraseWeek => _map['chartPeriodPhraseWeek']!;
  String get chartPeriodPhraseMonth => _map['chartPeriodPhraseMonth']!;
  String get chartPeriodPhrase3Months => _map['chartPeriodPhrase3Months']!;
  String get chartPeriodPhrase6Months => _map['chartPeriodPhrase6Months']!;
  String get chartPeriodPhrase9Months => _map['chartPeriodPhrase9Months']!;
  String get chartPeriodPhraseYear => _map['chartPeriodPhraseYear']!;
  String get incomeVsExpense6Months => _map['incomeVsExpense6Months']!;
  String get usersByRole => _map['usersByRole']!;
  /// Shown under the users-by-role chart: counts are not scoped to the selected period.
  String get usersByRolePeriodHint => _map['usersByRolePeriodHint']!;
  /// Explains pie vs bar/line and how custom range relates to full calendar months (Income & Expenses).
  String get incomeExpenseChartDataHint => _map['incomeExpenseChartDataHint']!;
  String get filterByPeriod => _map['filterByPeriod']!;
  String get periodDay => _map['periodDay']!;
  String get periodWeek => _map['periodWeek']!;
  String get periodMonth => _map['periodMonth']!;
  /// Admin charts: full calendar month from the 1st through the last day (current month).
  String get periodWholeCurrentMonth => _map['periodWholeCurrentMonth']!;
  /// Admin charts: pick any calendar month (full month).
  String get periodPickMonth => _map['periodPickMonth']!;
  /// Chart subtitle phrase for [periodWholeCurrentMonth] filter.
  String get chartPeriodPhraseThisMonth => _map['chartPeriodPhraseThisMonth']!;
  String get period3Months => _map['period3Months']!;
  String get period6Months => _map['period6Months']!;
  String get period9Months => _map['period9Months']!;
  String get periodYear => _map['periodYear']!;
  String get periodCustomRange => _map['periodCustomRange']!;
  String get chooseDateRange => _map['chooseDateRange']!;
  String get exportPdf => _map['exportPdf']!;
  String get dynamicReport => _map['dynamicReport']!;
  String get dynamicReportHint => _map['dynamicReportHint']!;
  String get dynamicReportExportChartType => _map['dynamicReportExportChartType']!;
  String get dynamicReportSelectAll => _map['dynamicReportSelectAll']!;
  String get dynamicReportClear => _map['dynamicReportClear']!;
  String get dynamicReportGenerate => _map['dynamicReportGenerate']!;
  String get dynamicReportSelectAtLeastOne => _map['dynamicReportSelectAtLeastOne']!;
  String get dynamicReportNothingCaptured => _map['dynamicReportNothingCaptured']!;
  String get dynamicReportNoCharts => _map['dynamicReportNoCharts']!;
  String get dynamicStatisticsReport => _map['dynamicStatisticsReport']!;
  String get generatingPdf => _map['generatingPdf']!;
  String get barChart => _map['barChart']!;
  String get lineChart => _map['lineChart']!;
  String get pieChart => _map['pieChart']!;
  String get appointmentsByStatus => _map['appointmentsByStatus']!;
  String get incomeNoDoctor => _map['incomeNoDoctor']!;
  String get chartOtherCategory => _map['chartOtherCategory']!;
  String get expensesByCategory => _map['expensesByCategory']!;
  String get uncategorizedExpense => _map['uncategorizedExpense']!;
  String get appointmentsByService => _map['appointmentsByService']!;
  String get appointmentsByPackage => _map['appointmentsByPackage']!;
  String get appointmentNoServices => _map['appointmentNoServices']!;
  String get periodIncome => _map['periodIncome']!;
  String get periodExpense => _map['periodExpense']!;
  String get periodNet => _map['periodNet']!;
  String get totalRooms => _map['totalRooms']!;
  String get totalServices => _map['totalServices']!;
  String get totalPackages => _map['totalPackages']!;
  String get addNewPatient => _map['addNewPatient']!;
  String get findPatient => _map['findPatient']!;
  String get patientAdded => _map['patientAdded']!;
  String get appointmentBooked => _map['appointmentBooked']!;
  String get noPatientsYet => _map['noPatientsYet']!;
  String get noSearchResults => _map['noSearchResults']!;
  String get patientCode => _map['patientCode']!;
  String get searchByPatientCodeHint => _map['searchByPatientCodeHint']!;
  String get assignPatientCode => _map['assignPatientCode']!;
  String get notifications => _map['notifications']!;
  String get noNotifications => _map['noNotifications']!;
  String get retry => _map['retry']!;
  String get checkForUpdate => _map['checkForUpdate']!;
  String get updateNotConfigured => _map['updateNotConfigured']!;
  String get updateCheckFailed => _map['updateCheckFailed']!;
  String get updateAlreadyLatest => _map['updateAlreadyLatest']!;
  String get updateAvailable => _map['updateAvailable']!;
  String get updateReleaseNotes => _map['updateReleaseNotes']!;
  String get updateDownload => _map['updateDownload']!;
  String get updateDownloadFailed => _map['updateDownloadFailed']!;
  String get updateOpeningInstaller => _map['updateOpeningInstaller']!;
  String get updateRequiredTitle => _map['updateRequiredTitle']!;
  String get updateRequiredBody => _map['updateRequiredBody']!;
  String updateVersionCurrent(String version, int code) =>
      _map['updateVersionCurrent']!.replaceAll('{version}', version).replaceAll('{code}', '$code');
  String updateVersionNew(String version, int code) =>
      _map['updateVersionNew']!.replaceAll('{version}', version).replaceAll('{code}', '$code');
  String updateDownloadingPercent(int percent) =>
      _map['updateDownloadingPercent']!.replaceAll('{percent}', '$percent');
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

  /// User-friendly message for Firestore/general errors. Returns localized text for known keys, or a generic message.
  String generalErrorMessage(String? key) => key == null ? '' : (_map[key] ?? _map['errorTryAgain'] ?? 'Something went wrong. Please try again.');

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
    'emailOrPatientCode': 'Email or patient code',
    'emailOrPatientCodeHint': 'Email address or your patient ID code',
    'changePassword': 'Change password',
    'currentPassword': 'Current password',
    'newPassword': 'New password',
    'confirmNewPassword': 'Confirm new password',
    'passwordChanged': 'Password changed successfully.',
    'changePasswordGoogleHint': 'You signed in with Google. Change your password in your Google account settings.',
    'fullNameAr': 'Full name (Arabic)',
    'fullNameEn': 'Full name (English)',
    'phone': 'Phone',
    'secondaryPhone': 'Secondary phone',
    'dashboard': 'Dashboard',
    'users': 'Users',
    'appointments': 'Appointments',
    'appointmentsSeeAll': 'See all appointments',
    'appointmentsViewAll': 'View all appointments (read-only)',
    'myAppointments': 'My Appointments',
    'profile': 'Profile',
    'priceQuote': 'Price Quote',
    'patients': 'Patients',
    'patientDetail': 'Patient detail',
    'incomeAndExpenses': 'Income & Expenses',
    'income': 'Income',
    'expenses': 'Expenses',
    'net': 'Net',
    'netProfit': 'Net Profit',
    'totalIncome': 'Total income',
    'totalExpenses': 'Total expenses',
    'financeSummary': 'Finance summary',
    'target': 'Target',
    'rentGuard': 'Rent + guard',
    'receptionist': 'Receptionist',
    'bonus': 'Bonus',
    'percent30Target': '30% target',
    'profitForEach': 'Profit for each',
    'commission': 'Commission',
    'slice': 'Slice',
    'incomeRange': 'Income range',
    'periodQuarter': '3 months',
    'periodSixMonths': '6 months',
    'financeSummaryLoadError': 'Could not load finance summary. Please try again.',
    'loadSampleData': 'Load sample',
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
    'discountPercent': 'Discount %',
    'amountAfterDiscount': 'Amount after discount',
    'sessionPayment': 'Session payment',
    'paid': 'Paid',
    'partialPaid': 'Partial paid',
    'notPaid': 'Not paid',
    'prepaid': 'Prepaid',
    'amountPaid': 'Amount paid',
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
    'supervisor': 'Supervisor',
    'secretary': 'Secretary',
    'trainee': 'Trainee',
    'pending': 'Pending',
    'confirmed': 'Confirmed',
    'completed': 'Completed',
    'attended': 'Attended',
    'apologized': 'Apologized',
    'cancelled': 'Cancelled',
    'noShow': 'No show',
    'absent': 'Absent',
    'absentWithCause': 'Absent (with cause)',
    'absentWithoutCause': 'Absent (without cause)',
    'absentAll': 'Absents all (both)',
    'newPatient': 'New Patient',
    'starredPatientVip': 'Patient (VIP)',
    'starredSessionVip': ' Session (VIP)',
    'filterDay': 'Day',
    'previousDay': 'Previous day',
    'nextDay': 'Next day',
    'filterByDoctor': 'Filter by doctor',
    'incomeByDoctor': 'Income by doctor',
    'expenseByDoctor': 'Expense by doctor',
    'paidByDoctor': 'Paid by (doctor)',
    'filterMonth': 'Month',
    'filterYear': 'Year',
    'sessionsFiltered': 'Sessions (filtered)',
    'sessionsThisWeek': 'Sessions this week',
    'extraSlot': 'Extra slot (optional)',
    'scheduleView': 'Schedule',
    'listView': 'List',
    'showFilters': 'Show filters',
    'hideFilters': 'Hide filters',
    'slotFull': 'This time slot is full (max 3 sessions + 1 extra).',
    'roomTimeConflict': 'This room is already booked for an appointment in this time range.',
    'doctorTimeConflict': 'This doctor already has an appointment at the selected date and time. Please choose another time.',
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
    'thisMonthAppointments': 'This month\'s appointments',
    'thisYearAppointments': 'This year\'s appointments',
    'filterToday': 'Today',
    'filterThisWeek': 'This week',
    'filterThisMonth': 'This month',
    'filterThisYear': 'This year',
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
    'searchAppointmentsHint': 'Search by patient, code, doctor or service',
    'searchUsersHint': 'Search by name, email, phone or patient code',
    'searchByPatientCodeHint': 'Search by name, email, phone or code',
    'patientCode': 'Patient code',
    'assignPatientCode': 'Assign patient code',
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
    'optional': 'Optional',
    'addDoctorInviteHint': 'Send an invite to the doctor\'s email. They will register and get the doctor role with this profile.',
    'doctorProfile': 'Doctor profile',
    'sendInvite': 'Send invite',
    'inviteNewDoctor': 'Invite new doctor',
    'inviteNewDoctorHint': 'Add doctor with email and profile; they register to join.',
    'linkExistingUser': 'Link existing user',
    'linkExistingUserDoctorHint': 'User already has doctor role; create doctor profile.',
    'inviteSent': 'Invite sent. Doctor can register with that email.',
    'noUsersWithDoctorRoleToLink': 'No users with doctor role to link. Invite or assign role first.',
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
    'medicalDetails': 'Medical details',
    'chiefComplaint': 'Chief complaint / Reason for referral',
    'painLevel': 'Pain level (e.g. VAS 0-10)',
    'treatmentGoals': 'Treatment goals',
    'contraindications': 'Contraindications / Precautions',
    'previousTreatment': 'Previous PT / Surgery',
    'gender': 'Gender',
    'male': 'Male',
    'female': 'Female',
    'dateOfBirth': 'Date of birth',
    'age': 'Age',
    'yearsOld': 'years old',
    'ageIfNoDateOfBirth': 'Optional — if patient does not share date of birth',
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
    'generateReport': 'Generate report',
    'generatingReport': 'Generating report…',
    'reportReady': 'Report ready',
    'reportError': 'Could not generate report',
    'editAppointment': 'Edit appointment',
    'room': 'Room',
    'rooms': 'Rooms',
    'addRoom': 'Add room',
    'editRoom': 'Edit room',
    'services': 'Services',
    'addService': 'Add service',
    'editService': 'Edit service',
    'serviceAmount': 'Amount (per session)',
    'packages': 'Packages',
    'addPackage': 'Add package',
    'editPackage': 'Edit package',
    'editSession': 'Edit session',
    'sessionsAndPackages': 'Sessions & packages',
    'viewDetails': 'View details',
    'deleteSession': 'Delete session',
    'numberOfSessions': 'Number of sessions',
    'packageAmount': 'Package amount',
    'packageServices': 'Services in package',
    'linkToPackageOptional': 'Link to package (optional)',
    'packageCompleted': 'Package completed (all sessions done)',
    'delete': 'Delete',
    'deleteConfirm': 'Delete?',
    'deleteAppointmentAndIncomeConfirm': 'Delete this appointment? Any session income linked to it will be removed.',
    'confirmAction': 'Confirm',
    'quantity': 'Quantity',
    'address': 'Address',
    'auditLog': 'Audit log',
    'auditWho': 'Who',
    'auditWhen': 'When',
    'auditAction': 'Action',
    'export': 'Export',
    'exportIncomeExpense': 'Export income & expense',
    'exportAppointments': 'Export appointments',
    'openLink': 'Open link',
    'viewImage': 'View image',
    'viewPdf': 'View PDF',
    'createProfile': 'Create profile',
    'manageDoctors': 'Manage doctors',
    'migrateStaffCreatedPatients': 'Migrate staff-created patients',
    'migrateStaffCreatedPatientsDialogTitle': 'Migrate to login',
    'migrateStaffCreatedPatientsDialogMessage': 'There are {count} patient(s) created by staff (no Auth login). Migrate them to login with code@awda.com / code?',
    'migrateStaffCreatedPatientsProgress': 'Migrating {current} / {total}…',
    'migrateStaffCreatedPatientsDone': 'Migration completed.',
    'migrateStaffCreatedPatientsNone': 'No staff-created patients to migrate.',
    'migrateStaffCreatedPatientsError': 'Migration failed',
    'addDoctor': 'Add doctor',
    'edit': 'Edit',
    'quickAccess': 'Quick access',
    'statistics': 'Statistics',
    'appointmentsLast7Days': 'Appointments (last 7 days)',
    'appointmentsChartTitle': 'Appointments ({period})',
    'incomeExpenseChartTitle': 'Income vs expenses ({period})',
    'chartPeriodPhraseDay': 'today',
    'chartPeriodPhraseWeek': 'last 7 days',
    'chartPeriodPhraseMonth': 'last month',
    'chartPeriodPhrase3Months': 'last 3 months',
    'chartPeriodPhrase6Months': 'last 6 months',
    'chartPeriodPhrase9Months': 'last 9 months',
    'chartPeriodPhraseYear': 'last 12 months',
    'incomeVsExpense6Months': 'Income vs expenses (last 6 months)',
    'usersByRole': 'Users by role',
    'usersByRolePeriodHint': 'Not affected by the period filter (all users).',
    'incomeExpenseChartDataHint':
        'Income vs expenses: the pie chart shows totals for the whole selected date range. Bar and line charts show each calendar month that overlaps that range—if the range ends before the last day of a month, that month only includes days inside the range. Income & Expenses often uses a full calendar month; to match one month here, set the custom range from the 1st through the last day of that month (e.g. 01/03–31/03 for all of March).',
    'filterByPeriod': 'Filter by period',
    'periodDay': 'Day',
    'periodWeek': 'Week',
    'periodMonth': 'Month',
    'periodWholeCurrentMonth': 'This month (full)',
    'periodPickMonth': 'Choose month…',
    'chartPeriodPhraseThisMonth': 'current month (full)',
    'period3Months': '3 Months',
    'period6Months': '6 Months',
    'period9Months': '9 Months',
    'periodYear': 'Year',
    'periodCustomRange': 'Custom range',
    'chooseDateRange': 'Choose dates',
    'exportPdf': 'Export PDF',
    'dynamicReport': 'Dynamic report',
    'dynamicReportHint': 'Choose one or more statistics below. Pick a chart style for the PDF; all selected charts will be exported using that style (your on-screen chart types stay the same after export).',
    'dynamicReportExportChartType': 'Chart style for PDF export',
    'dynamicReportSelectAll': 'Select all',
    'dynamicReportClear': 'Clear',
    'dynamicReportGenerate': 'Generate combined PDF',
    'dynamicReportSelectAtLeastOne': 'Select at least one statistic to export.',
    'dynamicReportNothingCaptured': 'Could not capture the selected charts. Try again after the charts finish loading.',
    'dynamicReportNoCharts': 'No charts are available for the current period.',
    'dynamicStatisticsReport': 'Admin statistics report',
    'generatingPdf': 'Generating PDF…',
    'barChart': 'Bar',
    'lineChart': 'Line',
    'pieChart': 'Pie',
    'appointmentsByStatus': 'Appointments by status',
    'incomeNoDoctor': 'No doctor (unassigned)',
    'chartOtherCategory': 'Other',
    'expensesByCategory': 'Expenses by category',
    'uncategorizedExpense': 'Uncategorized',
    'appointmentsByService': 'Appointments by service',
    'appointmentsByPackage': 'Appointments by package',
    'appointmentNoServices': 'No service listed',
    'periodIncome': 'Income (period)',
    'periodExpense': 'Expenses (period)',
    'periodNet': 'Net (period)',
    'totalRooms': 'Rooms',
    'totalServices': 'Services',
    'totalPackages': 'Packages',
    'addNewPatient': 'Add new patient',
    'findPatient': 'Find patient',
    'patientAdded': 'Patient added',
    'appointmentBooked': 'Appointment booked',
    'noPatientsYet': 'No patients yet. Add your first patient.',
    'noSearchResults': 'No patients match your search.',
    'notifications': 'Notifications',
    'noNotifications': 'No notifications',
    'retry': 'Retry',
    'checkForUpdate': 'Check for updates',
    'updateNotConfigured':
        'In-app updates are not configured. Add your JSON manifest URL in lib/core/android_update_config.dart (kAndroidUpdateManifestUrlEmbedded), or build with ANDROID_UPDATE_MANIFEST_URL. Use the Dropbox link to version.json, not the APK file.',
    'updateCheckFailed': 'Could not check for updates. Check your internet connection and try again.',
    'updateAlreadyLatest': 'You are using the latest version.',
    'updateAvailable': 'Update available',
    'updateReleaseNotes': 'Release notes',
    'updateDownload': 'Download & install',
    'updateDownloadFailed': 'Download failed. Check your connection and try again.',
    'updateOpeningInstaller': 'Opening installer… If nothing happens, allow installs from this source in Settings.',
    'updateRequiredTitle': 'Update required',
    'updateRequiredBody':
        'Your app version is no longer supported. Please download and install the latest version.',
    'updateVersionCurrent': 'Current: {version} (build {code})',
    'updateVersionNew': 'New: {version} (build {code})',
    'updateDownloadingPercent': 'Downloading… {percent}%',
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
    'authErrorGoogleSignInConfiguration':
        'Google sign-in failed for this app build. In Firebase Console → Project settings → Your apps → Android, add this computer\'s SHA-1 fingerprint (debug and release), then download a fresh google-services.json if needed.',
    'authErrorNoAccountWithEmail': 'No account found with this email.',
    'errorPermissionDenied': 'You don\'t have permission to perform this action. Please contact your administrator.',
    'errorNetwork': 'Connection error. Please check your internet and try again.',
    'errorSaveFailed': 'Could not save. Please try again.',
    'errorLoadFailed': 'Could not load data. Please try again.',
    'errorTryAgain': 'Something went wrong. Please try again.',
  };

  static const Map<String, String> _ar = {
    'appTitle': 'مركز عَودة',
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
    'emailOrPatientCode': 'البريد أو رمز المريض',
    'emailOrPatientCodeHint': 'البريد الإلكتروني أو رمز المريض',
    'changePassword': 'تغيير كلمة المرور',
    'currentPassword': 'كلمة المرور الحالية',
    'newPassword': 'كلمة المرور الجديدة',
    'confirmNewPassword': 'تأكيد كلمة المرور الجديدة',
    'passwordChanged': 'تم تغيير كلمة المرور بنجاح.',
    'changePasswordGoogleHint': 'تم تسجيل الدخول بحساب Google. غيّر كلمة المرور من إعدادات حساب Google.',
    'fullNameAr': 'الاسم الكامل (عربي)',
    'fullNameEn': 'الاسم الكامل (إنجليزي)',
    'phone': 'الهاتف',
    'secondaryPhone': 'هاتف ثانوي',
    'dashboard': 'لوحة التحكم',
    'users': 'المستخدمون',
    'appointments': 'المواعيد',
    'appointmentsSeeAll': 'عرض كل المواعيد',
    'appointmentsViewAll': 'عرض كل المواعيد (للقراءة فقط)',
    'myAppointments': 'مواعيدي',
    'profile': 'الملف الشخصي',
    'priceQuote': 'عرض الأسعار',
    'patients': 'المرضى',
    'patientDetail': 'تفاصيل المريض',
    'incomeAndExpenses': 'الإيرادات والمصروفات',
    'income': 'الإيرادات',
    'expenses': 'المصروفات',
    'net': 'صافي',
    'netProfit': 'صافي الربح',
    'totalIncome': 'إجمالي الإيرادات',
    'totalExpenses': 'إجمالي المصروفات',
    'financeSummary': 'ملخص مالي',
    'target': 'الهدف',
    'rentGuard': 'إيجار + حارس',
    'receptionist': 'موظف الاستقبال',
    'bonus': 'مكافأة',
    'percent30Target': '30% هدف',
    'profitForEach': 'ربح لكل واحد',
    'commission': 'عمولة',
    'slice': 'شريحة',
    'incomeRange': 'نطاق الدخل',
    'periodQuarter': '٣ أشهر',
    'periodSixMonths': '٦ أشهر',
    'financeSummaryLoadError': 'تعذر تحميل الملخص المالي. يرجى المحاولة مرة أخرى.',
    'loadSampleData': 'تحميل عينة',
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
    'discountPercent': 'خصم %',
    'amountAfterDiscount': 'المبلغ بعد الخصم',
    'sessionPayment': 'دفع الجلسة',
    'paid': 'مدفوع',
    'partialPaid': 'مدفوع جزئياً',
    'notPaid': 'غير مدفوع',
    'prepaid': 'مدفوع مسبقاً',
    'amountPaid': 'المبلغ المدفوع',
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
    'supervisor': 'مشرف',
    'secretary': 'سكرتير',
    'trainee': 'متدرب',
    'pending': 'قيد الانتظار',
    'confirmed': 'مؤكد',
    'completed': 'مكتمل',
    'attended': 'حضر',
    'apologized': 'اعتذر',
    'cancelled': 'ملغي',
    'noShow': 'لم يحضر',
    'absent': 'غائب',
    'absentWithCause': 'غائب (بعذر)',
    'absentWithoutCause': 'غائب (بدون عذر)',
    'absentAll': 'الغياب الكل (كلاهما)',
    'newPatient': 'مريض جديد',
    'starredPatientVip': 'مميز (VIP)',
    'starredSessionVip': 'جلسة مميزة (VIP)',
    'filterDay': 'يوم',
    'previousDay': 'اليوم السابق',
    'nextDay': 'اليوم التالي',
    'filterByDoctor': 'تصفية حسب الطبيب',
    'incomeByDoctor': 'الدخل حسب الطبيب',
    'expenseByDoctor': 'المصروفات حسب الطبيب',
    'paidByDoctor': 'مدفوع من (الطبيب)',
    'filterMonth': 'شهر',
    'filterYear': 'سنة',
    'sessionsFiltered': 'الجلسات (المصفاة)',
    'sessionsThisWeek': 'جلسات هذا الأسبوع',
    'extraSlot': 'جلسة إضافية (اختياري)',
    'scheduleView': 'الجدول',
    'listView': 'قائمة',
    'showFilters': 'إظهار الفلاتر',
    'hideFilters': 'إخفاء الفلاتر',
    'slotFull': 'هذا الموعد ممتلئ (٣ جلسات + ١ إضافية).',
    'roomTimeConflict': 'هذه الغرفة محجوزة بالفعل لموعد في هذا التوقيت.',
    'doctorTimeConflict': 'هذا الطبيب لديه موعد بالفعل في التاريخ والوقت المحدد. يرجى اختيار وقت آخر.',
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
    'thisMonthAppointments': 'مواعيد هذا الشهر',
    'thisYearAppointments': 'مواعيد هذه السنة',
    'filterToday': 'اليوم',
    'filterThisWeek': 'هذا الأسبوع',
    'filterThisMonth': 'هذا الشهر',
    'filterThisYear': 'هذه السنة',
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
    'searchAppointmentsHint': 'البحث بالمريض أو الرمز أو الطبيب أو الخدمة',
    'searchUsersHint': 'البحث بالاسم أو البريد أو الهاتف أو رمز المريض',
    'searchByPatientCodeHint': 'البحث بالاسم أو البريد أو الهاتف أو الرمز',
    'patientCode': 'رمز المريض',
    'assignPatientCode': 'تعيين رمز المريض',
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
    'optional': 'اختياري',
    'addDoctorInviteHint': 'إرسال دعوة إلى بريد الطبيب. سيسجل ويحصل على دور الطبيب مع هذا الملف.',
    'doctorProfile': 'الملف المهني للطبيب',
    'sendInvite': 'إرسال الدعوة',
    'inviteNewDoctor': 'دعوة طبيب جديد',
    'inviteNewDoctorHint': 'إضافة طبيب بالبريد والملف؛ يسجل للانضمام.',
    'linkExistingUser': 'ربط مستخدم موجود',
    'linkExistingUserDoctorHint': 'المستخدم لديه دور الطبيب؛ إنشاء الملف المهني.',
    'inviteSent': 'تم إرسال الدعوة. يمكن للطبيب التسجيل بهذا البريد.',
    'noUsersWithDoctorRoleToLink': 'لا يوجد مستخدمون بدور الطبيب للربط. ادعُ أو عيّن الدور أولاً.',
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
    'medicalDetails': 'البيانات الطبية',
    'chiefComplaint': 'الشكوى الرئيسية / سبب الإحالة',
    'painLevel': 'مستوى الألم (مثلاً 0-10)',
    'treatmentGoals': 'أهداف العلاج',
    'contraindications': 'موانع الاستعمال / احتياطات',
    'previousTreatment': 'علاج طبيعي أو جراحة سابقة',
    'gender': 'الجنس',
    'male': 'ذكر',
    'female': 'أنثى',
    'dateOfBirth': 'تاريخ الميلاد',
    'age': 'العمر',
    'yearsOld': 'سنوات',
    'ageIfNoDateOfBirth': 'اختياري — إذا لم يذكر المريض تاريخ الميلاد',
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
    'generateReport': 'إنشاء تقرير',
    'generatingReport': 'جاري إنشاء التقرير…',
    'reportReady': 'التقرير جاهز',
    'reportError': 'تعذر إنشاء التقرير',
    'editAppointment': 'تعديل الموعد',
    'room': 'غرفة',
    'rooms': 'الغرف',
    'addRoom': 'إضافة غرفة',
    'editRoom': 'تعديل الغرفة',
    'services': 'الخدمات',
    'addService': 'إضافة خدمة',
    'editService': 'تعديل الخدمة',
    'serviceAmount': 'المبلغ (لكل جلسة)',
    'packages': 'الباقات',
    'addPackage': 'إضافة باقة',
    'editPackage': 'تعديل الباقة',
    'editSession': 'تعديل الجلسة',
    'sessionsAndPackages': 'الجلسات والباقات',
    'viewDetails': 'عرض التفاصيل',
    'deleteSession': 'حذف الجلسة',
    'numberOfSessions': 'عدد الجلسات',
    'packageAmount': 'مبلغ الباقة',
    'packageServices': 'الخدمات في الباقة',
    'linkToPackageOptional': 'ربط بباقة (اختياري)',
    'packageCompleted': 'تم إكمال الباقة (جميع الجلسات)',
    'delete': 'حذف',
    'deleteConfirm': 'حذف؟',
    'deleteAppointmentAndIncomeConfirm': 'حذف هذا الموعد؟ سيتم إزالة أي إيراد مرتبط بالجلسة.',
    'confirmAction': 'تأكيد',
    'quantity': 'الكمية',
    'address': 'العنوان',
    'auditLog': 'سجل التدقيق',
    'auditWho': 'من',
    'auditWhen': 'متى',
    'auditAction': 'الإجراء',
    'export': 'تصدير',
    'exportIncomeExpense': 'تصدير الإيرادات والمصروفات',
    'exportAppointments': 'تصدير المواعيد',
    'openLink': 'فتح الرابط',
    'viewImage': 'عرض الصورة',
    'viewPdf': 'عرض PDF',
    'createProfile': 'إنشاء الملف الشخصي',
    'manageDoctors': 'إدارة الأطباء',
    'migrateStaffCreatedPatients': 'ترحيل المرضى المضافين من الموظفين',
    'migrateStaffCreatedPatientsDialogTitle': 'الترحيل لتسجيل الدخول',
    'migrateStaffCreatedPatientsDialogMessage': 'يوجد {count} مريض/مرضى أضافهم الموظفون (بدون حساب دخول). ترحيلهم لتسجيل الدخول بـ code@awda.com / code؟',
    'migrateStaffCreatedPatientsProgress': 'جاري الترحيل {current} / {total}…',
    'migrateStaffCreatedPatientsDone': 'تم الترحيل.',
    'migrateStaffCreatedPatientsNone': 'لا يوجد مرضى مضافون من الموظفين لترحيلهم.',
    'migrateStaffCreatedPatientsError': 'فشل الترحيل',
    'addDoctor': 'إضافة طبيب',
    'edit': 'تعديل',
    'quickAccess': 'وصول سريع',
    'statistics': 'إحصائيات',
    'appointmentsLast7Days': 'المواعيد (آخر 7 أيام)',
    'appointmentsChartTitle': 'المواعيد ({period})',
    'incomeExpenseChartTitle': 'الإيرادات والمصروفات ({period})',
    'chartPeriodPhraseDay': 'اليوم',
    'chartPeriodPhraseWeek': 'آخر 7 أيام',
    'chartPeriodPhraseMonth': 'الشهر الماضي',
    'chartPeriodPhrase3Months': 'آخر 3 أشهر',
    'chartPeriodPhrase6Months': 'آخر 6 أشهر',
    'chartPeriodPhrase9Months': 'آخر 9 أشهر',
    'chartPeriodPhraseYear': 'آخر 12 شهرًا',
    'incomeVsExpense6Months': 'الإيرادات والمصروفات (آخر 6 أشهر)',
    'usersByRole': 'المستخدمون حسب الدور',
    'usersByRolePeriodHint': 'غير مرتبط بفلتر الفترة أعلاه (جميع المستخدمين).',
    'incomeExpenseChartDataHint':
        'الإيرادات والمصروفات: مخطط الدائرة يعرض الإجمالي لنطاق التواريخ المحدد بالكامل. المخططات العمودية والخطية تعرض كل شهر ميلادي يتقاطع مع النطاق—إذا انتهى النطاق قبل آخر يوم في الشهر، يُحتسب من ذلك الشهر الأيام داخل النطاق فقط. شاشة الإيرادات والمصروفات غالباً تستخدم شهراً ميلادياً كاملاً؛ لمطابقة شهر كامل هنا اضبط النطاق المخصص من اليوم الأول إلى آخر يوم في ذلك الشهر (مثال: 01/03–31/03 لكامل مارس).',
    'filterByPeriod': 'تصفية حسب الفترة',
    'periodDay': 'يوم',
    'periodWeek': 'أسبوع',
    'periodMonth': 'شهر',
    'periodWholeCurrentMonth': 'هذا الشهر (كامل)',
    'periodPickMonth': 'اختر شهراً…',
    'chartPeriodPhraseThisMonth': 'الشهر الحالي (كامل)',
    'period3Months': '٣ أشهر',
    'period6Months': '٦ أشهر',
    'period9Months': '٩ أشهر',
    'periodYear': 'سنة',
    'periodCustomRange': 'فترة مخصصة',
    'chooseDateRange': 'اختر التواريخ',
    'exportPdf': 'تصدير PDF',
    'dynamicReport': 'تقرير ديناميكي',
    'dynamicReportHint': 'اختر إحصائية واحدة أو أكثر أدناه. اختر شكل المخطط للتصدير؛ ستُصدَّر كل المخططات المحددة بهذا الشكل (أنواع المخططات على الشاشة تُعاد كما كانت بعد التصدير).',
    'dynamicReportExportChartType': 'شكل المخطط لتصدير PDF',
    'dynamicReportSelectAll': 'تحديد الكل',
    'dynamicReportClear': 'مسح',
    'dynamicReportGenerate': 'إنشاء PDF مجمّع',
    'dynamicReportSelectAtLeastOne': 'اختر إحصائية واحدة على الأقل للتصدير.',
    'dynamicReportNothingCaptured': 'تعذر التقاط المخططات المحددة. أعد المحاولة بعد اكتمال التحميل.',
    'dynamicReportNoCharts': 'لا توجد مخططات متاحة للفترة الحالية.',
    'dynamicStatisticsReport': 'تقرير إحصائيات الإدارة',
    'generatingPdf': 'جاري إنشاء PDF…',
    'barChart': 'أعمدة',
    'lineChart': 'خط',
    'pieChart': 'دائري',
    'appointmentsByStatus': 'المواعيد حسب الحالة',
    'incomeNoDoctor': 'بدون طبيب (غير مخصص)',
    'chartOtherCategory': 'أخرى',
    'expensesByCategory': 'المصروفات حسب الفئة',
    'uncategorizedExpense': 'غير مصنف',
    'appointmentsByService': 'المواعيد حسب الخدمة',
    'appointmentsByPackage': 'المواعيد حسب الباقة',
    'appointmentNoServices': 'بدون خدمة مسجلة',
    'periodIncome': 'الإيرادات (الفترة)',
    'periodExpense': 'المصروفات (الفترة)',
    'periodNet': 'الصافي (الفترة)',
    'totalRooms': 'الغرف',
    'totalServices': 'الخدمات',
    'totalPackages': 'الباقات',
    'addNewPatient': 'إضافة مريض جديد',
    'findPatient': 'البحث عن مريض',
    'patientAdded': 'تمت إضافة المريض',
    'appointmentBooked': 'تم حجز الموعد',
    'noPatientsYet': 'لا يوجد مرضى بعد. أضف أول مريض.',
    'noSearchResults': 'لا توجد نتائج تطابق البحث.',
    'notifications': 'الإشعارات',
    'noNotifications': 'لا توجد إشعارات',
    'retry': 'إعادة المحاولة',
    'checkForUpdate': 'التحقق من التحديثات',
    'updateNotConfigured':
        'لم يُضبط التحديث داخل التطبيق. أضف رابط ملف JSON في lib/core/android_update_config.dart (kAndroidUpdateManifestUrlEmbedded)، أو ابنِ التطبيق بـ ANDROID_UPDATE_MANIFEST_URL. استخدم رابط Dropbox لملف version.json وليس ملف الـ APK.',
    'updateCheckFailed': 'تعذر التحقق من التحديثات. تحقق من الاتصال بالإنترنت وحاول مرة أخرى.',
    'updateAlreadyLatest': 'أنت تستخدم أحدث إصدار.',
    'updateAvailable': 'يتوفر إصدار جديد',
    'updateReleaseNotes': 'ملاحظات الإصدار',
    'updateDownload': 'تنزيل وتثبيت',
    'updateDownloadFailed': 'فشل التنزيل. تحقق من الاتصال وحاول مرة أخرى.',
    'updateOpeningInstaller': 'جاري فتح المثبت… إذا لم يحدث شيء، اسمح بالتثبيت من هذا المصدر في الإعدادات.',
    'updateRequiredTitle': 'يلزم التحديث',
    'updateRequiredBody': 'إصدار التطبيق لم يعد مدعوماً. يرجى تنزيل وتثبيت أحدث إصدار.',
    'updateVersionCurrent': 'الحالي: {version} (بناء {code})',
    'updateVersionNew': 'الجديد: {version} (بناء {code})',
    'updateDownloadingPercent': 'جاري التنزيل… {percent}٪',
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
    'authErrorGoogleSignInConfiguration':
        'فشل تسجيل الدخول بـ Google لهذا الإصدار. في إعدادات Firebase للمشروع → تطبيق Android أضف بصمة SHA-1 (للتطوير والإصدار) ثم حمّل google-services.json المحدث إن لزم.',
    'authErrorNoAccountWithEmail': 'لا يوجد حساب بهذا البريد الإلكتروني.',
    'errorPermissionDenied': 'ليس لديك صلاحية لتنفيذ هذا الإجراء. يرجى التواصل مع المسؤول.',
    'errorNetwork': 'خطأ في الاتصال. تحقق من الإنترنت وحاول مرة أخرى.',
    'errorSaveFailed': 'تعذر الحفظ. يرجى المحاولة مرة أخرى.',
    'errorLoadFailed': 'تعذر تحميل البيانات. يرجى المحاولة مرة أخرى.',
    'errorTryAgain': 'حدث خطأ. يرجى المحاولة مرة أخرى.',
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
