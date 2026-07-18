import { createBrowserRouter } from 'react-router-dom';

import { httpClient } from '@/core/api/http-client';
import { AppShell } from '@/core/components/app-shell';
import { SectionPlaceholder } from '@/core/components/section-placeholder';
import { BrandFormPage } from '@/features/brand/pages/brand-form-page';
import { BrandListPage } from '@/features/brand/pages/brand-list-page';
import { BrandRepository } from '@/features/brand/repositories/brand-repository';
import { CategoryFormPage } from '@/features/category/pages/category-form-page';
import { CategoryListPage } from '@/features/category/pages/category-list-page';
import { CategoryRepository } from '@/features/category/repositories/category-repository';
import { CouponFormPage } from '@/features/coupon/pages/coupon-form-page';
import { CouponListPage } from '@/features/coupon/pages/coupon-list-page';
import { CouponRepository } from '@/features/coupon/repositories/coupon-repository';
import { ProductFormPage } from '@/features/product/pages/product-form-page';
import { ProductListPage } from '@/features/product/pages/product-list-page';
import { ProductRepository } from '@/features/product/repositories/product-repository';

import { AdminGuard } from './admin-guard';
import { LoginRoute } from './login-route';
import { ROUTES } from './routes';

// Composition root: constructed once against the single Axios instance and
// injected into each feature's pages as a prop — the React analog of
// Flutter's `app_router.dart` receiving `XxxRepository(dio)` from `main.dart`.
const brandRepository = new BrandRepository(httpClient);
const categoryRepository = new CategoryRepository(httpClient);
const productRepository = new ProductRepository(httpClient);
const couponRepository = new CouponRepository(httpClient);

/**
 * The single React Router configuration (react-guidelines §Routing) — the analog
 * of the Flutter `createAppRouter`. The login route is public; every other route
 * is nested under the [AdminGuard] and the [AppShell]. Route paths come from the
 * [ROUTES] constants — no inline path string appears here or in any component.
 */
export const router = createBrowserRouter([
  { path: ROUTES.login, element: <LoginRoute /> },
  {
    element: (
      <AdminGuard>
        <AppShell />
      </AdminGuard>
    ),
    children: [
      {
        index: true,
        element: (
          <SectionPlaceholder
            title="FootVerse Admin"
            description="Select a section from the navigation to begin."
          />
        ),
      },
      {
        path: ROUTES.brands,
        children: [
          { index: true, element: <BrandListPage repository={brandRepository} /> },
          { path: 'form', element: <BrandFormPage repository={brandRepository} /> },
        ],
      },
      {
        path: ROUTES.categories,
        children: [
          { index: true, element: <CategoryListPage repository={categoryRepository} /> },
          { path: 'form', element: <CategoryFormPage repository={categoryRepository} /> },
        ],
      },
      {
        path: ROUTES.products,
        children: [
          { index: true, element: <ProductListPage repository={productRepository} /> },
          {
            path: 'form',
            element: (
              <ProductFormPage
                productRepository={productRepository}
                categoryRepository={categoryRepository}
                brandRepository={brandRepository}
              />
            ),
          },
        ],
      },
      {
        path: ROUTES.coupons,
        children: [
          { index: true, element: <CouponListPage repository={couponRepository} /> },
          { path: 'form', element: <CouponFormPage repository={couponRepository} /> },
        ],
      },
    ],
  },
]);
