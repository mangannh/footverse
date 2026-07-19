import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/core/router/app_routes.dart';
import 'package:footverse/features/auth/models/password_reset_token_response.dart';
import 'package:footverse/features/auth/models/reset_password_request.dart';
import 'package:footverse/features/auth/models/verify_reset_otp_request.dart';
import 'package:footverse/features/auth/providers/password_reset_provider.dart';
import 'package:footverse/features/auth/repositories/auth_repository.dart';
import 'package:footverse/features/auth/screens/reset_password_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'reset_password_screen_test.mocks.dart';

const AppException _tokenExpired = AppException(
  message: 'Reset token has expired',
  statusCode: 400,
  errorCode: 'PASSWORD_RESET_TOKEN_EXPIRED',
);

const PasswordResetTokenResponse _verifiedToken = PasswordResetTokenResponse(
  resetToken: 'opaque-reset-token',
  expiresIn: 900,
);

/// A [PasswordResetProvider] with an already-captured reset token, mirroring
/// what a real flow leaves behind after a successful step two.
Future<PasswordResetProvider> _verifiedProvider(
  MockAuthRepository authRepository,
) async {
  when(
    authRepository.verifyResetOtp(any),
  ).thenAnswer((_) async => _verifiedToken);
  final provider = PasswordResetProvider(authRepository);
  await provider.verifyOtp(
    const VerifyResetOtpRequest(email: 'user@example.com', otp: '123456'),
  );
  return provider;
}

GoRouter _router(PasswordResetProvider provider) => GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) =>
          ResetPasswordScreen(provider: provider, email: 'user@example.com'),
    ),
    GoRoute(
      path: '/login',
      name: AppRoute.login,
      builder: (context, state) =>
          Scaffold(body: Text('login-placeholder:${state.extra}')),
    ),
  ],
);

@GenerateNiceMocks([MockSpec<AuthRepository>()])
void main() {
  testWidgets('a weak password is blocked client-side; nothing is sent', (
    tester,
  ) async {
    final authRepository = MockAuthRepository();
    final provider = await _verifiedProvider(authRepository);
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router(provider)),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'short');
    await tester.enterText(fields.at(1), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Reset password'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Password must be at least 8 characters and include a letter '
        'and a number',
      ),
      findsOneWidget,
    );
    verifyNever(authRepository.resetPassword(any));
  });

  testWidgets(
    'a mismatched confirmation is blocked client-side; nothing is sent',
    (tester) async {
      final authRepository = MockAuthRepository();
      final provider = await _verifiedProvider(authRepository);
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: _router(provider)),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'NewPass123');
      await tester.enterText(fields.at(1), 'Different123');
      await tester.tap(find.widgetWithText(FilledButton, 'Reset password'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
      verifyNever(authRepository.resetPassword(any));
    },
  );

  testWidgets(
    'a server rejection is rendered without navigating away or clearing '
    'input',
    (tester) async {
      final authRepository = MockAuthRepository();
      when(authRepository.resetPassword(any)).thenThrow(_tokenExpired);
      final provider = await _verifiedProvider(authRepository);
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: _router(provider)),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'NewPass123');
      await tester.enterText(fields.at(1), 'NewPass123');
      await tester.tap(find.widgetWithText(FilledButton, 'Reset password'));
      await tester.pumpAndSettle();

      expect(find.text('Reset token has expired'), findsOneWidget);
      expect(find.text('NewPass123'), findsWidgets);
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.textContaining('login-placeholder'), findsNothing);
    },
  );

  testWidgets(
    'a matching strong password resets, then returns to login with the '
    'email carried forward',
    (tester) async {
      final authRepository = MockAuthRepository();
      when(authRepository.resetPassword(any)).thenAnswer((_) async {});
      final provider = await _verifiedProvider(authRepository);
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: _router(provider)),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'NewPass123');
      await tester.enterText(fields.at(1), 'NewPass123');
      await tester.tap(find.widgetWithText(FilledButton, 'Reset password'));
      await tester.pumpAndSettle();

      final sent =
          verify(authRepository.resetPassword(captureAny)).captured.single
              as ResetPasswordRequest;
      expect(sent.resetToken, 'opaque-reset-token');
      expect(sent.newPassword, 'NewPass123');
      expect(find.text('login-placeholder:user@example.com'), findsOneWidget);
    },
  );

  testWidgets('the visibility toggles reveal and hide each password field', (
    tester,
  ) async {
    final authRepository = MockAuthRepository();
    final provider = await _verifiedProvider(authRepository);
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router(provider)),
    );
    await tester.pumpAndSettle();

    final editableFields = find.byType(EditableText);
    bool obscuredAt(int index) =>
        tester.widget<EditableText>(editableFields.at(index)).obscureText;
    expect(obscuredAt(0), isTrue);
    expect(obscuredAt(1), isTrue);

    final toggles = find.byIcon(Icons.visibility);
    await tester.tap(toggles.first);
    await tester.pump();

    expect(obscuredAt(0), isFalse);
    expect(obscuredAt(1), isTrue);
  });
}
