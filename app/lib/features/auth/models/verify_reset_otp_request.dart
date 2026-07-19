import 'package:json_annotation/json_annotation.dart';

part 'verify_reset_otp_request.g.dart';

/// Verify an emailed one-time code and request a short-lived reset token
/// (dto-spec §6).
@JsonSerializable(createFactory: false)
class VerifyResetOtpRequest {
  const VerifyResetOtpRequest({required this.email, required this.otp});

  final String email;
  final String otp;

  Map<String, dynamic> toJson() => _$VerifyResetOtpRequestToJson(this);
}
