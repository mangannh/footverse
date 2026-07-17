import { cleanup, render, screen } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';

import type { Role } from '@/features/auth/models/role';
import type { UserResponse } from '@/features/auth/models/user-response';
import { SessionContext, type SessionContextValue } from '@/features/auth/session/session-context';

import { AdminGuard } from './admin-guard';

function sessionValue(overrides: Partial<SessionContextValue>): SessionContextValue {
  return {
    user: null,
    isAuthenticated: false,
    isSubmitting: false,
    isInitializing: false,
    login: vi.fn(),
    logout: vi.fn(),
    ...overrides,
  };
}

function userWithRole(role: Role): UserResponse {
  return {
    id: 1,
    email: 'user@footverse.com',
    fullName: 'User',
    phone: '0900000000',
    role,
    enabled: true,
    createdAt: '2026-01-01T00:00:00',
    updatedAt: '2026-01-01T00:00:00',
  };
}

function renderGuard(session: SessionContextValue) {
  return render(
    <SessionContext.Provider value={session}>
      <MemoryRouter initialEntries={['/brands']}>
        <Routes>
          <Route path="/login" element={<div>Login Screen</div>} />
          <Route
            path="/brands"
            element={
              <AdminGuard>
                <div>Protected Content</div>
              </AdminGuard>
            }
          />
        </Routes>
      </MemoryRouter>
    </SessionContext.Provider>,
  );
}

describe('AdminGuard', () => {
  afterEach(cleanup);

  it('redirects a signed-out visitor to login', () => {
    renderGuard(sessionValue({ isAuthenticated: false, user: null }));

    expect(screen.getByText('Login Screen')).toBeTruthy();
    expect(screen.queryByText('Protected Content')).toBeNull();
  });

  it('redirects a CUSTOMER to login', () => {
    renderGuard(sessionValue({ isAuthenticated: true, user: userWithRole('CUSTOMER') }));

    expect(screen.getByText('Login Screen')).toBeTruthy();
    expect(screen.queryByText('Protected Content')).toBeNull();
  });

  it('renders the protected content for an ADMIN', () => {
    renderGuard(sessionValue({ isAuthenticated: true, user: userWithRole('ADMIN') }));

    expect(screen.getByText('Protected Content')).toBeTruthy();
    expect(screen.queryByText('Login Screen')).toBeNull();
  });

  it('waits for the session to restore instead of redirecting', () => {
    renderGuard(sessionValue({ isInitializing: true, isAuthenticated: false, user: null }));

    expect(screen.queryByText('Login Screen')).toBeNull();
    expect(screen.queryByText('Protected Content')).toBeNull();
  });
});
