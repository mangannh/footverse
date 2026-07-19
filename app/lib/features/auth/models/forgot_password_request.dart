import 'package:json_annotation/json_annotation.dart';

part 'forgot_password_request.g.dart';

/// Request a password-reset one-time code by email (dto-spec §6).
@JsonSerializable(createFactory: false)
class ForgotPasswordRequest {
  const ForgotPasswordRequest({required this.email});

  final String email;

  Map<String, dynamic> toJson() => _$ForgotPasswordRequestToJson(this);
}
