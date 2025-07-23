import { test, expect } from '@playwright/test';

test.describe('D-Score Calculator', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForTimeout(2000);
    
    // Login
    await page.fill('input[type="text"]', 'testuser');
    await page.fill('input[type="password"]', 'testpass123');
    await page.click('button:has-text("ログイン")');
    await page.waitForTimeout(2000);
    
    // Navigate to D-Score calculator
    await page.click('text=Dスコア');
    await page.waitForTimeout(1000);
  });

  test('should display apparatus selection', async ({ page }) => {
    // Should show all apparatus options
    await expect(page.locator('text=ゆか')).toBeVisible();
    await expect(page.locator('text=あん馬')).toBeVisible();
    await expect(page.locator('text=つり輪')).toBeVisible();
    await expect(page.locator('text=跳馬')).toBeVisible();
    await expect(page.locator('text=平行棒')).toBeVisible();
    await expect(page.locator('text=鉄棒')).toBeVisible();
  });

  test('should select apparatus and show skills', async ({ page }) => {
    // Select floor exercise
    await page.click('text=ゆか');
    await page.waitForTimeout(1000);
    
    // Should show skills list
    await expect(page.locator('text=/前方.*宙返り/')).toBeVisible();
    await expect(page.locator('text=/後方.*宙返り/')).toBeVisible();
  });

  test('should add skills to routine', async ({ page }) => {
    // Select floor
    await page.click('text=ゆか');
    await page.waitForTimeout(1000);
    
    // Add a few skills
    await page.click('text=前方宙返り').first();
    await page.click('text=後方宙返り').first();
    
    // Should show in routine composition
    await expect(page.locator('text=演技構成')).toBeVisible();
    await expect(page.locator('text=/D.*スコア.*:/')).toBeVisible();
  });

  test('should calculate D-score correctly', async ({ page }) => {
    // Select floor
    await page.click('text=ゆか');
    await page.waitForTimeout(1000);
    
    // Add multiple skills
    const skills = await page.locator('button:has-text("追加")').all();
    for (let i = 0; i < 5 && i < skills.length; i++) {
      await skills[i].click();
      await page.waitForTimeout(200);
    }
    
    // Should show calculated D-score
    await expect(page.locator('text=/Dスコア.*[0-9]+\\.[0-9]+/')).toBeVisible();
  });

  test('should remove skills from routine', async ({ page }) => {
    // Select floor and add skills
    await page.click('text=ゆか');
    await page.waitForTimeout(1000);
    await page.click('button:has-text("追加")').first();
    
    // Remove skill
    await page.click('button[aria-label="削除"]').first();
    
    // Skill should be removed
    await expect(page.locator('text=/Dスコア.*0\\.0/')).toBeVisible();
  });

  test('should save routine for premium users', async ({ page }) => {
    // Select floor and add skills
    await page.click('text=ゆか');
    await page.waitForTimeout(1000);
    await page.click('button:has-text("追加")').first();
    
    // Try to save
    await page.click('button:has-text("保存")');
    
    // Should show save dialog or premium prompt
    await expect(page.locator('text=/保存.*演技構成/')).toBeVisible();
  });

  test('should filter skills by difficulty', async ({ page }) => {
    // Select floor
    await page.click('text=ゆか');
    await page.waitForTimeout(1000);
    
    // Click filter
    await page.click('button[aria-label="フィルター"]');
    
    // Select difficulty D
    await page.click('text=D難度');
    
    // Should show only D difficulty skills
    const skills = await page.locator('text=/D\\s*\\./'').all();
    expect(skills.length).toBeGreaterThan(0);
  });
});