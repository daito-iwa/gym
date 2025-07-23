import { test, expect } from '@playwright/test';

test.describe('Mobile Responsiveness', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForTimeout(2000);
    
    // Login
    await page.fill('input[type="text"]', 'testuser');
    await page.fill('input[type="password"]', 'testpass123');
    await page.click('button:has-text("ログイン")');
    await page.waitForTimeout(2000);
  });

  test('should show mobile navigation', async ({ page }) => {
    // Bottom navigation should be visible
    await expect(page.locator('nav[aria-label="メインナビゲーション"]')).toBeVisible();
    
    // Should have all navigation items
    await expect(page.locator('text=チャット')).toBeVisible();
    await expect(page.locator('text=Dスコア')).toBeVisible();
    await expect(page.locator('text=全種目')).toBeVisible();
    await expect(page.locator('text=分析')).toBeVisible();
  });

  test('should handle touch gestures', async ({ page }) => {
    // Go to D-score calculator
    await page.click('text=Dスコア');
    await page.waitForTimeout(1000);
    
    // Select apparatus
    await page.click('text=ゆか');
    await page.waitForTimeout(1000);
    
    // Scroll skills list
    await page.locator('.skills-list').evaluate(el => {
      el.scrollTop = 100;
    });
    
    // Should maintain scroll position
    const scrollPosition = await page.locator('.skills-list').evaluate(el => el.scrollTop);
    expect(scrollPosition).toBeGreaterThan(0);
  });

  test('should show mobile-optimized dialogs', async ({ page }) => {
    // Trigger upgrade dialog
    await page.click('text=分析');
    
    // Dialog should be mobile-optimized
    const dialog = page.locator('[role="dialog"]');
    await expect(dialog).toBeVisible();
    
    // Should be full-width on mobile
    const dialogBox = await dialog.boundingBox();
    const viewport = page.viewportSize();
    
    if (dialogBox && viewport) {
      expect(dialogBox.width).toBeGreaterThan(viewport.width * 0.9);
    }
  });

  test('should handle orientation changes', async ({ page, context }) => {
    // Start in portrait
    await page.setViewportSize({ width: 375, height: 812 });
    await page.waitForTimeout(1000);
    
    // UI should adapt
    await expect(page.locator('nav[aria-label="メインナビゲーション"]')).toBeVisible();
    
    // Change to landscape
    await page.setViewportSize({ width: 812, height: 375 });
    await page.waitForTimeout(1000);
    
    // UI should still be functional
    await expect(page.locator('text=AIチャット')).toBeVisible();
  });

  test('should have touch-friendly buttons', async ({ page }) => {
    // All interactive elements should be at least 44x44 pixels
    const buttons = await page.locator('button').all();
    
    for (const button of buttons.slice(0, 5)) { // Check first 5 buttons
      const box = await button.boundingBox();
      if (box) {
        expect(box.width).toBeGreaterThanOrEqual(44);
        expect(box.height).toBeGreaterThanOrEqual(44);
      }
    }
  });

  test('should handle virtual keyboard', async ({ page }) => {
    // Focus on chat input
    await page.click('textarea[placeholder*="質問を入力"]');
    
    // Simulate virtual keyboard appearance
    await page.setViewportSize({ width: 375, height: 500 }); // Reduced height
    
    // Input should still be visible and accessible
    await expect(page.locator('textarea[placeholder*="質問を入力"]')).toBeInViewport();
    
    // Should be able to type
    await page.fill('textarea[placeholder*="質問を入力"]', 'キーボードテスト');
    await expect(page.locator('textarea')).toHaveValue('キーボードテスト');
  });
});