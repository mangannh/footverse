import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/features/auth/models/forgot_password_request.dart';
import 'package:footverse/features/auth/models/password_reset_token_response.dart';
import 'package:footverse/features/auth/models/reset_password_request.dart';
import 'package:footverse/features/auth/models/verify_reset_otp_request.dart';
import 'package:footverse/features/auth/providers/password_reset_provider.dart';
import 'package:footverse/features/auth/repositories/auth_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'password_reset_provider_test.mocks.dart';

const ForgotPasswordRequest _forgotRequest = ForgotPasswordRequest(
  email: 'user@example.com',
);

const VerifyResetOtpRequest _verifyRequest = VerifyResetOtpRequest(
  email: 'user@example.com',
  otp: '123456',
);

const PasswordResetTokenResponse _verifiedToken = PasswordResetTokenResponse(
  resetToken: 'opaque-reset-token',
  expiresIn: 900,
);

const AppException _otpInvalid = AppException(
  message: 'Reset code is invalid',
  statusCode: 400,
  errorCode: 'PASSWORD_RESET_OTP_INVALID',
);

const AppException _tokenExpired = AppException(
  message: 'Reset token has expired',
  statusCode: 400,
  errorCode: 'PASSWORD_RESET_TOKEN_EXPIRED',
);

@GenerateNiceMocks([MockSpec<AuthRepository>()])
void main() {
  late MockAuthRepository repository;
  late PasswordResetProvider provider;

  setUp(() {
    repository = MockAuthRepository();
    provider = PasswordResetProvider(repository);
  });

  group('requestOtp', () {
    test('moves loading → success and sends the request', () async {
      final statuses = <PasswordResetStatus>[];
      provider.addListener(() => statuses.add(provider.status));
      when(repository.forgotPassword(any)).thenAnswer((_) async {});

      await provider.requestOtp(_forgotRequest);

      expect(statuses, <PasswordResetStatus>[
        PasswordResetStatus.loading,
        PasswordResetStatus.success,
      ]);
      final sent =
          verify(repository.forgotPassword(captureAny)).captured.single
              as ForgotPasswordRequest;
      expect(sent.email, 'user@example.com');
      expect(provider.error, isNull);
    });

    test('a second call while one is in flight is ignored', () async {
      final completer = Completer<void>();
      when(repository.forgotPassword(any)).thenAnswer((_) => completer.future);

      final first = provider.requestOtp(_forgotRequest);
      final second = provider.requestOtp(_forgotRequest);
      expect(provider.status, PasswordResetStatus.loading);

      completer.complete();
      await first;
      await second;

      verify(repository.forgotPassword(any)).called(1);
      expect(provider.status, PasswordResetStatus.success);
    });
  });

  group('verifyOtp', () {
    test('moves loading → success and captures the reset token', () async {
      final statuses = <PasswordResetStatus>[];
      provider.addListener(() => statuses.add(provider.status));
      when(
        repository.verifyResetOtp(any),
      ).thenAnswer((_) async => _verifiedToken);

      await provider.verifyOtp(_verifyRequest);

      expect(statuses, <PasswordResetStatus>[
        PasswordResetStatus.loading,
        PasswordResetStatus.success,
      ]);
      expect(provider.resetToken, 'opaque-reset-token');
      final sent =
          verify(repository.verifyResetOtp(captureAny)).captured.single
              as VerifyResetOtpRequest;
      expect(sent.email, 'user@example.com');
      expect(sent.otp, '123456');
    });

    test('a wrong code moves to error, rethrows, and keeps no token', () async {
      when(repository.verifyResetOtp(any)).thenThrow(_otpInvalid);

      await expectLater(
        provider.verifyOtp(_verifyRequest),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'PASSWORD_RESET_OTP_INVALID',
          ),
        ),
      );

      expect(provider.status, PasswordResetStatus.error);
      expect(provider.error, same(_otpInvalid));
      expect(provider.resetToken, isNull);
    });

    test('the flow is recoverable: a failed verify can be retried', () async {
      when(repository.verifyResetOtp(any)).thenThrow(_otpInvalid);
      await expectLater(
        provider.verifyOtp(_verifyRequest),
        throwsA(isA<AppException>()),
      );
      expect(provider.status, PasswordResetStatus.error);

      when(
        repository.verifyResetOtp(any),
      ).thenAnswer((_) async => _verifiedToken);
      await provider.verifyOtp(_verifyRequest);

      expect(provider.status, PasswordResetStatus.success);
      expect(provider.resetToken, 'opaque-reset-token');
    });

    test('a second call while one is in flight is ignored', () async {
      final completer = Completer<PasswordResetTokenResponse>();
      when(repository.verifyResetOtp(any)).thenAnswer((_) => completer.future);

      final first = provider.verifyOtp(_verifyRequest);
      final second = provider.verifyOtp(_verifyRequest);
      expect(provider.status, PasswordResetStatus.loading);

      completer.complete(_verifiedToken);
      await first;
      await second;

      verify(repository.verifyResetOtp(any)).called(1);
      expect(provider.status, PasswordResetStatus.success);
    });
  });

  group('resetPassword', () {
    Future<void> verifySuccessfully() async {
      when(
        repository.verifyResetOtp(any),
      ).thenAnswer((_) async => _verifiedToken);
      await provider.verifyOtp(_verifyRequest);
    }

    test(
      'moves loading → success and sends the token captured by verifyOtp',
      () async {
        await verifySuccessfully();
        final statuses = <PasswordResetStatus>[];
        provider.addListener(() => statuses.add(provider.status));
        when(repository.resetPassword(any)).thenAnswer((_) async {});

        await provider.resetPassword('NewPass123');

        expect(statuses, <PasswordResetStatus>[
          PasswordResetStatus.loading,
          PasswordResetStatus.success,
        ]);
        final sent =
            verify(repository.resetPassword(captureAny)).captured.single
                as ResetPasswordRequest;
        expect(sent.resetToken, 'opaque-reset-token');
        expect(sent.newPassword, 'NewPass123');
      },
    );

    test('throws StateError when called before a successful verifyOtp', () {
      expect(
        () => provider.resetPassword('NewPass123'),
        throwsA(isA<StateError>()),
      );
      verifyNever(repository.resetPassword(any));
    });

    test('an expired reset token moves to error, rethrows, and keeps the '
        'token so the flow is recoverable', () async {
      await verifySuccessfully();
      when(repository.resetPassword(any)).thenThrow(_tokenExpired);

      await expectLater(
        provider.resetPassword('NewPass123'),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'PASSWORD_RESET_TOKEN_EXPIRED',
          ),
        ),
      );

      expect(provider.status, PasswordResetStatus.error);
      expect(provider.error, same(_tokenExpired));
      // The token survives the failure — no earlier step needs to be
      // repeated to retry this step.
      expect(provider.resetToken, 'opaque-reset-token');
    });

    test('a second call while one is in flight is ignored', () async {
      await verifySuccessfully();
      final completer = Completer<void>();
      when(repository.resetPassword(any)).thenAnswer((_) => completer.future);

      final first = provider.resetPassword('NewPass123');
      final second = provider.resetPassword('NewPass123');
      expect(provider.status, PasswordResetStatus.loading);

      completer.complete();
      await first;
      await second;

      verify(repository.resetPassword(any)).called(1);
      expect(provider.status, PasswordResetStatus.success);
    });
  });
}
