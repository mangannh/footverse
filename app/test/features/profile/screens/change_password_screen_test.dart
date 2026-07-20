import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/features/profile/repositories/profile_repository.dart';
import 'package:footverse/features/profile/screens/change_password_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'change_password_screen_test.mocks.dart';

GoRouter _router(ProfileRepository profileRepository) => GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(body: Text('profile screen')),
      routes: <RouteBase>[
        GoRoute(
          path: 'password',
          builder: (context, state) =>
              ChangePasswordScreen(profileRepository: profileRepository),
        ),
      ],
    ),
  ],
);

Future<void> _pumpScreen(
  WidgetTester tester,
  MockProfileRepository profileRepository,
) async {
  final router = _router(profileRepository);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  router.push('/password');
  await tester.pumpAndSettle();
}

@GenerateNiceMocks([MockSpec<ProfileRepository>()])
void main() {
  late MockProfileRepository profileRepository;

  setUp(() {
    profileRepository = MockProfileRepository();
  });

  testWidgets(
    'blank fields are blocked client-side by the existing validators; '
    'nothing is sent',
    (tester) async {
      await _pumpScreen(tester, profileRepository);

      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pumpAndSettle();

      expect(find.text('Password is required'), findsWidgets);
      verifyNever(profileRepository.changePassword(any));
    },
  );

  testWidgets(
    'a server rejection shows a form-level message above the button — '
    'never a Snackbar',
    (tester) async {
      when(
        profileRepository.changePassword(any),
      ).thenThrow(const AppException(message: 'Current password is wrong'));

      await _pumpScreen(tester, profileRepository);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Current password'),
        'wrong-password',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'NewPass123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pumpAndSettle();

      expect(find.text('Current password is wrong'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      // Still on this screen — a rejection never pops.
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    },
  );

  testWidgets(
    'a successful change pops back returning true, with the in-button '
    'spinner shown meanwhile',
    (tester) async {
      final completer = Completer<void>();
      when(
        profileRepository.changePassword(any),
      ).thenAnswer((_) => completer.future);

      await _pumpScreen(tester, profileRepository);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Current password'),
        'CurrentPass1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'NewPass123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.text('profile screen'), findsOneWidget);
      verify(profileRepository.changePassword(any)).called(1);
    },
  );
}
