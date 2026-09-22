class DashboardSummary {
  final int accounts;
  final int students;
  final int rooms;
  final int workstations;
  final int onlineWorkstations;
  final int openFaults;
  final int repairedFaults;
  final int loginLogs;

  const DashboardSummary({
    required this.accounts,
    required this.students,
    required this.rooms,
    required this.workstations,
    required this.onlineWorkstations,
    required this.openFaults,
    required this.repairedFaults,
    required this.loginLogs,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    int read(String key) => int.tryParse((json[key] ?? 0).toString()) ?? 0;
    return DashboardSummary(
      accounts: read('accounts'),
      students: read('students'),
      rooms: read('rooms'),
      workstations: read('workstations'),
      onlineWorkstations: read('online_workstations'),
      openFaults: read('open_faults'),
      repairedFaults: read('repaired_faults'),
      loginLogs: read('login_logs'),
    );
  }
}
