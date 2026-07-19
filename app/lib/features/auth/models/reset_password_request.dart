import 'package:json_annotation/json_annotation.dart';

part 'reset_password_request.g.dart';

/// Set a new password using a verified reset token (dto-spec §6).
@JsonSerializable(createFactory: false)
class ResetPasswordRequest {
  const ResetPasswordRequest({
    required this.resetToken,
    required this.newPassword,
  });

  final String resetToken;
  final String newPassword;

  Map<String, dynamic> toJson() => _$ResetPasswordRequestToJson(this);
}
