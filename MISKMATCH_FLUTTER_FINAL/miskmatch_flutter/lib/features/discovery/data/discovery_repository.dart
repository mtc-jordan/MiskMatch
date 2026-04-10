import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miskmatch/core/api/api_client.dart';
import 'package:miskmatch/core/api/api_endpoints.dart';
import 'package:miskmatch/shared/models/api_response.dart';
import 'package:miskmatch/features/profile/data/profile_models.dart';

class DiscoveryRepository {
  DiscoveryRepository(this._dio);
  final Dio _dio;

  // ── Fetch discovery candidates ────────────────────────────────────────────
  Future<ApiResult<List<CandidateCard>>> getDiscovery({
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.matchDiscover,
        queryParameters: {'page': page, 'page_size': pageSize},
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
      return ApiSuccess(_mockCandidates);
    } on DioException catch (_) {
      return ApiSuccess(_mockCandidates);
    } catch (_) {
      return ApiSuccess(_mockCandidates);
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

// ─────────────────────────────────────────────
// MOCK CANDIDATES — used when backend is unreachable
// ─────────────────────────────────────────────

const _mockCandidates = [
  CandidateCard(
    profile: UserProfile(
      userId:           'disc-1',
      firstName:        'Aisha',
      lastName:         'Rahman',
      age:              25,
      city:             'London',
      country:          'United Kingdom',
      bio:              'Alhamdulillah, a medical student with a love for '
                        'calligraphy and poetry. I believe in building a '
                        'home grounded in deen and mercy. Seeking someone '
                        'who prioritises salah and values family bonds.',
      madhab:           Madhab.hanafi,
      prayerFrequency:  PrayerFrequency.allFive,
      quranLevel:       'hafiz_partial',
      hijabStance:      HijabStance.wears,
      wantsChildren:    true,
      numChildrenDesired:'3-4',
      hajjTimeline:     'within_3_years',
      islamicFinanceStance: 'strict',
      occupation:       'Medical Student',
      educationLevel:   'Postgraduate',
      trustScore:       88,
      mosqueVerified:   true,
      scholarEndorsed:  false,
      idVerified:       true,
      languages:        ['English', 'Arabic', 'Urdu'],
    ),
    compatibilityScore: 92,
    hasAiScore:         true,
  ),
  CandidateCard(
    profile: UserProfile(
      userId:           'disc-2',
      firstName:        'Maryam',
      lastName:         'Al-Sayed',
      age:              27,
      city:             'Manchester',
      country:          'United Kingdom',
      bio:              'Software engineer by day, Quran student by night. '
                        'Currently memorising my 20th juz. I love hiking, '
                        'cooking Middle Eastern food, and deep conversations '
                        'about aqeedah. Looking for a partner in deen and dunya.',
      madhab:           Madhab.shafii,
      prayerFrequency:  PrayerFrequency.allFive,
      quranLevel:       'memorising',
      hijabStance:      HijabStance.wears,
      wantsChildren:    true,
      numChildrenDesired:'2-3',
      hajjTimeline:     'within_1_year',
      wantsHijra:       true,
      hijraCountry:     'Malaysia',
      occupation:       'Software Engineer',
      educationLevel:   'Bachelors',
      trustScore:       95,
      mosqueVerified:   true,
      scholarEndorsed:  true,
      idVerified:       true,
      languages:        ['English', 'Arabic'],
    ),
    compatibilityScore: 87,
    hasAiScore:         true,
  ),
  CandidateCard(
    profile: UserProfile(
      userId:           'disc-3',
      firstName:        'Fatima',
      lastName:         'Hassan',
      age:              24,
      city:             'Birmingham',
      country:          'United Kingdom',
      bio:              'Primary school teacher passionate about nurturing the '
                        'next generation of the Ummah. In my free time, I enjoy '
                        'Islamic art, baking, and volunteering at the masjid.',
      madhab:           Madhab.maliki,
      prayerFrequency:  PrayerFrequency.allFive,
      quranLevel:       'recites_tajweed',
      hijabStance:      HijabStance.wears,
      wantsChildren:    true,
      numChildrenDesired:'4+',
      hajjTimeline:     'within_5_years',
      occupation:       'Primary Teacher',
      educationLevel:   'Bachelors',
      trustScore:       76,
      mosqueVerified:   true,
      idVerified:       true,
      languages:        ['English', 'Somali'],
    ),
    compatibilityScore: 74,
    hasAiScore:         false,
  ),
  CandidateCard(
    profile: UserProfile(
      userId:           'disc-4',
      firstName:        'Zahra',
      lastName:         'Khan',
      age:              26,
      city:             'Leeds',
      country:          'United Kingdom',
      bio:              'Pharmacist and part-time Arabic tutor. I come from a '
                        'family that values knowledge and community service. '
                        'Looking for someone with taqwa, a good sense of humour, '
                        'and ambition to grow together in this life and the next.',
      madhab:           Madhab.hanafi,
      prayerFrequency:  PrayerFrequency.allFive,
      quranLevel:       'strong',
      hijabStance:      HijabStance.wears,
      isRevert:         true,
      revertYear:       2019,
      wantsChildren:    true,
      hajjTimeline:     'done',
      islamicFinanceStance: 'strict',
      occupation:       'Pharmacist',
      educationLevel:   'Masters',
      trustScore:       82,
      mosqueVerified:   false,
      scholarEndorsed:  true,
      idVerified:       true,
      languages:        ['English', 'Pashto', 'Arabic'],
    ),
    compatibilityScore: 68,
    hasAiScore:         true,
  ),
];
