import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/core/router/app_routes.dart';
import 'package:footverse/features/auth/models/password_reset_token_response.dart';
import 'package:footverse/features/auth/models/verify_reset_otp_request.dart';
import 'package:footverse/features/auth/providers/password_reset_provider.dart';
import 'package:footverse/features/auth/repositories/auth_repository.dart';
import 'package:footverse/features/auth/screens/verify_reset_otp_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'verify_reset_otp_screen_test.mocks.dart';

const AppException _otpInvalid = AppException(
  message: 'Reset code is invalid',
  statusCode: 400,
  errorCode: 'PASSWORD_RESET_OTP_INVALID',
);

const PasswordResetTokenResponse _verifiedToken = PasswordResetTokenResponse(
  resetToken: 'opaque-reset-token',
  expiresIn: 900,
);

GoRouter _router(PasswordResetProvider provider) => GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) =>
          VerifyResetOtpScreen(provider: provider, email: 'user@example.com'),
      routes: <RouteBase>[
        GoRoute(
          path: 'reset',
          name: AppRoute.resetPassword,
          builder: (context, state) =>
              const Scaffold(body: Text('reset-password-placeholder')),
        ),
      ],
    ),
    GoRoute(
      path: '/forgot-password',
      name: AppRoute.forgotPassword,
      builder: (context, state) =>
          const Scaffold(body: Text('forgot-password-placeholder')),
    ),
  ],
);

@GenerateNiceMocks([MockSpec<AuthRepository>()])
void main() {
  testWidgets('a five-digit code is blocked client-side; nothing is sent', (
    tester,
  ) async {
    final authRepository = MockAuthRepository();
    final provider = PasswordResetProvider(authRepository);
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router(provider)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '12345');
    await tester.tap(find.widgetWithText(FilledButton, 'Verify'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the 6-digit reset code'), findsOneWidget);
    verifyNever(authRepository.verifyResetOtp(any));
  });

  testWidgets(
    'a server rejection is rendered without navigating away or clearing '
    'input',
    (tester) async {
      final authRepository = MockAuthRepository();
      when(authRepository.verifyResetOtp(any)).thenThrow(_otpInvalid);
      final provider = PasswordResetProvider(authRepository);
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: _router(provider)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.widgetWithText(FilledButton, 'Verify'));
      await tester.pumpAndSettle();

      expect(find.text('Reset code is invalid'), findsOneWidget);
      expect(find.text('123456'), findsOneWidget);
      expect(find.byType(VerifyResetOtpScreen), findsOneWidget);
      expect(find.text('reset-password-placeholder'), findsNothing);
    },
  );

  testWidgets('a correct code verifies and moves to step three', (
    tester,
  ) async {
    final authRepository = MockAuthRepository();
    when(
      authRepository.verifyResetOtp(any),
    ).thenAnswer((_) async => _verifiedToken);
    final provider = PasswordResetProvider(authRepository);
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router(provider)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Verify'));
    await tester.pumpAndSettle();

    final sent =
        verify(authRepository.verifyResetOtp(captureAny)).captured.single
            as VerifyResetOtpRequest;
    expect(sent.email, 'user@example.com');
    expect(sent.otp, '123456');
    expect(provider.resetToken, 'opaque-reset-token');
    expect(find.text('reset-password-placeholder'), findsOneWidget);
  });

  testWidgets('resend code returns to step one, not a new OTP send', (
    tester,
  ) async {
    final authRepository = MockAuthRepository();
    final provider = PasswordResetProvider(authRepository);
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router(provider)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Resend code'));
    await tester.pumpAndSettle();

    expect(find.text('forgot-password-placeholder'), findsOneWidget);
    verifyNever(authRepository.forgotPassword(any));
  });
}
