import 'package:json_annotation/json_annotation.dart';

part 'password_reset_token_response.g.dart';

/// Result of a successful OTP verification (dto-spec §6).
@JsonSerializable(createToJson: false)
class PasswordResetTokenResponse {
  const PasswordResetTokenResponse({
    required this.resetToken,
    required this.expiresIn,
  });

  factory PasswordResetTokenResponse.fromJson(Map<String, dynamic> json) =>
      _$PasswordResetTokenResponseFromJson(json);

  final String resetToken;
  final int expiresIn;
}
