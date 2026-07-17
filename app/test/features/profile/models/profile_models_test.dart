import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/features/profile/models/change_email_request.dart';
import 'package:footverse/features/profile/models/change_password_request.dart';
import 'package:footverse/features/profile/models/update_profile_request.dart';

void main() {
  group('UpdateProfileRequest (dto-spec §7)', () {
    test('serializes every write field', () {
      const request = UpdateProfileRequest(
        fullName: 'Nguyen Van A',
        phone: '0901234567',
        avatarUrl: 'https://cdn.example.com/a.jpg',
      );

      expect(request.toJson(), <String, dynamic>{
        'fullName': 'Nguyen Van A',
        'phone': '0901234567',
        'avatarUrl': 'https://cdn.example.com/a.jpg',
      });
    });

    test('omits the optional avatarUrl when it is not set', () {
      const request = UpdateProfileRequest(
        fullName: 'Nguyen Van A',
        phone: '0901234567',
      );

      final json = request.toJson();
      expect(json.containsKey('avatarUrl'), isFalse);
      expect(json, <String, dynamic>{
        'fullName': 'Nguyen Van A',
        'phone': '0901234567',
      });
    });
  });

  group('ChangePasswordRequest (dto-spec §7)', () {
    test('serializes the current and new password', () {
      const request = ChangePasswordRequest(
        currentPassword: 'oldPass1',
        newPassword: 'newPass2',
      );

      expect(request.toJson(), <String, dynamic>{
        'currentPassword': 'oldPass1',
        'newPassword': 'newPass2',
      });
    });
  });

  group('ChangeEmailRequest (dto-spec §7)', () {
    test('serializes the new email and the current password', () {
      const request = ChangeEmailRequest(
        newEmail: 'new@example.com',
        currentPassword: 'oldPass1',
      );

      expect(request.toJson(), <String, dynamic>{
        'newEmail': 'new@example.com',
        'currentPassword': 'oldPass1',
      });
    });
  });
}
