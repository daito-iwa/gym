import { test, expect } from '@playwright/test';

test.describe('Authentication Flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    // Wait for app to load
    await page.waitForTimeout(2000);
  });

  test('should display login screen with all elements', async ({ page }) => {
    // Check for login elements
    await expect(page.locator('text=ログイン')).toBeVisible();
    await expect(page.locator('input[type="text"]').first()).toBeVisible(); // Username
    await expect(page.locator('input[type="password"]')).toBeVisible(); // Password
    await expect(page.locator('text=Googleでサインイン')).toBeVisible();
    await expect(page.locator('text=Appleでサインイン')).toBeVisible();
  });

  test('should login with username and password', async ({ page }) => {
    // Fill login form
    await page.fill('input[type="text"]', 'testuser');
    await page.fill('input[type="password"]', 'testpass123');
    
    // Click login button
    await page.click('button:has-text("ログイン")');
    
    // Wait for navigation
    await page.waitForTimeout(2000);
    
    // Should be on home page
    await expect(page.locator('text=AIチャット')).toBeVisible();
  });

  test('should login with Google Sign-In', async ({ page }) => {
    // Click Google sign-in button
    await page.click('text=Googleでサインイン');
    
    // Wait for mock authentication
    await page.waitForTimeout(2000);
    
    // Should be logged in
    await expect(page.locator('text=AIチャット')).toBeVisible();
  });

  test('should login with Apple Sign-In on iOS', async ({ page, browserName }) => {
    // Skip on non-Safari browsers
    if (browserName !== 'webkit') {
      test.skip();
      return;
    }
    
    // Click Apple sign-in button
    await page.click('text=Appleでサインイン');
    
    // Wait for mock authentication
    await page.waitForTimeout(2000);
    
    // Should be logged in
    await expect(page.locator('text=AIチャット')).toBeVisible();
  });

  test('should show error for invalid credentials', async ({ page }) => {
    // Fill with short username
    await page.fill('input[type="text"]', 'usr');
    await page.fill('input[type="password"]', 'pass');
    
    // Try to submit
    await page.click('button:has-text("ログイン")');
    
    // Should show validation error
    await expect(page.locator('text=4文字以上入力してください')).toBeVisible();
  });

  test('should switch to sign up mode', async ({ page }) => {
    // Click create account
    await page.click('text=新規アカウント作成');
    
    // Should show sign up form
    await expect(page.locator('text=サインアップ')).toBeVisible();
    await expect(page.locator('input[placeholder*="メール"]')).toBeVisible();
    await expect(page.locator('input[placeholder*="氏名"]')).toBeVisible();
  });

  test('should switch language to English', async ({ page }) => {
    // Click language dropdown
    await page.click('text=日本語');
    await page.click('text=English');
    
    // Should show English text
    await expect(page.locator('text=Login')).toBeVisible();
    await expect(page.locator('text=Username')).toBeVisible();
  });
});