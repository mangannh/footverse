import 'package:json_annotation/json_annotation.dart';

part 'change_password_request.g.dart';

/// The write body for changing the caller's password (dto-spec §7).
///
/// The change is re-authenticated with [currentPassword]; the server verifies it
/// (a wrong value is `400 USER_CURRENT_PASSWORD_INVALID`) — this model only
/// serializes the wire body and never logs or stores a raw password.
@JsonSerializable(createFactory: false)
class ChangePasswordRequest {
  const ChangePasswordRequest({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;

  Map<String, dynamic> toJson() => _$ChangePasswordRequestToJson(this);
}
