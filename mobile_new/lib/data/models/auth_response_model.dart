import 'user_model.dart';

/// Model for authentication response from /auth/login and /auth/refresh
class AuthResponseModel {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final UserModel user;

  const AuthResponseModel({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return AuthResponseModel(
      accessToken: data['access_token'] as String,
      tokenType: data['token_type'] as String,
      expiresIn: data['expires_in'] as int,
      user: UserModel.fromLoginResponse(data['user'] as Map<String, dynamic>),
    );
  }

  /// Calculate token expiry DateTime
  DateTime get tokenExpiry => DateTime.now().add(Duration(seconds: expiresIn));
}
