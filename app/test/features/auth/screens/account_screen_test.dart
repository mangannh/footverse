import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/core/storage/token_storage.dart';
import 'package:footverse/core/theme/app_motion.dart';
import 'package:footverse/core/theme/app_theme.dart';
import 'package:footverse/core/widgets/app_empty_state.dart';
import 'package:footverse/core/widgets/app_skeleton.dart';
import 'package:footverse/features/auth/models/refresh_token_request.dart';
import 'package:footverse/features/auth/providers/auth_provider.dart';
import 'package:footverse/features/auth/repositories/auth_repository.dart';
import 'package:footverse/features/auth/screens/account_screen.dart';
import 'package:footverse/features/auth/models/role.dart';
import 'package:footverse/features/auth/models/user_response.dart';
import 'package:footverse/features/profile/repositories/profile_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_screen_test.mocks.dart';

UserResponse _user() => UserResponse(
  id: 1,
  email: 'jane@example.com',
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
      path: '/account',
      name: 'account',
      builder: (context, state) =>
          AccountScreen(profileRepository: profileRepository),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const Scaffold(body: Text('LOGIN SCREEN')),
    ),
    GoRoute(
      path: '/addresses',
      name: 'addresses',
      builder: (context, state) =>
          const Scaffold(body: Text('ADDRESSES SCREEN')),
    ),
    GoRoute(
      path: '/wishlist',
      name: 'wishlist',
      builder: (context, state) =>
          const Scaffold(body: Text('WISHLIST SCREEN')),
    ),
    GoRoute(
      path: '/orders',
      name: 'orders',
      builder: (context, state) => const Scaffold(body: Text('ORDERS SCREEN')),
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const Scaffold(body: Text('PROFILE SCREEN')),
    ),
  ],
  initialLocation: '/account',
);

Future<AuthProvider> _authProvider({required bool signedIn}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final tokenStorage = TokenStorage(await SharedPreferences.getInstance());
  if (signedIn) {
    await tokenStorage.saveTokens('access', 'refresh');
  }
  final authProvider = AuthProvider(MockAuthRepository(), tokenStorage);
  authProvider.restoreSession();
  return authProvider;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  AuthProvider authProvider,
  MockProfileRepository profileRepository,
) async {
  await tester.binding.setSurfaceSize(const Size(600, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router(profileRepository),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

@GenerateNiceMocks([MockSpec<AuthRepository>(), MockSpec<ProfileRepository>()])
void main() {
  testWidgets('a signed-in caller sees the user header and every destination', (
    tester,
  ) async {
    final profileRepository = MockProfileRepository();
    when(profileRepository.getMe()).thenAnswer((_) async => _user());
    final authProvider = await _authProvider(signedIn: true);

    await _pumpScreen(tester, authProvider, profileRepository);

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('jane@example.com'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Addresses'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Wishlist'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'My Orders'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Profile'), findsOneWidget);
    expect(find.byType(AppEmptyState), findsNothing);
  });

  testWidgets('a signed-out visitor sees a sign-in prompt, not the menu', (
    tester,
  ) async {
    final profileRepository = MockProfileRepository();
    final authProvider = await _authProvider(signedIn: false);

    await _pumpScreen(tester, authProvider, profileRepository);

    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.text('Sign in to view your account'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Addresses'), findsNothing);
    expect(find.text('Sign out'), findsNothing);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN SCREEN'), findsOneWidget);
  });

  testWidgets(
    'the header degrades gracefully (no name/email) when the profile fetch '
    'fails, and the menu still works',
    (tester) async {
      final profileRepository = MockProfileRepository();
      when(
        profileRepository.getMe(),
      ).thenThrow(const AppException(message: 'broke'));
      final authProvider = await _authProvider(signedIn: true);

      await _pumpScreen(tester, authProvider, profileRepository);

      expect(find.text('My account'), findsOneWidget);
      expect(find.text('jane@example.com'), findsNothing);

      await tester.tap(find.widgetWithText(ListTile, 'Addresses'));
      await tester.pumpAndSettle();

      expect(find.text('ADDRESSES SCREEN'), findsOneWidget);
    },
  );

  testWidgets(
    'shows a skeleton header while the profile loads — never a centred '
    'spinner',
    (tester) async {
      final profileRepository = MockProfileRepository();
      final completer = Completer<UserResponse>();
      when(profileRepository.getMe()).thenAnswer((_) => completer.future);
      final authProvider = await _authProvider(signedIn: true);

      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: _router(profileRepository),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(AppMotion.short);
      await tester.pump();

      expect(find.byType(ListTileSkeleton), findsOneWidget);

      completer.complete(_user());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Sign out requires confirmation — Cancel keeps the caller signed in',
    (tester) async {
      final profileRepository = MockProfileRepository();
      when(profileRepository.getMe()).thenAnswer((_) async => _user());
      final authProvider = await _authProvider(signedIn: true);

      await _pumpScreen(tester, authProvider, profileRepository);

      await tester.tap(find.widgetWithText(ListTile, 'Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Sign out?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(authProvider.isAuthenticated, isTrue);
      expect(find.text('LOGIN SCREEN'), findsNothing);
    },
  );

  testWidgets('confirming Sign out logs out and the guard redirects to login', (
    tester,
  ) async {
    final profileRepository = MockProfileRepository();
    when(profileRepository.getMe()).thenAnswer((_) async => _user());
    final authRepository = MockAuthRepository();
    when(authRepository.logout(any)).thenAnswer((_) async {});
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final tokenStorage = TokenStorage(await SharedPreferences.getInstance());
    await tokenStorage.saveTokens('access', 'refresh');
    final authProvider = AuthProvider(authRepository, tokenStorage);
    authProvider.restoreSession();

    await _pumpScreen(tester, authProvider, profileRepository);

    await tester.tap(find.widgetWithText(ListTile, 'Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    verify(
      authRepository.logout(argThat(isA<RefreshTokenRequest>())),
    ).called(1);
    expect(authProvider.isAuthenticated, isFalse);
  });
}
