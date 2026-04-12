import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miskmatch/core/api/api_client.dart';
import 'package:miskmatch/core/api/api_endpoints.dart';
import 'package:miskmatch/shared/models/api_response.dart';
import 'package:miskmatch/features/profile/data/profile_models.dart';
// ─────────────────────────────────────────────
// DISCOVERY FILTERS (shared between repo and provider)
// ─────────────────────────────────────────────

class DiscoveryFilters {
  const DiscoveryFilters({
    this.minAge,
    this.maxAge,
    this.country,
    this.madhab,
    this.prayer,
  });

  final int?    minAge;
  final int?    maxAge;
  final String? country;
  final String? madhab;
  final String? prayer;

  bool get hasActiveFilters =>
      minAge != null || maxAge != null || country != null ||
      madhab != null || prayer != null;

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    if (minAge != null) params['min_age'] = minAge;
    if (maxAge != null) params['max_age'] = maxAge;
    if (country != null) params['country'] = country;
    if (madhab != null) params['madhab'] = madhab;
    if (prayer != null) params['prayer'] = prayer;
    return params;
  }
}

class DiscoveryRepository {
  DiscoveryRepository(this._dio);
  final Dio _dio;

  // ── Fetch discovery candidates ────────────────────────────────────────────
  Future<ApiResult<List<CandidateCard>>> getDiscovery({
    int page = 1,
    int pageSize = 10,
    DiscoveryFilters filters = const DiscoveryFilters(),
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.matchDiscover,
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          ...filters.toQueryParams(),
        },
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        final candidates = (data['candidates'] as List<dynamic>? ?? [])
            .map((item) {
              final m = item as Map<String, dynamic>;
              return CandidateCard(
                profile: UserProfile.fromJson(m),
                compatibilityScore:
                    (m['compatibility_score'] as num?)?.toDouble() ?? 0,
                hasAiScore: m['has_ai_scoring'] as bool? ?? false,
              );
            })
            .toList();
        return ApiSuccess(candidates);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Express interest ──────────────────────────────────────────────────────
  Future<ApiResult<String>> expressInterest({
    required String receiverId,
    required String message,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.matchInterest,
        data: {'receiver_id': receiverId, 'message': message},
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return const ApiSuccess('Interest expressed. JazakAllah Khair.');
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }

  // ── Preview compatibility ─────────────────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> previewCompatibility(
      String candidateId) async {
    try {
      final res = await _dio.get(
          ApiEndpoints.compatPreview(candidateId));
      if (res.statusCode == 200) {
        return ApiSuccess(res.data as Map<String, dynamic>);
      }
      return ApiError(AppError.fromResponse(res.statusCode, res.data));
    } on DioException catch (e) {
      return ApiError(AppError.fromDio(e));
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final discoveryRepositoryProvider = Provider<DiscoveryRepository>(
  (ref) => DiscoveryRepository(ref.watch(dioProvider)),
);
