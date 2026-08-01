import '../models/app_user.dart';
import '../models/dashboard_summary.dart';
import '../models/fault_report.dart';
import '../models/last_known_user_record.dart';
import '../models/pc_health_record.dart';
import '../models/room_record.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'app_config_service.dart';

class StaffService {
  StaffService._();

  static final StaffService instance = StaffService._();

  Future<Map<String, dynamic>> health() {
    return ApiClient.instance.getJson(
      ApiEndpoints.health,
      authenticated: false,
    );
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw Exception('Enter your staff email and password.');
    }

    final response = await ApiClient.instance.postJson(
      ApiEndpoints.staffLogin,
      authenticated: false,
      body: {
        'email': cleanEmail,
        'password': password,
      },
    );

    final rawUser = response['user'];
    if (rawUser is! Map) {
      throw Exception('The server did not return a staff profile.');
    }
    final user = AppUser.fromJson(
      rawUser.map((key, value) => MapEntry(key.toString(), value)),
    );

    if (!user.active) throw Exception('This account is disabled.');
    if (!user.isAdmin) {
      throw Exception('Access denied. Use an Admin account.');
    }

    final token = (response['api_token'] ?? '').toString();
    if (token.isEmpty) {
      throw Exception('The server did not return an access token.');
    }

    await AppConfigService.instance.saveSession(
      user: user,
      apiToken: token,
      expiresAt: response['token_expires_at']?.toString(),
    );
    return user;
  }

  Future<void> logout() async {
    try {
      if (AppConfigService.instance.apiToken.isNotEmpty) {
        await ApiClient.instance.postJson(ApiEndpoints.logout);
      }
    } catch (_) {
      // Local logout must still work when the server is offline.
    } finally {
      await AppConfigService.instance.clearSession();
    }
  }

  Future<List<AppUser>> listAccounts() async {
    final response = await ApiClient.instance.getJson(ApiEndpoints.accountList);
    return _mapList(response['users'], AppUser.fromJson);
  }

  Future<void> createAccount({
    required String displayName,
    required String email,
    required String password,
    required String role,
    String? studentId,
    required bool active,
  }) async {
    await ApiClient.instance.postJson(
      ApiEndpoints.accountCreate,
      body: {
        'display_name': displayName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'role': role.trim().toLowerCase(),
        'student_id': role == 'student' ? studentId?.trim() : null,
        'active': active,
      },
    );
  }

  Future<void> setAccountActive({
    required String uid,
    required bool active,
  }) async {
    await ApiClient.instance.postJson(
      ApiEndpoints.accountSetActive,
      body: {'uid': uid, 'active': active},
    );
  }

  Future<void> resetPassword({
    required String uid,
    required String password,
  }) async {
    await ApiClient.instance.postJson(
      ApiEndpoints.accountResetPassword,
      body: {'uid': uid, 'password': password},
    );
  }

  Future<List<RoomRecord>> listRooms() async {
    final response = await ApiClient.instance.getJson(ApiEndpoints.roomList);
    return _mapList(response['rooms'], RoomRecord.fromJson);
  }

  Future<void> createRoom({
    required String roomName,
    required int pcCount,
  }) async {
    await ApiClient.instance.postJson(
      ApiEndpoints.roomCreate,
      body: {'room_name': roomName.trim(), 'pc_count': pcCount},
    );
  }

  Future<void> setRoomActive({
    required String roomName,
    required bool active,
  }) async {
    await ApiClient.instance.postJson(
      ApiEndpoints.roomSetActive,
      body: {'room_name': roomName, 'active': active},
    );
  }

  Future<DashboardSummary> dashboard() async {
    final response = await ApiClient.instance.getJson(ApiEndpoints.dashboard);
    final raw = response['summary'];
    if (raw is! Map) throw Exception('Invalid dashboard response.');
    return DashboardSummary.fromJson(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<List<PcHealthRecord>> listPcHealth() async {
    final response = await ApiClient.instance.getJson(ApiEndpoints.pcHealth);
    return _mapList(response['records'], PcHealthRecord.fromJson);
  }

  Future<List<FaultReport>> listFaultReports() async {
    final response = await ApiClient.instance.getJson(ApiEndpoints.faultReports);
    return _mapList(response['reports'], FaultReport.fromJson);
  }

  Future<void> markRepaired({
    required String reportId,
    required String notes,
  }) async {
    await ApiClient.instance.postJson(
      ApiEndpoints.markRepaired,
      body: {'report_id': reportId, 'notes': notes.trim()},
    );
  }

  Future<List<LastKnownUserRecord>> listLastKnownUsers() async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.lastKnownUsers,
    );
    return _mapList(response['records'], LastKnownUserRecord.fromJson);
  }

  List<T> _mapList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw is! List) return <T>[];
    return raw.whereType<Map>().map((item) {
      return fromJson(
        item.map((key, value) => MapEntry(key.toString(), value)),
      );
    }).toList();
  }
}
