class ApiEndpoints {
  ApiEndpoints._();

  static const String health = 'health.php';
  static const String staffLogin = 'auth/staff_login.php';
  static const String logout = 'auth/logout.php';

  static const String accountList = 'accounts/list.php';
  static const String accountCreate = 'accounts/create.php';
  static const String accountSetActive = 'accounts/set_active.php';
  static const String accountResetPassword = 'accounts/reset_password.php';

  static const String roomList = 'rooms/list.php';
  static const String roomCreate = 'rooms/create.php';
  static const String roomSetActive = 'rooms/set_active.php';

  static const String dashboard = 'staff/dashboard.php';
  static const String pcHealth = 'staff/pc_health.php';
  static const String faultReports = 'staff/fault_reports.php';
  static const String markRepaired = 'staff/mark_repaired.php';
  static const String lastKnownUsers = 'staff/last_known_users.php';

  static const String supportConversations = 'chat/admin_conversations.php';
  static const String supportMessages = 'chat/admin_messages.php';
  static const String supportSend = 'chat/admin_send.php';
  static const String supportUpdateStatus = 'chat/admin_update_status.php';
  static const String supportMarkRead = 'chat/admin_mark_read.php';
}
