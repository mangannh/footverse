import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/core/router/app_routes.dart';
import 'package:footverse/core/theme/app_motion.dart';
import 'package:footverse/core/theme/app_theme.dart';
import 'package:footverse/core/widgets/app_error_state.dart';
import 'package:footverse/core/widgets/app_skeleton.dart';
import 'package:footverse/core/widgets/section_header.dart';
import 'package:footverse/features/auth/models/role.dart';
import 'package:footverse/features/auth/models/user_response.dart';
import 'package:footverse/features/profile/repositories/profile_repository.dart';
import 'package:footverse/features/profile/screens/change_email_screen.dart';
import 'package:footverse/features/profile/screens/change_password_screen.dart';
import 'package:footverse/features/profile/screens/profile_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'profile_screen_test.mocks.dart';

UserResponse _user({String fullName = 'Jane Doe'}) => UserResponse(
  id: 1,
  email: 'jane@example.com',
  fullName: fullName,
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
      builder: (context, state) => Scaffold(
        body: TextButton(onPressed: () {}, child: const Text('home')),
      ),
      routes: <RouteBase>[
        GoRoute(
          path: 'profile',
          name: AppRoute.profile,
          builder: (context, state) =>
              ProfileScreen(profileRepository: profileRepository),
          routes: <RouteBase>[
            GoRoute(
              path: 'password',
              name: AppRoute.changePassword,
              builder: (context, state) =>
                  ChangePasswordScreen(profileRepository: profileRepository),
            ),
            GoRoute(
              path: 'email',
              name: AppRoute.changeEmail,
              builder: (context, state) =>
                  ChangeEmailScreen(profileRepository: profileRepository),
            ),
          ],
        ),
      ],
    ),
  ],
);

Future<void> _pumpScreen(
  WidgetTester tester,
  MockProfileRepository profileRepository,
) async {
  await tester.binding.setSurfaceSize(const Size(600, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final router = _router(profileRepository);
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
  router.pushNamed(AppRoute.profile);
  await tester.pumpAndSettle();
}

@GenerateNiceMocks([MockSpec<ProfileRepository>()])
void main() {
  late MockProfileRepository profileRepository;

  setUp(() {
    profileRepository = MockProfileRepository();
  });

  testWidgets('uses SectionHeader to group Account / Edit profile / Security', (
    tester,
  ) async {
    when(profileRepository.getMe()).thenAnswer((_) async => _user());

    await _pumpScreen(tester, profileRepository);

    expect(find.byType(SectionHeader), findsNWidgets(3));
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
  });

  testWidgets('shows the read-only identity — email is not an editable field', (
    tester,
  ) async {
    when(profileRepository.getMe()).thenAnswer((_) async => _user());

    await _pumpScreen(tester, profileRepository);

    expect(find.text('jane@example.com'), findsOneWidget);
    // Only three editable fields exist (full name, phone, avatar URL); no
    // TextFormField carries the email value.
    final emailFields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .where((field) => field.controller?.text == 'jane@example.com');
    expect(emailFields, isEmpty);
  });

  testWidgets(
    'shows a skeleton while the profile loads — never a centred spinner',
    (tester) async {
      final completer = Completer<UserResponse>();
      when(profileRepository.getMe()).thenAnswer((_) => completer.future);

      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = _router(profileRepository);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      router.pushNamed(AppRoute.profile);
      await tester.pump();
      await tester.pump();
      await tester.pump(AppMotion.short);
      await tester.pump();

      expect(find.byType(ListTileSkeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      completer.complete(_user());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('shows AppErrorState on a failed load, with a working retry', (
    tester,
  ) async {
    var callCount = 0;
    when(profileRepository.getMe()).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) {
        throw const AppException(message: 'Something broke');
      }
      return _user();
    });

    await _pumpScreen(tester, profileRepository);

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.text('Something broke'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorState), findsNothing);
    expect(find.text('Jane Doe'), findsWidgets);
  });

  testWidgets(
    'opening Change email and returning true refreshes the identity',
    (tester) async {
      // The server is the single source of truth for the current email:
      // this fixture tracks it across both `getMe` (the profile screen's own
      // reload) and `changeEmail` (the credential screen's write), exactly
      // as a real backend would.
      var currentEmail = 'jane@example.com';
      when(profileRepository.getMe()).thenAnswer(
        (_) async => UserResponse(
          id: 1,
          email: currentEmail,
          fullName: 'Jane Doe',
          phone: '0901234567',
          role: Role.customer,
          enabled: true,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
      when(profileRepository.changeEmail(any)).thenAnswer((_) async {
        currentEmail = 'new@example.com';
        return UserResponse(
          id: 1,
          email: currentEmail,
          fullName: 'Jane Doe',
          phone: '0901234567',
          role: Role.customer,
          enabled: true,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
      });

      await _pumpScreen(tester, profileRepository);

      await tester.tap(find.widgetWithText(ListTile, 'Change email'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'New email'),
        'new@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Current password'),
        'CurrentPass1!',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Change email'));
      await tester.pumpAndSettle();

      expect(find.text('jane@example.com'), findsNothing);
      expect(find.text('new@example.com'), findsOneWidget);
    },
  );
}
