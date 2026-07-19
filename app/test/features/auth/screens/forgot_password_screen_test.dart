import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/core/router/app_routes.dart';
import 'package:footverse/features/auth/models/forgot_password_request.dart';
import 'package:footverse/features/auth/repositories/auth_repository.dart';
import 'package:footverse/features/auth/screens/forgot_password_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'forgot_password_screen_test.mocks.dart';

const AppException _serverError = AppException(
  message: 'Something went wrong. Please try again later.',
  statusCode: 500,
);

GoRouter _router(AuthRepository authRepository) => GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) =>
          ForgotPasswordScreen(authRepository: authRepository),
      routes: <RouteBase>[
        GoRoute(
          path: 'verify',
          name: AppRoute.verifyResetOtp,
          builder: (context, state) =>
              const Scaffold(body: Text('verify-otp-placeholder')),
        ),
      ],
    ),
  ],
);

@GenerateNiceMocks([MockSpec<AuthRepository>()])
void main() {
  testWidgets('an invalid email is blocked client-side; nothing is sent', (
    tester,
  ) async {
    final authRepository = MockAuthRepository();
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router(authRepository)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    verifyNever(authRepository.forgotPassword(any));
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
  });

  testWidgets(
    'a server error is rendered without navigating away or clearing input',
    (tester) async {
      final authRepository = MockAuthRepository();
      when(authRepository.forgotPassword(any)).thenThrow(_serverError);
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: _router(authRepository)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Please try again later.'),
        findsOneWidget,
      );
      expect(find.text('user@example.com'), findsOneWidget);
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(find.text('verify-otp-placeholder'), findsNothing);
    },
  );

  testWidgets('a valid email requests the code and moves to step two', (
    tester,
  ) async {
    final authRepository = MockAuthRepository();
    when(authRepository.forgotPassword(any)).thenAnswer((_) async {});
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router(authRepository)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
    await tester.pumpAndSettle();

    final sent =
        verify(authRepository.forgotPassword(captureAny)).captured.single
            as ForgotPasswordRequest;
    expect(sent.email, 'user@example.com');
    expect(find.text('verify-otp-placeholder'), findsOneWidget);
  });
}
