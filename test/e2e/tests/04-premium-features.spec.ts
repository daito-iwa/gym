import { test, expect } from '@playwright/test';

test.describe('Premium Features Access Control', () => {
  test.describe('Free User Restrictions', () => {
    test.beforeEach(async ({ page }) => {
      await page.goto('/');
      await page.waitForTimeout(2000);
      
      // Login as free user
      await page.fill('input[type="text"]', 'freeuser');
      await page.fill('input[type="password"]', 'freepass123');
      await page.click('button:has-text("ログイン")');
      await page.waitForTimeout(2000);
    });

    test('should show ads for free users', async ({ page }) => {
      // Should display banner ad
      await expect(page.locator('[aria-label="広告"]')).toBeVisible();
    });

    test('should limit chat messages to 3 per day', async ({ page }) => {
      // Send 3 messages
      for (let i = 0; i < 3; i++) {
        await page.fill('textarea[placeholder*="質問を入力"]', `質問 ${i + 1}`);
        await page.click('button[aria-label="送信"]');
        await page.waitForTimeout(1000);
      }
      
      // 4th message should be blocked
      await page.fill('textarea[placeholder*="質問を入力"]', '4つ目の質問');
      await page.click('button[aria-label="送信"]');
      
      // Should show limit reached dialog
      await expect(page.locator('text=/本日の無料.*制限/')).toBeVisible();
      await expect(page.locator('text=プレミアムにアップグレード')).toBeVisible();
    });

    test('should limit skills database to 50 skills', async ({ page }) => {
      // Go to D-score calculator
      await page.click('text=Dスコア');
      await page.waitForTimeout(1000);
      
      // Select apparatus
      await page.click('text=ゆか');
      await page.waitForTimeout(1000);
      
      // Count available skills
      const skills = await page.locator('button:has-text("追加")').all();
      expect(skills.length).toBeLessThanOrEqual(50);
      
      // Should show limitation notice
      await expect(page.locator('text=/50技.*制限/')).toBeVisible();
    });

    test('should block analytics access', async ({ page }) => {
      // Try to access analytics
      await page.click('text=分析');
      
      // Should show premium required dialog
      await expect(page.locator('text=プレミアム限定機能')).toBeVisible();
      await expect(page.locator('text=/分析機能.*プレミアム/')).toBeVisible();
    });
  });

  test.describe('Premium User Full Access', () => {
    test.beforeEach(async ({ page }) => {
      await page.goto('/');
      await page.waitForTimeout(2000);
      
      // Login as premium user
      await page.fill('input[type="text"]', 'premiumuser');
      await page.fill('input[type="password"]', 'premiumpass123');
      await page.click('button:has-text("ログイン")');
      await page.waitForTimeout(2000);
    });

    test('should not show ads for premium users', async ({ page }) => {
      // Should not display any ads
      await expect(page.locator('[aria-label="広告"]')).not.toBeVisible();
    });

    test('should allow unlimited chat messages', async ({ page }) => {
      // Send multiple messages
      for (let i = 0; i < 10; i++) {
        await page.fill('textarea[placeholder*="質問を入力"]', `質問 ${i + 1}`);
        await page.click('button[aria-label="送信"]');
        await page.waitForTimeout(500);
      }
      
      // Should not show any limit warnings
      await expect(page.locator('text=/制限/')).not.toBeVisible();
    });

    test('should access full skills database', async ({ page }) => {
      // Go to D-score calculator
      await page.click('text=Dスコア');
      await page.waitForTimeout(1000);
      
      // Select apparatus
      await page.click('text=ゆか');
      await page.waitForTimeout(1000);
      
      // Should show premium badge
      await expect(page.locator('text=/799技.*全アクセス/')).toBeVisible();
      
      // Count available skills
      const skills = await page.locator('button:has-text("追加")').all();
      expect(skills.length).toBeGreaterThan(50);
    });

    test('should access analytics features', async ({ page }) => {
      // Access analytics
      await page.click('text=分析');
      await page.waitForTimeout(1000);
      
      // Should show analytics dashboard
      await expect(page.locator('text=演技分析')).toBeVisible();
      await expect(page.locator('text=トレンド')).toBeVisible();
      await expect(page.locator('text=統計')).toBeVisible();
    });

    test('should save unlimited routines', async ({ page }) => {
      // Go to D-score calculator
      await page.click('text=Dスコア');
      await page.waitForTimeout(1000);
      
      // Create and save multiple routines
      for (let i = 0; i < 3; i++) {
        await page.click('text=ゆか');
        await page.waitForTimeout(500);
        await page.click('button:has-text("追加")').first();
        await page.click('button:has-text("保存")');
        await page.fill('input[placeholder*="演技名"]', `ルーティン ${i + 1}`);
        await page.click('button:has-text("保存する")');
        await page.waitForTimeout(500);
      }
      
      // Should save all without restriction
      await expect(page.locator('text=/保存.*成功/')).toBeVisible();
    });
  });

  test('should show upgrade dialog with correct pricing', async ({ page }) => {
    await page.goto('/');
    await page.waitForTimeout(2000);
    
    // Login as free user
    await page.fill('input[type="text"]', 'freeuser');
    await page.fill('input[type="password"]', 'freepass123');
    await page.click('button:has-text("ログイン")');
    await page.waitForTimeout(2000);
    
    // Trigger upgrade dialog
    await page.click('text=分析');
    
    // Should show correct pricing
    await expect(page.locator('text=月額¥500')).toBeVisible();
    await expect(page.locator('text=今すぐアップグレード')).toBeVisible();
  });
});