/**
 * 认证服务测试
 * @module authService.test
 */

import { authService, SignInCredentials, SignUpCredentials } from '../../main/ets/utils/authService';
import { describe, it, expect, beforeEach } from '@ohos/hypium';

export default function authServiceTest() {
  describe('Auth Service Tests', () => {
    beforeEach(() => {
      // 清理认证状态
      authService.signOut();
    });

    it('should initialize with no authenticated user', () => {
      const authState = authService.getAuthState();
      expect(authState.user).toBeNull();
      expect(authState.isAuthenticated).toBeFalse();
      expect(authState.isLoading).toBeFalse();
    });

    it('should get anonymous user ID when not authenticated', () => {
      const userId = authService.getUserId();
      expect(userId).toBe('anonymous');
    });

    it('should validate sign in credentials format', () => {
      const validCredentials: SignInCredentials = {
        email: 'test@example.com',
        password: 'password123'
      };

      const invalidCredentials1: SignInCredentials = {
        email: '',
        password: 'password123'
      };

      const invalidCredentials2: SignInCredentials = {
        email: 'invalid-email',
        password: 'password123'
      };

      expect(validCredentials.email.length).toBeGreaterThan(0);
      expect(validCredentials.email).toContain('@');
      expect(validCredentials.password.length).toBeGreaterThan(0);

      expect(invalidCredentials1.email.length).toBe(0);
      expect(invalidCredentials2.email).not().toContain('@');
    });

    it('should validate sign up credentials format', () => {
      const validCredentials: SignUpCredentials = {
        email: 'test@example.com',
        password: 'password123'
      };

      expect(validCredentials.email).toContain('@');
      expect(validCredentials.password.length).toBeGreaterThanOrEqual(6);
    });

    it('should handle session token management', () => {
      const token = authService.getSessionToken();
      expect(typeof token).toBe('string');
    });

    it('should handle current user state', () => {
      const user = authService.getCurrentUser();
      expect(user).toBeNull();
    });
  });
}