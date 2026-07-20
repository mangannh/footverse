import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/features/auth/models/role.dart';
import 'package:footverse/features/auth/models/user_response.dart';
import 'package:footverse/features/profile/repositories/profile_repository.dart';
import 'package:footverse/features/profile/screens/change_email_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'change_email_screen_test.mocks.dart';

UserResponse _user() => UserResponse(
  id: 1,
  email: 'new@example.com',
  fullName: 'Jane Doe',
  phone: '0901234567',
  role: Role.customer,
  enabled: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

GoRouter _router(ProfileRepository profileRepository) => GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(body: Text('profile screen')),
      routes: <RouteBase>[
        GoRoute(
          path: 'email',
          builder: (context, state) =>
              ChangeEmailScreen(profileRepository: profileRepository),
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
  router.push('/email');
  await tester.pumpAndSettle();
}

@GenerateNiceMocks([MockSpec<ProfileRepository>()])
void main() {
  late MockProfileRepository profileRepository;

  setUp(() {
    profileRepository = MockProfileRepository();
  });

  testWidgets(
    'an invalid email is blocked client-side by the existing validator; '
    'nothing is sent',
    (tester) async {
      await _pumpScreen(tester, profileRepository);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'New email'),
        'not-an-email',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Current password'),
        'CurrentPass1',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Change email'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      verifyNever(profileRepository.changeEmail(any));
    },
  );

  testWidgets(
    'a duplicate-email rejection shows a form-level message above the '
    'button — never a Snackbar',
    (tester) async {
      when(
        profileRepository.changeEmail(any),
      ).thenThrow(const AppException(message: 'That email is already used'));

      await _pumpScreen(tester, profileRepository);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'New email'),
        'taken@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Current password'),
        'CurrentPass1',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Change email'));
      await tester.pumpAndSettle();

      expect(find.text('That email is already used'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(ChangeEmailScreen), findsOneWidget);
    },
  );

  testWidgets(
    'a successful change pops back returning true, with the in-button '
    'spinner shown meanwhile',
    (tester) async {
      final completer = Completer<UserResponse>();
      when(
        profileRepository.changeEmail(any),
      ).thenAnswer((_) => completer.future);

      await _pumpScreen(tester, profileRepository);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'New email'),
        'new@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Current password'),
        'CurrentPass1',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Change email'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(_user());
      await tester.pumpAndSettle();

      expect(find.text('profile screen'), findsOneWidget);
      verify(profileRepository.changeEmail(any)).called(1);
    },
  );
}
