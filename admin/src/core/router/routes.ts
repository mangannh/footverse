/**
 * Typed route-path constants — the React analog of Flutter `app_routes.dart`
 * (react-guidelines §Routing).
 *
 * This is the single place a URL path appears; components and the router
 * reference these names instead of inline path strings. The table grows one
 * entry per routed screen as later tasks add them (Task 02 mounts `login`,
 * Task 03 adds the guarded shell root and its section paths).
 */
export const ROUTES = {
  root: '/',
  login: '/login',
  brands: '/brands',
  brandForm: '/brands/form',
  categories: '/categories',
  categoryForm: '/categories/form',
  products: '/products',
  productForm: '/products/form',
  coupons: '/coupons',
  couponForm: '/coupons/form',
} as const;
