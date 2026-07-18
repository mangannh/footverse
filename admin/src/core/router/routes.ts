/**
 * Typed route-path constants — the React analog of Flutter `app_routes.dart`
 * (react-guidelines §Routing).
 *
 * This is the single place a URL path appears; components and the router
 * reference these names instead of inline path strings. The table grows one
 * entry per routed screen as later tasks add them (Task 02 mounts `login`,
 * Task 03 adds the guarded shell root and its section paths).
 *
 * `orderDetail` is a path **builder**, not a static string — the admin
 * panel's first parameterized route (sprint-12-plan Design Decision 5). An
 * order detail is reached by id in the URL (so it can be opened, refreshed,
 * and linked directly), never by router `state`; the builder keeps that the
 * single place the `/orders/:id` shape is ever concatenated.
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
  orders: '/orders',
  orderDetail: (id: number) => `/orders/${id}`,
} as const;
