import type { AxiosInstance } from 'axios';

import { AppError } from '@/core/error/app-error';
import type { ApiResponse } from '@/shared/types/api-response';

import type { DashboardResponse } from '../models/dashboard-response';

const DASHBOARD_PATH = '/api/v1/admin/dashboard';
const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

/**
 * The typed client of the single ADMIN dashboard read endpoint (dto-spec §20,
 * sprint-13-plan Task 02) — the React analog of the Flutter dashboard
 * repository, and the direct analog of the Sprint 12 `OrderRepository`
 * (react-guidelines §Repository Contract). The dashboard is read-only: there
 * is no create / update / delete method.
 *
 * It only calls the API, unwraps the `ApiResponse` envelope, and returns the
 * typed payload — throwing `AppError` on failure (the single Axios
 * instance's error interceptor has already mapped the transport error). It
 * holds no business logic, no feature state, and touches no storage or
 * navigation.
 */
export class DashboardRepository {
  constructor(private readonly client: AxiosInstance) {}

  /** `GET /admin/dashboard` — the store's core operating figures. No request parameters. */
  async get(): Promise<DashboardResponse> {
    const response = await this.client.get<ApiResponse<DashboardResponse>>(DASHBOARD_PATH);
    return this.unwrap(response.data.data);
  }

  private unwrap<T>(data: T | null | undefined): T {
    if (data === undefined || data === null) {
      throw new AppError({ message: UNEXPECTED_MESSAGE });
    }
    return data;
  }
}
