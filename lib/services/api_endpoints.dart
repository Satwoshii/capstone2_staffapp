class ApiEndpoints {
  ApiEndpoints._();

  static const String health = 'health.php';

  // Staff endpoints retained for compatibility; the Teacher app does not show a staff login page.
  static const String staffLogin = 'auth/staff_login.php';
  static const String logout = 'auth/logout.php';
  static const String staffSessionHeartbeat = 'staff_sessions/heartbeat.php';

  // Automatic Windows-account Teacher session.
  static const String teacherWindowsRecord =
      'staff_sessions/windows_record.php';
  static const String teacherWindowsAutoLogin =
      'staff_sessions/windows_auto_login.php';
  static const String teacherWindowsHeartbeat =
      'staff_sessions/windows_heartbeat.php';

  // Teacher dashboard.
  static const String teacherOverview = 'teacher/overview.php';
  static const String teacherReports = 'teacher/reports.php';
  static const String teacherCreateReport = 'teacher/create_report.php';
  static const String teacherForwardReport = 'teacher/forward_report.php';
  static const String teacherVerifyRepair = 'teacher/verify_repair.php';
  static const String teacherChatOverview = 'teacher/chat_overview.php';
  static const String teacherChatSend = 'teacher/chat_send.php';

  // Protected Ctrl+Shift+A Teacher room configuration.
  static const String teacherConfigureRoom = 'teacher/configure_room.php';

  // Teacher proof image upload.
  static const String attachmentUpload = 'attachments/upload.php';
}
