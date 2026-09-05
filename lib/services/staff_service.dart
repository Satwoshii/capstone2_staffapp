import 'dart:async';
import 'dart:io';

import '../models/app_user.dart';
import '../models/dashboard_summary.dart';
import '../models/fault_report.dart';
import '../models/last_known_user_record.dart';
import '../models/lab_overview.dart';
import '../models/maintenance_record.dart';
import '../models/pc_health_record.dart';
import '../models/room_record.dart';
import '../models/support_chat_message.dart';
import '../models/support_conversation.dart';
import '../models/teacher_chat.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'app_config_service.dart';
import 'teacher_startup_service.dart';
import 'teacher_windows_session_service.dart';

class StaffService {
  StaffService._();

  static final StaffService instance = StaffService._();

  static const int minimumPasswordLength = 8;
  static const int maximumPasswordLength = 64;

  static void validatePasswordLength(String password) {
    final length = password.runes.length;
    if (length < minimumPasswordLength || length > maximumPasswordLength) {
      throw Exception(
        'Password must contain between $minimumPasswordLength and '
        '$maximumPasswordLength characters.',
      );
    }
  }

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
    validatePasswordLength(password);

    // Read the already authenticated Windows identity. These are non-secret
    // account/session details only; Syswatch never reads the Windows password
    // or PIN. A verified Teacher login uses these fields to link the Windows
    // account so future Windows logins can be recorded automatically.
    final windowsAccount =
        await TeacherWindowsSessionService.instance.currentAccount();
    final windowsPayload =
        TeacherWindowsSessionService.instance.windowsIdentityPayload() ??
            <String, dynamic>{
              'computer_name': Platform.localHostname,
              'windows_username': Platform.environment['USERNAME'] ?? '',
            };

    final response = await ApiClient.instance.postJson(
      ApiEndpoints.staffLogin,
      authenticated: false,
      body: {
        'email': cleanEmail,
        'password': password,
        ...windowsPayload,
        if (windowsAccount != null)
          'computer_name': windowsAccount.computerName,
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
    if (!user.isStaff) {
      throw Exception(
        'Access denied. Use an Admin, Super Admin, or Teacher room account.',
      );
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

    if (user.isTeacher) {
      // A successful Teacher password login is the only time the server
      // creates/rotates this per-Windows-profile auto-login secret. Future
      // launches can then open the Teacher dashboard automatically without
      // trusting a spoofable Windows username by itself.
      final autoLoginSecret =
          (response['teacher_auto_login_secret'] ?? '').toString().trim();
      if (autoLoginSecret.isNotEmpty) {
        await AppConfigService.instance
            .saveTeacherAutoLoginSecret(autoLoginSecret);
      }
      // After the first trusted Teacher login, future Windows sign-ins on this
      // profile can be recorded automatically without waiting for the Teacher
      // to re-enter the session details manually.
      await TeacherStartupService.instance.ensureEnabled();
      unawaited(
        TeacherWindowsSessionService.instance
            .ensureRecordedAfterTeacherLogin(),
      );
    }

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
    String? assignedRoomName,
    required bool active,
  }) async {
    final normalizedRole = role.trim().toLowerCase();
    if (normalizedRole != AppUser.studentRole &&
        normalizedRole != AppUser.adminRole &&
        normalizedRole != AppUser.teacherRole) {
      throw ArgumentError(
        'Only Student, Teacher, and Admin accounts can be created.',
      );
    }
    validatePasswordLength(password);
    await ApiClient.instance.postJson(
      ApiEndpoints.accountCreate,
      body: {
        'display_name': displayName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'role': normalizedRole,
        'student_id': normalizedRole == AppUser.studentRole
            ? studentId?.trim()
            : null,
        'assigned_room_name': normalizedRole == AppUser.teacherRole
            ? assignedRoomName?.trim()
            : null,
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
    validatePasswordLength(password);
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

  Future<void> acceptReport(String reportId) async {
    await ApiClient.instance.postJson(
      ApiEndpoints.acceptReport,
      body: {'report_id': reportId},
    );
  }

  Future<void> heartbeatStaffSession() async {
    await ApiClient.instance.postJson(ApiEndpoints.staffSessionHeartbeat);
  }

  Future<List<LastKnownUserRecord>> listLastKnownUsers() async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.lastKnownUsers,
    );
    return _mapList(response['records'], LastKnownUserRecord.fromJson);
  }

  Future<List<MaintenanceSchedule>> listMaintenanceSchedule() async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.maintenanceSchedule,
    );
    return _mapList(response['workstations'], MaintenanceSchedule.fromJson);
  }

  Future<List<MaintenanceRecord>> listMaintenanceHistory({
    String? workstationId,
  }) async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.maintenanceHistory,
      query: workstationId == null || workstationId.trim().isEmpty
          ? null
          : {'workstation_id': workstationId.trim()},
    );
    return _mapList(response['records'], MaintenanceRecord.fromJson);
  }

  Future<void> completePreventiveMaintenance({
    required String workstationId,
    required Map<String, bool> checklist,
    required String overallCondition,
    required String findings,
    required String actionsTaken,
    required String recommendations,
  }) async {
    await ApiClient.instance.postJson(
      ApiEndpoints.completeMaintenance,
      body: {
        'workstation_id': workstationId,
        'checklist': checklist,
        'overall_condition': overallCondition,
        'findings': findings.trim(),
        'actions_taken': actionsTaken.trim(),
        'recommendations': recommendations.trim(),
      },
    );
  }

  Future<List<LabOverview>> listLabOverview() async {
    final response = await ApiClient.instance.getJson(ApiEndpoints.labOverview);
    return _mapList(response['rooms'], LabOverview.fromJson);
  }

  Future<LabOverview> teacherOverview() async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.teacherOverview,
    );
    final rawRoom = response['room'];
    if (rawRoom is! Map) throw Exception('Invalid Teacher room response.');
    return LabOverview.fromJson(
      rawRoom.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<List<FaultReport>> listTeacherReports() async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.teacherReports,
    );
    return _mapList(response['reports'], FaultReport.fromJson);
  }

  Future<String> createTeacherReport({
    required String workstationId,
    required String issue,
    required String details,
    required String severity,
  }) async {
    final response = await ApiClient.instance.postJson(
      ApiEndpoints.teacherCreateReport,
      body: {
        'workstation_id': workstationId,
        'issue': issue.trim(),
        'details': details.trim(),
        'severity': severity,
      },
    );
    final reportId = (response['report_id'] ?? '').toString();
    if (reportId.isEmpty) throw Exception('The server did not return the report id.');
    return reportId;
  }

  Future<void> forwardTeacherReport({
    required String reportId,
    required String notes,
  }) async {
    await ApiClient.instance.postJson(
      ApiEndpoints.teacherForwardReport,
      body: {'report_id': reportId, 'notes': notes.trim()},
    );
  }

  Future<void> verifyTeacherRepair({
    required String reportId,
    required bool approved,
    required String notes,
  }) async {
    await ApiClient.instance.postJson(
      ApiEndpoints.teacherVerifyRepair,
      body: {
        'report_id': reportId,
        'decision': approved ? 'approve' : 'reopen',
        'notes': notes.trim(),
      },
    );
  }

  Future<(TeacherChatConversation, List<TeacherChatMessage>)>
      teacherChatOverview() async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.teacherChatOverview,
    );
    final rawConversation = response['conversation'];
    if (rawConversation is! Map) {
      throw Exception('The server did not return the Teacher chat.');
    }
    final conversation = TeacherChatConversation.fromJson(
      rawConversation.map((key, value) => MapEntry(key.toString(), value)),
    );
    final messages = _mapList(
      response['messages'],
      TeacherChatMessage.fromJson,
    );
    return (conversation, messages);
  }

  Future<TeacherChatMessage> sendTeacherChatMessage(String message) async {
    final response = await ApiClient.instance.postJson(
      ApiEndpoints.teacherChatSend,
      body: {'message': message.trim()},
    );
    return _teacherChatMessage(response);
  }

  Future<List<TeacherChatConversation>> listAdminTeacherChats() async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.adminTeacherChatConversations,
    );
    return _mapList(
      response['conversations'],
      TeacherChatConversation.fromJson,
    );
  }

  Future<List<TeacherChatMessage>> listAdminTeacherChatMessages(
    int conversationId,
  ) async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.adminTeacherChatMessages,
      query: {'conversation_id': conversationId.toString()},
    );
    return _mapList(response['messages'], TeacherChatMessage.fromJson);
  }

  Future<TeacherChatMessage> sendAdminTeacherChatMessage({
    required int conversationId,
    required String message,
  }) async {
    final response = await ApiClient.instance.postJson(
      ApiEndpoints.adminTeacherChatSend,
      body: {'conversation_id': conversationId, 'message': message.trim()},
    );
    return _teacherChatMessage(response);
  }

  Future<void> updateAdminTeacherChatStatus({
    required int conversationId,
    required String status,
  }) async {
    await ApiClient.instance.postJson(
      ApiEndpoints.adminTeacherChatUpdateStatus,
      body: {'conversation_id': conversationId, 'status': status},
    );
  }

  TeacherChatMessage _teacherChatMessage(Map<String, dynamic> response) {
    final raw = response['message'];
    if (raw is! Map) {
      throw Exception('The server did not return the sent chat message.');
    }
    return TeacherChatMessage.fromJson(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
  }



  Future<List<SupportConversation>> listSupportConversations({
    String status = 'all',
  }) async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.supportConversations,
      query: status == 'all' ? null : {'status': status},
    );
    return _mapList(
      response['conversations'],
      SupportConversation.fromJson,
    );
  }

  Future<List<SupportChatMessage>> listSupportMessages(
    int conversationId,
  ) async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.supportMessages,
      query: {'conversation_id': conversationId.toString()},
    );
    return _mapList(response['messages'], SupportChatMessage.fromJson);
  }

  Future<SupportChatMessage> sendSupportMessage({
    required int conversationId,
    required String message,
  }) async {
    final response = await ApiClient.instance.postJson(
      ApiEndpoints.supportSend,
      body: {
        'conversation_id': conversationId,
        'message': message.trim(),
      },
    );
    final raw = response['message'];
    if (raw is! Map) {
      throw Exception('The server did not return the sent message.');
    }
    return SupportChatMessage.fromJson(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<void> updateSupportStatus({
    required int conversationId,
    required String status,
  }) async {
    await ApiClient.instance.postJson(
      ApiEndpoints.supportUpdateStatus,
      body: {
        'conversation_id': conversationId,
        'status': status,
      },
    );
  }

  Future<void> markSupportRead(int conversationId) async {
    await ApiClient.instance.postJson(
      ApiEndpoints.supportMarkRead,
      body: {'conversation_id': conversationId},
    );
  }

  Future<void> uploadReportAttachment({
    required String reportId,
    required String attachmentType,
    required File image,
  }) async {
    await ApiClient.instance.postMultipartFile(
      ApiEndpoints.attachmentUpload,
      fileField: 'image',
      file: image,
      fields: {
        'report_id': reportId,
        'attachment_type': attachmentType,
      },
    );
  }

  Future<List<Map<String, dynamic>>> listReportAttachments(String reportId) async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.attachmentList,
      query: {'report_id': reportId},
    );
    return _rawMapList(response['attachments']);
  }

  Future<File> downloadReportAttachment({
    required String attachmentId,
    required String originalFileName,
  }) {
    final safeName = originalFileName.trim().isEmpty
        ? 'syswatch_evidence_$attachmentId.jpg'
        : originalFileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return ApiClient.instance.downloadToDownloads(
      ApiEndpoints.attachmentDownload,
      query: {'id': attachmentId},
      fallbackFileName: safeName,
    );
  }

  Future<List<Map<String, dynamic>>> listWorkstationInventory({String? roomName}) async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.workstationInventory,
      query: roomName == null || roomName.trim().isEmpty ? null : {'room_name': roomName.trim()},
    );
    return _rawMapList(response['records']);
  }

  Future<List<Map<String, dynamic>>> listSoftwareCompliance({String? roomName}) async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.softwareCompliance,
      query: roomName == null || roomName.trim().isEmpty ? null : {'room_name': roomName.trim()},
    );
    return _rawMapList(response['records']);
  }

  Future<List<Map<String, dynamic>>> listRequiredSoftware({String? roomName}) async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.requiredSoftware,
      query: roomName == null || roomName.trim().isEmpty ? null : {'room_name': roomName.trim()},
    );
    return _rawMapList(response['required_software']);
  }

  Future<void> saveRequiredSoftware({
    required String roomName,
    required String softwareName,
    String publisher = '',
    String minimumVersion = '',
    String matchPattern = '',
  }) async {
    await ApiClient.instance.postJson(ApiEndpoints.requiredSoftware, body: {
      'action': 'save',
      'room_name': roomName.trim(),
      'software_name': softwareName.trim(),
      'publisher': publisher.trim(),
      'minimum_version': minimumVersion.trim(),
      'match_pattern': matchPattern.trim(),
      'active': true,
    });
  }

  /// Creates the same requirement for every selected room using the existing
  /// API contract. This keeps the feature compatible with current Syswatch
  /// servers while removing the need to submit the form one room at a time.
  Future<int> saveRequiredSoftwareForRooms({
    required Iterable<String> roomNames,
    required String softwareName,
    String publisher = '',
    String minimumVersion = '',
    String matchPattern = '',
  }) async {
    final rooms = roomNames
        .map((room) => room.trim())
        .where((room) => room.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final cleanName = softwareName.trim();
    final cleanPattern = matchPattern.trim();

    if (rooms.isEmpty) {
      throw Exception('Select at least one room.');
    }
    if (cleanName.isEmpty) {
      throw Exception('Enter the software name.');
    }
    if (cleanPattern.isEmpty) {
      throw Exception('Enter text used to identify the installed app.');
    }

    var saved = 0;
    for (final roomName in rooms) {
      try {
        await saveRequiredSoftware(
          roomName: roomName,
          softwareName: cleanName,
          publisher: publisher,
          minimumVersion: minimumVersion,
          matchPattern: cleanPattern,
        );
        saved++;
      } catch (error) {
        throw Exception(
          saved == 0
              ? 'Could not save the requirement for room $roomName: $error'
              : 'Saved $saved of ${rooms.length} rooms. Room $roomName failed: $error',
        );
      }
    }
    return saved;
  }

  Future<void> deleteRequiredSoftware(int id) async {
    await ApiClient.instance.postJson(ApiEndpoints.requiredSoftware, body: {'action': 'delete', 'id': id});
  }

  Future<void> manuallyVerifySoftware({
    required String workstationId,
    required int requiredSoftwareId,
    String notes = '',
  }) async {
    await ApiClient.instance.postJson(ApiEndpoints.requiredSoftware, body: {
      'action': 'manual_verify',
      'workstation_id': workstationId,
      'required_software_id': requiredSoftwareId,
      'notes': notes.trim(),
    });
  }

  Future<File> exportRecords({
    required String type,
    required String format,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? roomName,
  }) {
    final query = <String, String>{
      'type': type,
      'format': format,
      if (dateFrom != null)
        'date_from': DateTime(dateFrom.year, dateFrom.month, dateFrom.day)
            .toUtc()
            .toIso8601String(),
      if (dateTo != null)
        'date_to': DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59)
            .toUtc()
            .toIso8601String(),
      if (roomName != null && roomName.trim().isNotEmpty) 'room_name': roomName.trim(),
    };
    return ApiClient.instance.downloadToDownloads(
      ApiEndpoints.exportRecords,
      query: query,
      fallbackFileName: 'syswatch_${type}_${DateTime.now().millisecondsSinceEpoch}.$format',
    );
  }

  List<Map<String, dynamic>> _rawMapList(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((item) => item.map((key, value) => MapEntry(key.toString(), value))).toList();
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
