import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miskmatch/core/api/api_client.dart';
import 'package:miskmatch/core/api/api_endpoints.dart';
import 'package:miskmatch/shared/models/api_response.dart';
import 'wali_models.dart';

class WaliRepository {
  WaliRepository(this._dio);
  final Dio _dio;

  // ── Guardian dashboard ────────────────────────────────────────────────────
  Future<ApiResult<WaliDashboard>> getDashboard() async {
    try {
      final res = await _dio.get(ApiEndpoints.waliDashboard,
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      if (res.statusCode == 200) {
        return ApiSuccess(
            WaliDashboard.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiSuccess(_mockDashboard);
    } on DioException catch (_) {
      return ApiSuccess(_mockDashboard);
    } catch (_) {
      return ApiSuccess(_mockDashboard);
    }
  }

  // ── Wards list ────────────────────────────────────────────────────────────
  Future<ApiResult<List<Ward>>> getWards() async {
    try {
      final res = await _dio.get(ApiEndpoints.waliWards,
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      if (res.statusCode == 200) {
        final data  = res.data as Map<String, dynamic>;
        final items = (data['wards'] as List<dynamic>? ?? [])
            .map((e) => Ward.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiSuccess(items);
      }
      return ApiSuccess(_mockDashboard.wards);
    } on DioException catch (_) {
      return ApiSuccess(_mockDashboard.wards);
    } catch (_) {
      return ApiSuccess(_mockDashboard.wards);
    }
  }

  // ── Pending decisions ─────────────────────────────────────────────────────
  Future<ApiResult<List<WaliMatchDecision>>> getPendingDecisions() async {
    try {
      final res = await _dio.get(ApiEndpoints.waliPending,
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      if (res.statusCode == 200) {
        final data  = res.data as Map<String, dynamic>;
        final items = (data['decisions'] as List<dynamic>? ?? [])
            .map((e) => WaliMatchDecision.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiSuccess(items);
      }
      return ApiSuccess(_mockDashboard.pendingDecisions);
    } on DioException catch (_) {
      return ApiSuccess(_mockDashboard.pendingDecisions);
    } catch (_) {
      return ApiSuccess(_mockDashboard.pendingDecisions);
    }
  }

  // ── Decide on a match ─────────────────────────────────────────────────────
  Future<ApiResult<String>> decide(WaliDecisionRequest req) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.waliDecide(req.matchId),
        data: req.toJson(),
      );
      if (res.statusCode == 200) {
        final msg = req.approved
            ? 'Alhamdulillah — Match approved. May Allah bless this union.'
            : 'Noted. The match has been respectfully declined.';
        return ApiSuccess(msg);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Wali setup ────────────────────────────────────────────────────────────
  Future<ApiResult<WaliStatus>> setup(WaliSetupRequest req) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.waliSetup,
        data: req.toJson(),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return ApiSuccess(
            WaliStatus.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Wali status ───────────────────────────────────────────────────────────
  Future<ApiResult<WaliStatus>> getStatus() async {
    try {
      final res = await _dio.get(ApiEndpoints.waliStatus,
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      if (res.statusCode == 200) {
        return ApiSuccess(
            WaliStatus.fromJson(res.data as Map<String, dynamic>));
      }
      return ApiSuccess(_mockStatus);
    } on DioException catch (_) {
      return ApiSuccess(_mockStatus);
    } catch (_) {
      return ApiSuccess(_mockStatus);
    }
  }

  // ── Accept wali invite ────────────────────────────────────────────────────
  Future<ApiResult<String>> acceptInvite(String token) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.waliAccept,
        data: {'token': token},
      );
      if (res.statusCode == 200) {
        return const ApiSuccess('Welcome to MiskMatch Guardian Portal.');
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Update permissions ────────────────────────────────────────────────────
  Future<ApiResult<WaliPermissions>> updatePermissions(
      WaliPermissions permissions) async {
    try {
      final res = await _dio.put(
        ApiEndpoints.waliPermissions,
        data: permissions.toJson(),
      );
      if (res.statusCode == 200) {
        return ApiSuccess(WaliPermissions.fromJson(
            res.data as Map<String, dynamic>));
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Conversations (read messages as wali) ─────────────────────────────────
  Future<ApiResult<List<WaliConversation>>> getConversations() async {
    try {
      final res = await _dio.get(ApiEndpoints.waliConversations,
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      if (res.statusCode == 200) {
        final data  = res.data as Map<String, dynamic>;
        final items = (data['conversations'] as List<dynamic>? ?? [])
            .map((e) => WaliConversation.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiSuccess(items);
      }
      return ApiSuccess(_mockConversations);
    } on DioException catch (_) {
      return ApiSuccess(_mockConversations);
    } catch (_) {
      return ApiSuccess(_mockConversations);
    }
  }

  // ── Resend invite SMS ─────────────────────────────────────────────────────
  Future<ApiResult<String>> resendInvite() async {
    try {
      final res = await _dio.post(ApiEndpoints.waliInviteResend);
      if (res.statusCode == 200) {
        return const ApiSuccess('Invitation resent to your guardian.');
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }
}

final waliRepositoryProvider = Provider<WaliRepository>(
    (ref) => WaliRepository(ref.watch(dioProvider)));

// ─────────────────────────────────────────────
// MOCK DATA — used when backend is unreachable
// ─────────────────────────────────────────────

final _now = DateTime.now();

final _mockDashboard = WaliDashboard(
  wards: [
    Ward(
      userId:           'ward-1',
      firstName:        'Fatima',
      lastName:         'Al-Rashid',
      relationship:     WaliRelationship.father,
      permissions:      const WaliPermissions(
        canReadMessages:       true,
        mustApproveMatches:    true,
        receivesNotifications: true,
        canJoinCalls:          true,
      ),
      pendingDecisions: 2,
      activeMatches:    3,
      joinedAt:         _now.subtract(const Duration(days: 45)),
    ),
    Ward(
      userId:           'ward-2',
      firstName:        'Amina',
      lastName:         'Al-Rashid',
      relationship:     WaliRelationship.father,
      permissions:      const WaliPermissions(
        canReadMessages:       false,
        mustApproveMatches:    true,
        receivesNotifications: true,
        canJoinCalls:          false,
      ),
      pendingDecisions: 0,
      activeMatches:    1,
      joinedAt:         _now.subtract(const Duration(days: 12)),
    ),
  ],
  pendingCount:     2,
  totalMatches:     4,
  pendingDecisions: [
    WaliMatchDecision(
      matchId:            'match-101',
      wardId:             'ward-1',
      wardName:           'Fatima',
      candidateId:        'cand-1',
      candidateName:      'Ahmad K.',
      candidateAge:       27,
      senderMessage:      'Assalamu Alaikum. I am seeking a righteous spouse '
                          'and was impressed by Fatima\'s profile. '
                          'I would be honoured to get to know her with your blessing.',
      compatibilityScore: 0.87,
      receivedAt:         _now.subtract(const Duration(hours: 3)),
      candidateCity:      'London',
      candidateMadhab:    'Hanafi',
      candidatePrayerFreq:'5 daily',
      candidateBio:       'Software engineer, memorised 15 juz. '
                          'Seeking a partner who values deen and family.',
      candidateTrustScore:       82,
      candidateMosqueVerified:   true,
    ),
    WaliMatchDecision(
      matchId:            'match-102',
      wardId:             'ward-1',
      wardName:           'Fatima',
      candidateId:        'cand-2',
      candidateName:      'Yusuf M.',
      candidateAge:       30,
      senderMessage:      'Bismillah. I am a teacher and imam at my local masjid. '
                          'I am looking for a partner who shares my commitment '
                          'to the Quran and community service.',
      compatibilityScore: 0.74,
      receivedAt:         _now.subtract(const Duration(days: 1)),
      candidateCity:      'Manchester',
      candidateMadhab:    'Shafi\'i',
      candidatePrayerFreq:'5 daily + sunnah',
      candidateBio:       'Imam and Arabic teacher. Hafiz al-Quran. '
                          'Love hiking and reading tafsir.',
      candidateTrustScore:       91,
      candidateMosqueVerified:   true,
    ),
  ],
  flaggedMessages: [
    FlaggedMessage(
      messageId:        'msg-201',
      matchId:          'match-103',
      senderId:         'cand-3',
      senderName:       'Omar H.',
      content:          'Can we meet alone somewhere private without telling anyone?',
      flaggedAt:        _now.subtract(const Duration(hours: 6)),
      moderationReason: 'Suggestion to meet privately without guardian knowledge',
      wardId:           'ward-1',
      wardName:         'Fatima',
    ),
    FlaggedMessage(
      messageId:        'msg-202',
      matchId:          'match-104',
      senderId:         'cand-4',
      senderName:       'Khalid R.',
      content:          'You should send me your personal number so we can '
                        'talk without the app monitoring.',
      flaggedAt:        _now.subtract(const Duration(days: 2)),
      moderationReason: 'Attempt to move communication off-platform',
      wardId:           'ward-1',
      wardName:         'Fatima',
    ),
  ],
);

const _mockStatus = WaliStatus(
  hasWali:      true,
  waliId:       'wali-001',
  waliName:     'Abu Abdullah',
  waliPhone:    '+44 7700 900000',
  relationship: WaliRelationship.father,
  accepted:     true,
  permissions:  WaliPermissions(
    canReadMessages:       true,
    mustApproveMatches:    true,
    receivesNotifications: true,
    canJoinCalls:          true,
  ),
);

final _mockConversations = [
  WaliConversation(
    matchId:       'match-103',
    wardName:      'Fatima',
    candidateName: 'Ahmad K.',
    lastMessage:   'JazakAllah khair for sharing that. I will speak with my family.',
    lastMessageAt: _now.subtract(const Duration(minutes: 35)),
    totalMessages: 24,
    unreadCount:   3,
  ),
  WaliConversation(
    matchId:       'match-104',
    wardName:      'Fatima',
    candidateName: 'Yusuf M.',
    lastMessage:   'In sha Allah, I hope to hear back from your father soon.',
    lastMessageAt: _now.subtract(const Duration(hours: 4)),
    totalMessages: 12,
    unreadCount:   0,
  ),
  WaliConversation(
    matchId:       'match-105',
    wardName:      'Amina',
    candidateName: 'Ibrahim S.',
    lastMessage:   'Wa alaikum assalam. Yes, I am originally from Egypt.',
    lastMessageAt: _now.subtract(const Duration(days: 1)),
    totalMessages: 8,
    unreadCount:   1,
  ),
];
