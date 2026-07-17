import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/features/auth/models/role.dart';
import 'package:footverse/features/auth/models/user_response.dart';
import 'package:footverse/features/profile/models/change_email_request.dart';
import 'package:footverse/features/profile/models/change_password_request.dart';
import 'package:footverse/features/profile/models/update_profile_request.dart';
import 'package:footverse/features/profile/providers/profile_provider.dart';
import 'package:footverse/features/profile/repositories/profile_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'profile_provider_test.mocks.dart';

UserResponse _user({
  String fullName = 'Nguyen Van A',
  String phone = '0901234567',
}) => UserResponse(
  id: 1,
  email: 'user@example.com',
  fullName: fullName,
  phone: phone,
  role: Role.customer,
  enabled: true,
  createdAt: DateTime.parse('2025-01-15T10:30:00'),
  updatedAt: DateTime.parse('2025-01-16T08:00:00'),
);

const UpdateProfileRequest _request = UpdateProfileRequest(
  fullName: 'Nguyen Van B',
  phone: '0907654321',
);

const AppException _phoneConflict = AppException(
  message: 'Phone already in use',
  statusCode: 409,
  errorCode: 'USER_PHONE_DUPLICATED',
);

const ChangePasswordRequest _passwordRequest = ChangePasswordRequest(
  currentPassword: 'OldPass123',
  newPassword: 'NewPass123',
);

const ChangeEmailRequest _emailRequest = ChangeEmailRequest(
  newEmail: 'new@example.com',
  currentPassword: 'OldPass123',
);

const AppException _wrongPassword = AppException(
  message: 'Current password is incorrect',
  statusCode: 400,
  errorCode: 'USER_CURRENT_PASSWORD_INVALID',
);

const AppException _emailConflict = AppException(
  message: 'Email already in use',
  statusCode: 409,
  errorCode: 'USER_EMAIL_DUPLICATED',
);

const AppException _networkError = AppException.network(
  message: 'Unable to reach the server. Please check your connection.',
);

@GenerateNiceMocks([MockSpec<ProfileRepository>()])
void main() {
  late MockProfileRepository repository;
  late ProfileProvider provider;

  setUp(() {
    repository = MockProfileRepository();
    provider = ProfileProvider(repository);
  });

  group('load', () {
    test('moves loading → ready and exposes the fetched profile', () async {
      final statuses = <ProfileStatus>[];
      provider.addListener(() => statuses.add(provider.status));
      when(repository.getMe()).thenAnswer((_) async => _user());

      await provider.load();

      expect(statuses, <ProfileStatus>[
        ProfileStatus.loading,
        ProfileStatus.ready,
      ]);
      expect(provider.user?.email, 'user@example.com');
      expect(provider.user?.fullName, 'Nguyen Van A');
    });

    test('a failed load moves to error and preserves the exception', () async {
      when(repository.getMe()).thenThrow(_networkError);

      await provider.load();

      expect(provider.status, ProfileStatus.error);
      expect(provider.error, same(_networkError));
      expect(provider.user, isNull);
    });
  });

  group('retry', () {
    test('re-runs the load and recovers from an earlier error', () async {
      when(repository.getMe()).thenThrow(_networkError);
      await provider.load();
      expect(provider.status, ProfileStatus.error);

      when(repository.getMe()).thenAnswer((_) async => _user());
      await provider.retry();

      expect(provider.status, ProfileStatus.ready);
      expect(provider.user?.fullName, 'Nguyen Van A');
    });
  });

  group('updateProfile', () {
    test('replaces the held profile with the server response (no GET '
        'reload)', () async {
      when(repository.getMe()).thenAnswer((_) async => _user());
      await provider.load();

      final updated = _user(fullName: 'Nguyen Van B', phone: '0907654321');
      when(repository.updateProfile(any)).thenAnswer((_) async => updated);

      await provider.updateProfile(_request);

      final sent =
          verify(repository.updateProfile(captureAny)).captured.single
              as UpdateProfileRequest;
      expect(sent.fullName, 'Nguyen Van B');
      expect(sent.phone, '0907654321');
      // The held user is the server's returned response, and getMe ran only once
      // (the initial load) — the update never re-fetches.
      expect(provider.user?.fullName, 'Nguyen Van B');
      expect(provider.user?.phone, '0907654321');
      verify(repository.getMe()).called(1);
      expect(provider.isUpdating, isFalse);
    });

    test('rethrows a phone conflict and leaves the held profile '
        'unchanged', () async {
      when(repository.getMe()).thenAnswer((_) async => _user());
      await provider.load();
      when(repository.updateProfile(any)).thenThrow(_phoneConflict);

      await expectLater(
        provider.updateProfile(_request),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'USER_PHONE_DUPLICATED',
          ),
        ),
      );
      // The held profile is untouched on failure.
      expect(provider.user?.fullName, 'Nguyen Van A');
      expect(provider.user?.phone, '0901234567');
      expect(provider.isUpdating, isFalse);
    });
  });

  group('single-flight', () {
    test('a second update while one is in flight is ignored', () async {
      when(repository.getMe()).thenAnswer((_) async => _user());
      await provider.load();

      final completer = Completer<UserResponse>();
      when(repository.updateProfile(any)).thenAnswer((_) => completer.future);

      final first = provider.updateProfile(_request);
      final second = provider.updateProfile(_request);
      expect(provider.isUpdating, isTrue);

      completer.complete(_user(fullName: 'Nguyen Van B'));
      await first;
      await second;

      verify(repository.updateProfile(any)).called(1);
      expect(provider.isUpdating, isFalse);
      expect(provider.user?.fullName, 'Nguyen Van B');
    });
  });

  group('changePassword', () {
    test(
      'sends the request and clears the in-flight flag on success',
      () async {
        when(repository.changePassword(any)).thenAnswer((_) async {});

        await provider.changePassword(_passwordRequest);

        final sent =
            verify(repository.changePassword(captureAny)).captured.single
                as ChangePasswordRequest;
        expect(sent.currentPassword, 'OldPass123');
        expect(sent.newPassword, 'NewPass123');
        expect(provider.isUpdating, isFalse);
      },
    );

    test('rethrows a wrong-password 400 and changes no state', () async {
      when(repository.changePassword(any)).thenThrow(_wrongPassword);

      await expectLater(
        provider.changePassword(_passwordRequest),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'USER_CURRENT_PASSWORD_INVALID',
          ),
        ),
      );
      // A void write never sets the held profile, and the flag is released.
      expect(provider.user, isNull);
      expect(provider.isUpdating, isFalse);
    });

    test('a second change while one is in flight is ignored', () async {
      final completer = Completer<void>();
      when(repository.changePassword(any)).thenAnswer((_) => completer.future);

      final first = provider.changePassword(_passwordRequest);
      final second = provider.changePassword(_passwordRequest);
      expect(provider.isUpdating, isTrue);

      completer.complete();
      await first;
      await second;

      verify(repository.changePassword(any)).called(1);
      expect(provider.isUpdating, isFalse);
    });
  });

  group('changeEmail', () {
    test('replaces the held profile with the server response', () async {
      final updated = UserResponse(
        id: 1,
        email: 'new@example.com',
        fullName: 'Nguyen Van A',
        phone: '0901234567',
        role: Role.customer,
        enabled: true,
        createdAt: DateTime.parse('2025-01-15T10:30:00'),
        updatedAt: DateTime.parse('2025-01-17T09:00:00'),
      );
      when(repository.changeEmail(any)).thenAnswer((_) async => updated);

      await provider.changeEmail(_emailRequest);

      final sent =
          verify(repository.changeEmail(captureAny)).captured.single
              as ChangeEmailRequest;
      expect(sent.newEmail, 'new@example.com');
      expect(sent.currentPassword, 'OldPass123');
      expect(provider.user?.email, 'new@example.com');
      expect(provider.isUpdating, isFalse);
    });

    test('rethrows a duplicated-email 409 and leaves the held profile '
        'unchanged', () async {
      when(repository.getMe()).thenAnswer((_) async => _user());
      await provider.load();
      when(repository.changeEmail(any)).thenThrow(_emailConflict);

      await expectLater(
        provider.changeEmail(_emailRequest),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'USER_EMAIL_DUPLICATED',
          ),
        ),
      );
      // The held profile is untouched on failure.
      expect(provider.user?.email, 'user@example.com');
      expect(provider.isUpdating, isFalse);
    });

    test('a second change while one is in flight is ignored', () async {
      final completer = Completer<UserResponse>();
      when(repository.changeEmail(any)).thenAnswer((_) => completer.future);

      final first = provider.changeEmail(_emailRequest);
      final second = provider.changeEmail(_emailRequest);
      expect(provider.isUpdating, isTrue);

      completer.complete(_user());
      await first;
      await second;

      verify(repository.changeEmail(any)).called(1);
      expect(provider.isUpdating, isFalse);
    });
  });
}
