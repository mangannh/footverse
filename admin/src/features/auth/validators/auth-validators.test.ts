import { describe, expect, it } from 'vitest';

import { authValidators } from './auth-validators';

describe('authValidators.email', () => {
  it('accepts a valid email', () => {
    expect(authValidators.email('admin@footverse.com')).toBeUndefined();
  });

  it('rejects a blank email', () => {
    expect(authValidators.email('   ')).toBe('Email is required');
  });

  it('rejects a malformed email', () => {
    expect(authValidators.email('foo@')).toBe('Enter a valid email address');
    expect(authValidators.email('nope')).toBe('Enter a valid email address');
  });
});

describe('authValidators.requiredPassword', () => {
  it('accepts any non-empty password', () => {
    expect(authValidators.requiredPassword('x')).toBeUndefined();
  });

  it('rejects an empty password', () => {
    expect(authValidators.requiredPassword('')).toBe('Password is required');
  });
});
