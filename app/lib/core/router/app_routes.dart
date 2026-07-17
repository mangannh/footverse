/// Named-route identifiers shared by the router and the screens that navigate.
///
/// Widgets navigate by these names only (`context.goNamed(AppRoute.login)`),
/// never by inline path strings (flutter-guidelines §Routing). They live apart
/// from the router configuration so a screen can reference a route name without
/// depending on the whole router (and the screens it wires).
class AppRoute {
  const AppRoute._();

  static const String catalog = 'catalog';
  static const String productDetail = 'productDetail';
  static const String login = 'login';
  static const String register = 'register';
  static const String account = 'account';
  static const String addresses = 'addresses';
  static const String addressForm = 'addressForm';
  static const String cart = 'cart';
  static const String wishlist = 'wishlist';
  static const String checkout = 'checkout';
  static const String orders = 'orders';
  static const String orderDetail = 'orderDetail';
  static const String profile = 'profile';
  static const String changePassword = 'changePassword';
  static const String changeEmail = 'changeEmail';
}
