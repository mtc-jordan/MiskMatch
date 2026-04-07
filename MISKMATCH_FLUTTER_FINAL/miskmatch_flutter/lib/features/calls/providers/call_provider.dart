import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../data/call_models.dart';
import '../data/call_repository.dart';
import 'package:miskmatch/shared/models/api_response.dart';

// ─────────────────────────────────────────────
// AGORA ENGINE ABSTRACTION
// ─────────────────────────────────────────────

/// Callback signature for remote user events from Agora SDK.
typedef OnRemoteUserJoined = void Function(int uid);
typedef OnRemoteUserLeft   = void Function(int uid);

abstract class AgoraEngineInterface {
  Future<void> initialize(String appId);
  Future<void> joinChannel({
    required String token,
    required String channelName,
    required int    uid,
    required bool   publishVideo,
  });
  Future<void> leaveChannel();
  Future<void> muteLocalAudio(bool muted);
  Future<void> muteLocalVideo(bool muted);
  Future<void> enableSpeakerphone(bool enabled);
  Future<void> switchCamera();
  void dispose();

  /// Set callbacks so CallNotifier receives remote user events.
  OnRemoteUserJoined? onUserJoined;
  OnRemoteUserLeft?   onUserLeft;
}

/// Real Agora RTC Engine implementation.
class AgoraEngine implements AgoraEngineInterface {
  RtcEngine? _engine;

  @override OnRemoteUserJoined? onUserJoined;
  @override OnRemoteUserLeft?   onUserLeft;

  @override
  Future<void> initialize(String appId) async {
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint('Agora: joined channel ${connection.channelId} in ${elapsed}ms');
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint('Agora: remote user $remoteUid joined');
        onUserJoined?.call(remoteUid);
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        debugPrint('Agora: remote user $remoteUid left ($reason)');
        onUserLeft?.call(remoteUid);
      },
      onError: (ErrorCodeType code, String msg) {
        debugPrint('Agora error: $code — $msg');
      },
    ));

    await _engine!.enableAudio();
  }

  @override
  Future<void> joinChannel({
    required String token,
    required String channelName,
    required int    uid,
    required bool   publishVideo,
  }) async {
    if (_engine == null) return;

    if (publishVideo) {
      await _engine!.enableVideo();
    } else {
      await _engine!.disableVideo();
    }

    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishMicrophoneTrack: true,
        publishCameraTrack: publishVideo,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );
  }

  @override
  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
  }

  @override
  Future<void> muteLocalAudio(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  @override
  Future<void> muteLocalVideo(bool muted) async {
    await _engine?.muteLocalVideoStream(muted);
  }

  @override
  Future<void> enableSpeakerphone(bool enabled) async {
    await _engine?.setEnableSpeakerphone(enabled);
  }

  @override
  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    _engine = null;
  }
}

// ─────────────────────────────────────────────
// CALL STATE
// ─────────────────────────────────────────────

enum CallPhase {
  idle,       // no call
  initiating, // posting to backend
  ringing,    // waiting for receiver to answer
  connecting, // joining Agora channel
  active,     // in call
  ending,     // posting end to backend
  ended,      // call finished
  failed,     // something went wrong
}

class CallState {
  const CallState({
    this.phase         = CallPhase.idle,
    this.call,
    this.participants  = const [],
    this.myAudioMuted  = false,
    this.myVideoMuted  = false,
    this.speakerOn     = true,
    this.frontCamera   = true,
    this.elapsedSeconds= 0,
    this.error,
    this.waliJoined    = false,
  });

  final CallPhase           phase;
  final CallModel?          call;
  final List<CallParticipant> participants;
  final bool                myAudioMuted;
  final bool                myVideoMuted;
  final bool                speakerOn;
  final bool                frontCamera;
  final int                 elapsedSeconds;
  final String?             error;
  final bool                waliJoined;

  bool get isActive    => phase == CallPhase.active;
  bool get isRinging   => phase == CallPhase.ringing;
  bool get inProgress  => phase == CallPhase.active ||
                          phase == CallPhase.ringing ||
                          phase == CallPhase.connecting;

  String get elapsedFormatted {
    final m = elapsedSeconds ~/ 60;
    final s = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  CallState copyWith({
    CallPhase?            phase,
    CallModel?            call,
    List<CallParticipant>? participants,
    bool?                 myAudioMuted,
    bool?                 myVideoMuted,
    bool?                 speakerOn,
    bool?                 frontCamera,
    int?                  elapsedSeconds,
    String?               error,
    bool?                 waliJoined,
    bool                  clearError = false,
    bool                  clearCall  = false,
  }) => CallState(
    phase:          phase          ?? this.phase,
    call:           clearCall ? null : (call ?? this.call),
    participants:   participants   ?? this.participants,
    myAudioMuted:   myAudioMuted   ?? this.myAudioMuted,
    myVideoMuted:   myVideoMuted   ?? this.myVideoMuted,
    speakerOn:      speakerOn      ?? this.speakerOn,
    frontCamera:    frontCamera    ?? this.frontCamera,
    elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    error:          clearError ? null : (error ?? this.error),
    waliJoined:     waliJoined     ?? this.waliJoined,
  );
}

// ─────────────────────────────────────────────
// CALL NOTIFIER
// ─────────────────────────────────────────────

class CallNotifier extends StateNotifier<CallState> {
  CallNotifier(this._repo) : super(const CallState()) {
    _engine = AgoraEngine()
      ..onUserJoined = _handleRemoteUserJoined
      ..onUserLeft   = onRemoteUserLeft;
  }

  void _handleRemoteUserJoined(int uid) {
    // Map Agora UID to role name
    final role = switch (uid) {
      CallParticipant.uidInitiator => 'initiator',
      CallParticipant.uidReceiver  => 'receiver',
      CallParticipant.uidWali      => 'wali',
      _                            => 'unknown',
    };
    onRemoteUserJoined(uid, role, role);
  }

  final CallRepository    _repo;
  late AgoraEngineInterface _engine;
  Timer? _elapsedTimer;
  Timer? _ringTimeout;

  // ── Initiate ─────────────────────────────────────────────────────────────
  Future<CallModel?> initiateCall({
    required String matchId,
    required String myName,
    required String otherName,
    CallType callType    = CallType.videoChaperoned,
    bool     inviteWali  = true,
    DateTime? scheduledAt,
  }) async {
    state = state.copyWith(phase: CallPhase.initiating, clearError: true);

    final result = await _repo.initiateCall(
      InitiateCallRequest(
        matchId:     matchId,
        callType:    callType.value,
        inviteWali:  inviteWali,
        scheduledAt: scheduledAt,
      ),
    );

    return switch (result) {
      ApiSuccess(data: final call) => () async {
          // Build participant list with initiator pre-populated
          final participants = [
            CallParticipant(
              uid:  CallParticipant.uidInitiator,
              name: myName,
              role: 'initiator',
            ),
          ];

          state = state.copyWith(
            phase:        CallPhase.ringing,
            call:         call,
            participants: participants,
          );

          // Ring timeout — if no answer in 45s, auto-end
          _ringTimeout = Timer(const Duration(seconds: 45), () {
            if (state.phase == CallPhase.ringing) {
              endCall(reason: 'timeout');
            }
          });

          // If we have a token, join the Agora channel
          if (call.token != null) {
            await _joinAgoraChannel(call, myName, isPublisher: true);
          }

          return call;
        }(),
      ApiError(error: final e) => () {
          state = state.copyWith(phase: CallPhase.failed, error: e.message);
          return null;
        }(),
    };
  }

  // ── Accept incoming call ──────────────────────────────────────────────────
  Future<void> acceptCall({
    required String callId,
    required String myName,
    required String participantType,
  }) async {
    state = state.copyWith(phase: CallPhase.connecting, clearError: true);
    _ringTimeout?.cancel();

    final result = await _repo.joinCall(callId, participantType);

    return switch (result) {
      ApiSuccess(data: final call) => () async {
          final isPublisher = participantType != 'wali';

          final participants = List<CallParticipant>.from(state.participants)
            ..add(CallParticipant(
              uid:  participantType == 'wali'
                  ? CallParticipant.uidWali
                  : CallParticipant.uidReceiver,
              name: myName,
              role: participantType,
            ));

          state = state.copyWith(
            phase:        CallPhase.active,
            call:         call,
            participants: participants,
          );

          await _joinAgoraChannel(call, myName, isPublisher: isPublisher);
          _startElapsedTimer();
        }(),
      ApiError(error: final e) => () {
          state = state.copyWith(phase: CallPhase.failed, error: e.message);
        }(),
    };
  }

  // ── Decline incoming call ─────────────────────────────────────────────────
  Future<void> declineCall(String callId) async {
    _ringTimeout?.cancel();
    await _repo.endCall(callId, reason: 'declined');
    state = const CallState(phase: CallPhase.ended);
  }

  // ── End call ─────────────────────────────────────────────────────────────
  Future<void> endCall({String? reason}) async {
    final callId = state.call?.id;
    if (callId == null) return;

    _ringTimeout?.cancel();
    _elapsedTimer?.cancel();
    state = state.copyWith(phase: CallPhase.ending);

    await _engine.leaveChannel();
    await _repo.endCall(callId, reason: reason ?? 'completed');

    state = state.copyWith(
      phase:          CallPhase.ended,
      elapsedSeconds: state.elapsedSeconds,
    );
  }

  // ── Media controls ────────────────────────────────────────────────────────
  Future<void> toggleAudio() async {
    final muted = !state.myAudioMuted;
    await _engine.muteLocalAudio(muted);
    state = state.copyWith(myAudioMuted: muted);
  }

  Future<void> toggleVideo() async {
    final muted = !state.myVideoMuted;
    await _engine.muteLocalVideo(muted);
    state = state.copyWith(myVideoMuted: muted);
  }

  Future<void> toggleSpeaker() async {
    final on = !state.speakerOn;
    await _engine.enableSpeakerphone(on);
    state = state.copyWith(speakerOn: on);
  }

  Future<void> flipCamera() async {
    await _engine.switchCamera();
    state = state.copyWith(frontCamera: !state.frontCamera);
  }

  // ── Simulated remote participant joined ───────────────────────────────────
  /// Called when the Agora SDK fires onUserJoined
  void onRemoteUserJoined(int uid, String name, String role) {
    final updated = List<CallParticipant>.from(state.participants);
    if (!updated.any((p) => p.uid == uid)) {
      updated.add(CallParticipant(uid: uid, name: name, role: role));
    }
    state = state.copyWith(
      participants: updated,
      waliJoined:   role == 'wali' ? true : state.waliJoined,
    );
    // If receiver joined, call is now truly active
    if (role == 'receiver' && state.phase == CallPhase.ringing) {
      _ringTimeout?.cancel();
      state = state.copyWith(phase: CallPhase.active);
      _startElapsedTimer();
    }
  }

  /// Called when the Agora SDK fires onUserOffline
  void onRemoteUserLeft(int uid) {
    final updated = state.participants.where((p) => p.uid != uid).toList();
    state = state.copyWith(participants: updated);
    // If only wali is left or no one → end call
    if (updated.length <= 1) endCall(reason: 'remote_left');
  }

  // ── Internals ─────────────────────────────────────────────────────────────
  Future<void> _joinAgoraChannel(
    CallModel call,
    String    myName, {
    required bool isPublisher,
  }) async {
    if (call.token == null) return;
    try {
      await _engine.initialize(call.token!.appId);
      await _engine.joinChannel(
        token:       call.token!.agoraToken,
        channelName: call.channelName,
        uid:         call.token!.uid,
        publishVideo:isPublisher && call.callType.isVideo,
      );
    } catch (e) {
      debugPrint('Agora join error: $e');
    }
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isActive) {
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
      }
    });
  }

  void resetAfterEnded() {
    state = const CallState(phase: CallPhase.idle);
  }

  @override
  void dispose() {
    _ringTimeout?.cancel();
    _elapsedTimer?.cancel();
    _engine.dispose();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final callProvider =
    StateNotifierProvider<CallNotifier, CallState>((ref) {
  return CallNotifier(ref.watch(callRepositoryProvider));
});

// Call history for a match
final callHistoryProvider =
    FutureProvider.family.autoDispose<List<CallModel>, String>((ref, matchId) async {
  final repo   = ref.watch(callRepositoryProvider);
  final result = await repo.getMatchHistory(matchId);
  return switch (result) {
    ApiSuccess(data: final calls) => calls,
    ApiError()                    => <CallModel>[],
  };
});
