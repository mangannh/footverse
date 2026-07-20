import 'package:go_router/go_router.dart';

import '../../features/address/models/address_response.dart';
import '../../features/address/repositories/address_repository.dart';
import '../../features/address/screens/address_form_screen.dart';
import '../../features/address/screens/address_list_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/providers/password_reset_provider.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../../features/auth/screens/account_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/verify_reset_otp_screen.dart';
import '../../features/cart/screens/cart_screen.dart';
import '../../features/order/repositories/order_repository.dart';
import '../../features/order/screens/checkout_screen.dart';
import '../../features/order/screens/order_detail_screen.dart';
import '../../features/order/screens/order_list_screen.dart';
import '../../features/order/screens/payment_webview_screen.dart';
import '../../features/product/repositories/brand_repository.dart';
import '../../features/product/repositories/category_repository.dart';
import '../../features/product/repositories/product_repository.dart';
import '../../features/product/screens/product_detail_screen.dart';
import '../../features/product/screens/product_list_screen.dart';
import '../../features/profile/repositories/profile_repository.dart';
import '../../features/profile/screens/change_email_screen.dart';
import '../../features/profile/screens/change_password_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/review/repositories/review_repository.dart';
import '../../features/wishlist/screens/wishlist_screen.dart';
import 'app_routes.dart';

// Path definitions are private to the router: the single place any URL path
// appears. `productDetail` is a child of `catalog`, so navigating to it builds a
// catalog → detail stack and the automatic back button returns to the list.
const String _catalogPath = '/';
const String _productDetailPath = 'products/:id';
const String _loginPath = '/login';
// Relative to `_loginPath`, nested three deep so the flow's URL structure
// states what it belongs to and the auth guard needs no special case for it
// (mirrors the address list → form and order list → detail nesting).
const String _forgotPasswordPath = 'forgot-password';
const String _verifyResetOtpPath = 'verify-otp';
const String _resetPasswordPath = 'reset';
const String _registerPath = '/register';
const String _accountPath = '/account';
const String _addressesPath = '/addresses';
// Relative to `_addressesPath`, so the form is a child of the address list and
// back-navigation stacks naturally (mirrors the catalog → detail nesting).
const String _addressFormPath = 'form';
const String _cartPath = '/cart';
const String _wishlistPath = '/wishlist';
const String _checkoutPath = '/checkout';
// Relative to `_checkoutPath`, so the payment WebView is a child of checkout
// and inherits its auth guard automatically — no special-case guard rule
// (mirrors the address list → form nesting). Reachable by name from the order
// detail screen too (the retry-payment affordance), exactly as the order
// detail route is itself reached from checkout though nested under `_ordersPath`.
const String _paymentWebviewPath = 'payment/:id';
const String _ordersPath = '/orders';
// Relative to `_ordersPath`, so the order detail is a child of the order list and
// back-navigation stacks naturally (mirrors the catalog → detail nesting).
const String _orderDetailPath = ':id';
const String _profilePath = '/profile';
// Relative to `_profilePath`, so each credential screen is a child of the profile
// screen and back-navigation stacks naturally (mirrors the address list → form
// and order list → detail nesting).
const String _changePasswordPath = 'password';
const String _changeEmailPath = 'email';

// The signed-in-only area. A location under any of these paths requires a token;
// the redirect algorithm below is unchanged — only the guarded set grew from the
// single `_accountPath` (sprint-6-plan item 07) to include the Sprint 7 routes,
// the Sprint 8 checkout / order routes, and, now, the Sprint 9 `_profilePath`.
// `_ordersPath` and `_profilePath` also guard their nested children, since the
// guard matches any location under a path.
const List<String> _authenticatedPaths = <String>[
  _accountPath,
  _addressesPath,
  _cartPath,
  _wishlistPath,
  _checkoutPath,
  _ordersPath,
  _profilePath,
];

/// Builds the `go_router` configuration (flutter-guidelines §Routing).
///
/// The app opens on the public catalog (assumption 4); guests reach every
/// catalog route while the signed-in-only [AppRoute.account] requires a token.
/// [authProvider] is both the redirect's auth source and the router's
/// [GoRouter.refreshListenable], so a change in auth state re-evaluates the
/// guard and the router redirects accordingly (sprint-6-plan item 07). The
/// catalog repositories are injected here from the composition root so the
/// catalog screen can build its provider without any widget touching `Dio`.
/// [authRepository] is injected the same way for the password-reset flow's
/// [ForgotPasswordScreen] (sprint-13-plan Task 07), which builds the flow's
/// single [PasswordResetProvider] instance from it.
GoRouter createAppRouter(
  AuthProvider authProvider,
  AuthRepository authRepository,
  ProductRepository productRepository,
  CategoryRepository categoryRepository,
  BrandRepository brandRepository,
  AddressRepository addressRepository,
  OrderRepository orderRepository,
  ProfileRepository profileRepository,
  ReviewRepository reviewRepository,
) {
  return GoRouter(
    initialLocation: _catalogPath,
    refreshListenable: authProvider,
    redirect: (context, state) => _guard(state, authProvider),
    routes: <RouteBase>[
      GoRoute(
        path: _catalogPath,
        name: AppRoute.catalog,
        builder: (context, state) => ProductListScreen(
          productRepository: productRepository,
          categoryRepository: categoryRepository,
          brandRepository: brandRepository,
        ),
        routes: <RouteBase>[
          GoRoute(
            path: _productDetailPath,
            name: AppRoute.productDetail,
            builder: (context, state) => ProductDetailScreen(
              productId: int.parse(state.pathParameters['id']!),
              productRepository: productRepository,
              reviewRepository: reviewRepository,
              profileRepository: profileRepository,
            ),
          ),
        ],
      ),
      GoRoute(
        path: _loginPath,
        name: AppRoute.login,
        // `state.extra` is shared by every route matched in the same
        // location, including the nested password-reset routes below (whose
        // `extra` is a `(PasswordResetProvider, String)` record, not a
        // `String`) — so this checks the runtime type instead of casting.
        builder: (context, state) {
          final extra = state.extra;
          return LoginScreen(prefillEmail: extra is String ? extra : null);
        },
        routes: <RouteBase>[
          GoRoute(
            path: _forgotPasswordPath,
            name: AppRoute.forgotPassword,
            builder: (context, state) =>
                ForgotPasswordScreen(authRepository: authRepository),
            routes: <RouteBase>[
              GoRoute(
                path: _verifyResetOtpPath,
                name: AppRoute.verifyResetOtp,
                builder: (context, state) {
                  final args = state.extra! as (PasswordResetProvider, String);
                  return VerifyResetOtpScreen(
                    provider: args.$1,
                    email: args.$2,
                  );
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: _resetPasswordPath,
                    name: AppRoute.resetPassword,
                    builder: (context, state) {
                      final args =
                          state.extra! as (PasswordResetProvider, String);
                      return ResetPasswordScreen(
                        provider: args.$1,
                        email: args.$2,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: _registerPath,
        name: AppRoute.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: _accountPath,
        name: AppRoute.account,
        builder: (context, state) =>
            AccountScreen(profileRepository: profileRepository),
      ),
      GoRoute(
        path: _addressesPath,
        name: AppRoute.addresses,
        builder: (context, state) =>
            AddressListScreen(addressRepository: addressRepository),
        routes: <RouteBase>[
          GoRoute(
            path: _addressFormPath,
            name: AppRoute.addressForm,
            builder: (context, state) =>
                AddressFormScreen(address: state.extra as AddressResponse?),
          ),
        ],
      ),
      GoRoute(
        path: _cartPath,
        name: AppRoute.cart,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: _wishlistPath,
        name: AppRoute.wishlist,
        builder: (context, state) => const WishlistScreen(),
      ),
      GoRoute(
        path: _checkoutPath,
        name: AppRoute.checkout,
        builder: (context, state) => CheckoutScreen(
          orderRepository: orderRepository,
          addressRepository: addressRepository,
          cartItemIds: (state.extra as List<int>?) ?? const <int>[],
        ),
        routes: <RouteBase>[
          GoRoute(
            path: _paymentWebviewPath,
            name: AppRoute.paymentWebview,
            builder: (context, state) => PaymentWebViewScreen(
              orderId: int.parse(state.pathParameters['id']!),
              orderRepository: orderRepository,
            ),
          ),
        ],
      ),
      GoRoute(
        path: _ordersPath,
        name: AppRoute.orders,
        builder: (context, state) =>
            OrderListScreen(orderRepository: orderRepository),
        routes: <RouteBase>[
          GoRoute(
            path: _orderDetailPath,
            name: AppRoute.orderDetail,
            builder: (context, state) => OrderDetailScreen(
              orderId: int.parse(state.pathParameters['id']!),
              orderRepository: orderRepository,
            ),
          ),
        ],
      ),
      GoRoute(
        path: _profilePath,
        name: AppRoute.profile,
        builder: (context, state) =>
            ProfileScreen(profileRepository: profileRepository),
        routes: <RouteBase>[
          GoRoute(
            path: _changePasswordPath,
            name: AppRoute.changePassword,
            builder: (context, state) =>
                ChangePasswordScreen(profileRepository: profileRepository),
          ),
          GoRoute(
            path: _changeEmailPath,
            name: AppRoute.changeEmail,
            builder: (context, state) =>
                ChangeEmailScreen(profileRepository: profileRepository),
          ),
        ],
      ),
    ],
  );
}

/// The single redirect rule: it guards the authenticated-only area and bounces a
/// signed-in user away from the auth screens. It reads state only — no business
/// logic, no side effects (flutter-guidelines §Routing).
String? _guard(GoRouterState state, AuthProvider authProvider) {
  final authenticated = authProvider.isAuthenticated;
  final location = state.matchedLocation;

  final requiresAuth = _authenticatedPaths.any(
    (path) => location == path || location.startsWith('$path/'),
  );
  final onAuthScreen = location == _loginPath || location == _registerPath;

  if (requiresAuth && !authenticated) {
    // Remember where the user was headed so login can return them there.
    return Uri(
      path: _loginPath,
      queryParameters: <String, String>{'from': location},
    ).toString();
  }
  if (onAuthScreen && authenticated) {
    final from = state.uri.queryParameters['from'];
    return (from != null && from.isNotEmpty) ? from : _accountPath;
  }
  return null;
}
