/// MiskMatch — Auth Domain Models

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.tokenType,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final String tokenType;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken:  json['access_token']  as String,
    refreshToken: json['refresh_token'] as String,
    userId:       json['user_id']       as String,
    tokenType:    json['token_type']    as String? ?? 'bearer',
  );
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.phone,
    required this.role,
    required this.status,
    required this.gender,
    required this.subscriptionTier,
    required this.onboardingCompleted,
    this.email,
    this.niyyah,
  });

  final String  id;
  final String  phone;
  final String? email;
  final String  role;
  final String  status;
  final String  gender;
  final String  subscriptionTier;
  final bool    onboardingCompleted;
  final String? niyyah;

  bool get isMale   => gender == 'male';
  bool get isFemale => gender == 'female';
  bool get isActive => status == 'active';
  bool get isPremium=> subscriptionTier != 'barakah';
  bool get isWali   => role == 'wali';

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id:                  json['id']                   as String,
    phone:               json['phone']                as String,
    email:               json['email']                as String?,
    role:                json['role']                 as String,
    status:              json['status']               as String,
    gender:              json['gender']               as String,
    subscriptionTier:    json['subscription_tier']    as String,
    onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
    niyyah:              json['niyyah']               as String?,
  );
}

class RegisterRequest {
  const RegisterRequest({
    required this.phone,
    required this.password,
    required this.gender,
    this.email,
    this.niyyah,
    this.referralCode,
  });

  final String  phone;
  final String  password;
  final String  gender;
  final String? email;
  final String? niyyah;
  final String? referralCode;

  Map<String, dynamic> toJson() => {
    'phone':    phone,
    'password': password,
    'gender':   gender,
    if (email        != null) 'email':        email,
    if (niyyah       != null) 'niyyah':       niyyah,
    if (referralCode != null) 'referral_code':referralCode,
  };
}

class LoginRequest {
  const LoginRequest({
    required this.phone,
    required this.password,
  });

  final String phone;
  final String password;

  Map<String, dynamic> toJson() => {
    'phone':    phone,
    'password': password,
  };
}

class OtpVerifyRequest {
  const OtpVerifyRequest({
    required this.phone,
    required this.otp,
  });

  final String phone;
  final String otp;

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'otp':   otp,
  };
}
