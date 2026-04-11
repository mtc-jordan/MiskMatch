/// MiskMatch — API Endpoint Registry
/// Single source of truth for all backend paths.

abstract class ApiEndpoints {
  // ── Auth ──────────────────────────────────────────────────────────────────
  static const authRegister   = '/auth/register';
  static const authVerifyOtp  = '/auth/verify-otp';
  static const authLogin      = '/auth/login';
  static const authRefresh    = '/auth/refresh';
  static const authResendOtp  = '/auth/resend-otp';
  static const authLogout     = '/auth/logout';
  static const authDeviceToken = '/auth/device-token';
  static const authDeleteAccount = '/auth/account';

  // ── Profiles ──────────────────────────────────────────────────────────────
  static const profileMe          = '/profiles/me';
  static const profileCompletion  = '/profiles/me/completion';
  static const profilePhoto       = '/profiles/me/photo';
  static const profileGallery     = '/profiles/me/gallery';
  static const profileVoice       = '/profiles/me/voice';
  static const profileFamily      = '/profiles/me/family';
  static const profileSifr        = '/profiles/me/sifr';
  static const profilePreferences = '/profiles/me/preferences';
  static String profileById(String id) => '/profiles/$id';

  // ── Matches ───────────────────────────────────────────────────────────────
  static const matchDiscover       = '/matches/discover';
  static const matchInterest       = '/matches/interest';
  static const matchList           = '/matches/';
  static const matchWaliPending    = '/matches/wali/pending';
  static String matchById(String id) => '/matches/$id';
  static String matchRespond(String id) => '/matches/$id/respond';
  static String matchWaliApprove(String id) => '/matches/$id/wali-approve';
  static String matchClose(String id) => '/matches/$id/close';
  static String matchNikah(String id) => '/matches/$id/nikah';
  static String matchCompat(String id) => '/matches/$id/compatibility';

  // ── Messages ──────────────────────────────────────────────────────────────
  static String messages(String matchId) => '/messages/$matchId';
  static String messagesRead(String matchId) => '/messages/$matchId/read';
  static String messagesReport(String matchId) => '/messages/$matchId/report';
  static String messagesWs(String matchId, String token) =>
      '/messages/ws/$matchId?token=$token';
  static const waliConversations = '/messages/wali/conversations';
  static String waliMessages(String matchId) => '/messages/wali/$matchId';

  // ── Games ─────────────────────────────────────────────────────────────────
  static String gameCatalogue(String matchId) => '/games/$matchId';
  static String gameStart(String matchId, String type) =>
      '/games/$matchId/$type/start';
  static String gameState(String matchId, String type) =>
      '/games/$matchId/$type';
  static String gameTurn(String matchId, String type) =>
      '/games/$matchId/$type/turn';
  static String gameRealtime(String matchId, String type) =>
      '/games/$matchId/$type/realtime';
  static String timeCapsuleSeal(String matchId) =>
      '/games/$matchId/time-capsule/seal';
  static String timeCapsuleOpen(String matchId) =>
      '/games/$matchId/time-capsule/open';
  static String memoryTimeline(String matchId) => '/games/$matchId/memory';
  static String gameWs(String matchId, String token) =>
      '/games/ws/$matchId?token=$token';

  // ── Wali ─────────────────────────────────────────────────────────────────
  static const waliSetup          = '/wali/setup';
  static const waliInvite         = '/wali/invite';
  static const waliInviteResend   = '/wali/invite/resend';
  static const waliAccept         = '/wali/accept';
  static const waliStatus         = '/wali/status';
  static const waliPermissions    = '/wali/permissions';
  static const wali               = '/wali';
  static const waliDashboard      = '/wali/dashboard';
  static const waliWards          = '/wali/wards';
  static const waliPending        = '/wali/decisions/pending';
  static String waliMatch(String id) => '/wali/matches/$id';
  static String waliDecide(String id) => '/wali/matches/$id/decide';

  // ── Calls ────────────────────────────────────────────────────────────────
  static const callInitiate = '/calls/initiate';
  static String callJoin(String id)        => '/calls/$id/join';
  static String callEnd(String id)         => '/calls/$id/end';
  static String callById(String id)        => '/calls/$id';
  static String callMatchHistory(String matchId) => '/calls/match/$matchId';
  static String callWaliApprove(String id) => '/calls/$id/wali-approve';

  // ── Message media ────────────────────────────────────────────────────────
  static String messageAudio(String matchId) => '/messages/$matchId/audio';

  // ── Compatibility ─────────────────────────────────────────────────────────
  static String compatMatch(String matchId) => '/compatibility/$matchId';
  static String compatPreview(String userId) => '/compatibility/preview/$userId';
  static const compatEmbed     = '/compatibility/embed/me';
  static const compatAdminStats= '/compatibility/admin/stats';
}
