import 'package:json_annotation/json_annotation.dart';

part 'change_email_request.g.dart';

/// The write body for changing the caller's email (dto-spec §7).
///
/// The change is re-authenticated with [currentPassword]; the server verifies it
/// and enforces email uniqueness (a taken email is `409 USER_EMAIL_DUPLICATED`) —
/// this model only serializes the wire body and never logs or stores a raw
/// password.
@JsonSerializable(createFactory: false)
class ChangeEmailRequest {
  const ChangeEmailRequest({
    required this.newEmail,
    required this.currentPassword,
  });

  final String newEmail;
  final String currentPassword;

  Map<String, dynamic> toJson() => _$ChangeEmailRequestToJson(this);
}
