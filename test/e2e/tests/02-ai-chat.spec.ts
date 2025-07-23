import { test, expect } from '@playwright/test';

test.describe('AI Chat Functionality', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForTimeout(2000);
    
    // Login first
    await page.fill('input[type="text"]', 'testuser');
    await page.fill('input[type="password"]', 'testpass123');
    await page.click('button:has-text("ログイン")');
    await page.waitForTimeout(2000);
  });

  test('should display chat interface', async ({ page }) => {
    // Should be on chat tab by default
    await expect(page.locator('text=AIチャット')).toBeVisible();
    await expect(page.locator('textarea[placeholder*="質問を入力"]')).toBeVisible();
    await expect(page.locator('button[aria-label="送信"]')).toBeVisible();
  });

  test('should send a message and receive response', async ({ page }) => {
    // Type a message
    await page.fill('textarea[placeholder*="質問を入力"]', 'つり輪の基本的な技を教えて');
    
    // Send message
    await page.click('button[aria-label="送信"]');
    
    // Wait for response
    await page.waitForTimeout(3000);
    
    // Should show user message
    await expect(page.locator('text=つり輪の基本的な技を教えて')).toBeVisible();
    
    // Should show AI response
    await expect(page.locator('text=/つり輪.*基本.*技/')).toBeVisible();
  });

  test('should show chat usage limit for free users', async ({ page }) => {
    // Send multiple messages to reach limit
    for (let i = 0; i < 4; i++) {
      await page.fill('textarea[placeholder*="質問を入力"]', `質問 ${i + 1}`);
      await page.click('button[aria-label="送信"]');
      await page.waitForTimeout(1000);
    }
    
    // Should show limit warning
    await expect(page.locator('text=/制限.*プレミアム/')).toBeVisible();
  });

  test('should clear chat history', async ({ page }) => {
    // Send a message first
    await page.fill('textarea[placeholder*="質問を入力"]', 'テストメッセージ');
    await page.click('button[aria-label="送信"]');
    await page.waitForTimeout(2000);
    
    // Open menu and clear chat
    await page.click('button[aria-label="メニュー"]');
    await page.click('text=チャットをクリア');
    
    // Confirm clear
    await page.click('text=クリア');
    
    // Chat should be empty
    await expect(page.locator('text=テストメッセージ')).not.toBeVisible();
  });

  test('should switch chat modes', async ({ page }) => {
    // Click mode selector
    await page.click('text=一般的な質問');
    
    // Select training mode
    await page.click('text=トレーニング相談');
    
    // Mode should be changed
    await expect(page.locator('text=トレーニング相談')).toBeVisible();
  });
});