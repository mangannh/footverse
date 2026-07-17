import 'package:json_annotation/json_annotation.dart';

part 'update_profile_request.g.dart';

/// The write body for updating the caller's editable profile fields
/// (dto-spec §7).
///
/// [avatarUrl] is optional (dto-spec §7, `W, O`): omitted from the JSON when
/// unset, exactly as the Sprint 8 request models omit their optionals — the wire
/// body carries only what the caller provided. The server remains authoritative
/// on validation and phone uniqueness; this model only serializes the wire body.
@JsonSerializable(createFactory: false, includeIfNull: false)
class UpdateProfileRequest {
  const UpdateProfileRequest({
    required this.fullName,
    required this.phone,
    this.avatarUrl,
  });

  final String fullName;
  final String phone;
  final String? avatarUrl;

  Map<String, dynamic> toJson() => _$UpdateProfileRequestToJson(this);
}
