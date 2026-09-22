import 'dart:io';

import '../models/fault_report.dart';
import '../models/lab_overview.dart';
import '../models/teacher_chat.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'app_config_service.dart';

/// Teacher-only API service.
///
/// This standalone app intentionally exposes only the Teacher workflow. Admin,
/// Super Admin, and ITSO screens/actions remain in the separate Admin app.
class TeacherService {
  TeacherService._();

  static final TeacherService instance = TeacherService._();

  // Teacher authentication is automatic from the current Windows session.
  // This service contains only Teacher dashboard/actions; there is no Teacher
  // email/password login or first-time linking flow.


  /// Authenticates an Admin/Super Admin for the protected Ctrl+Shift+A
  /// Teacher-room configuration and returns active Teacher accounts and rooms.
  Future<Map<String, dynamic>> loadRoomConfiguration({
    required String adminEmail,
    required String adminPassword,
  }) async {
    return ApiClient.instance.postJson(
      ApiEndpoints.teacherConfigureRoom,
      authenticated: false,
      body: {
        'action': 'load',
        'admin_email': adminEmail.trim(),
        'admin_password': adminPassword,
      },
    );
  }

  /// Saves the room used by the selected shared Teacher account. The server
  /// rechecks the Admin/Super Admin credentials before changing the mapping.
  /// If the room does not exist yet, the API creates it with [pcCount].
  Future<Map<String, dynamic>> configureRoom({
    required String adminEmail,
    required String adminPassword,
    required String teacherUid,
    required String roomName,
    required int pcCount,
  }) async {
    return ApiClient.instance.postJson(
      ApiEndpoints.teacherConfigureRoom,
      authenticated: false,
      body: {
        'action': 'save',
        'admin_email': adminEmail.trim(),
        'admin_password': adminPassword,
        'teacher_uid': teacherUid.trim(),
        'room_name': roomName.trim(),
        'pc_count': pcCount,
      },
    );
  }

  Future<void> logout() async {
    try {
      if (AppConfigService.instance.apiToken.isNotEmpty) {
        await ApiClient.instance.postJson(ApiEndpoints.logout);
      }
    } catch (_) {
      // Closing the Teacher app must still work when the LAN is unavailable.
    } finally {
      await AppConfigService.instance.clearSession();
    }
  }

  Future<void> heartbeatSession() async {
    await ApiClient.instance.postJson(ApiEndpoints.staffSessionHeartbeat);
  }

  Future<LabOverview> overview() async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.teacherOverview,
    );
    final rawRoom = response['room'];
    if (rawRoom is! Map) {
      throw Exception('Invalid Teacher room response.');
    }
    return LabOverview.fromJson(
      rawRoom.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<List<FaultReport>> listReports() async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.teacherReports,
    );
    return _mapList(response['reports'], FaultReport.fromJson);
  }

  Future<String> createReport({
    required String workstationId,
    required String pcId,
    required String issue,
    required String details,
    required String severity,
  }) async {
    final response = await ApiClient.instance.postJson(
      ApiEndpoints.teacherCreateReport,
      body: {
        'workstation_id': workstationId,
        'pc_id': pcId.trim(),
        'issue': issue.trim(),
        'details': details.trim(),
        'severity': severity,
      },
    );
    final reportId = (response['report_id'] ?? '').toString();
    if (reportId.isEmpty) {
      throw Exception('The server did not return the report id.');
    }
    return reportId;
  }

  Future<void> forwardReport({
    required String reportId,
    required String notes,
  }) async {
    await ApiClient.instance.postJson(
      ApiEndpoints.teacherForwardReport,
      body: {
        'report_id': reportId,
        'notes': notes.trim(),
      },
    );
  }

  Future<void> verifyRepair({
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
      chatOverview() async {
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

  Future<TeacherChatMessage> sendChatMessage(String message) async {
    final response = await ApiClient.instance.postJson(
      ApiEndpoints.teacherChatSend,
      body: {'message': message.trim()},
    );
    final raw = response['message'];
    if (raw is! Map) {
      throw Exception('The server did not return the sent chat message.');
    }
    return TeacherChatMessage.fromJson(
      raw.map((key, value) => MapEntry(key.toString(), value)),
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
