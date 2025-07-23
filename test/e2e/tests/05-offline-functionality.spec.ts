import { test, expect } from '@playwright/test';

test.describe('Offline Functionality', () => {
  test('should work without server connection', async ({ page, context }) => {
    // Block all network requests to API
    await context.route('**/api/**', route => route.abort());
    await context.route('**/auth/**', route => route.abort());
    
    await page.goto('/');
    await page.waitForTimeout(2000);
    
    // Should still be able to login
    await page.fill('input[type="text"]', 'offlineuser');
    await page.fill('input[type="password"]', 'offlinepass123');
    await page.click('button:has-text("ログイン")');
    await page.waitForTimeout(2000);
    
    // Should access main features
    await expect(page.locator('text=AIチャット')).toBeVisible();
  });

  test('should use cached skill data', async ({ page }) => {
    await page.goto('/');
    await page.waitForTimeout(2000);
    
    // Login
    await page.fill('input[type="text"]', 'testuser');
    await page.fill('input[type="password"]', 'testpass123');
    await page.click('button:has-text("ログイン")');
    await page.waitForTimeout(2000);
    
    // Go to D-score calculator
    await page.click('text=Dスコア');
    await page.waitForTimeout(1000);
    
    // Skills should load from local data
    await page.click('text=ゆか');
    await page.waitForTimeout(1000);
    
    // Should show skills immediately
    await expect(page.locator('text=/前方.*宙返り/')).toBeVisible();
  });

  test('should save data locally', async ({ page }) => {
    await page.goto('/');
    await page.waitForTimeout(2000);
    
    // Login
    await page.fill('input[type="text"]', 'testuser');
    await page.fill('input[type="password"]', 'testpass123');
    await page.click('button:has-text("ログイン")');
    await page.waitForTimeout(2000);
    
    // Add a chat message
    await page.fill('textarea[placeholder*="質問を入力"]', 'オフラインテスト');
    await page.click('button[aria-label="送信"]');
    await page.waitForTimeout(2000);
    
    // Reload page
    await page.reload();
    await page.waitForTimeout(2000);
    
    // Login again
    await page.fill('input[type="text"]', 'testuser');
    await page.fill('input[type="password"]', 'testpass123');
    await page.click('button:has-text("ログイン")');
    await page.waitForTimeout(2000);
    
    // Message should still be there
    await expect(page.locator('text=オフラインテスト')).toBeVisible();
  });
});