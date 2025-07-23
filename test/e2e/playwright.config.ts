import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright configuration for Gymnastics AI E2E tests
 */
export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:8080',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    {
      name: 'Mobile Chrome',
      use: { 
        ...devices['Pixel 5'],
        launchOptions: {
          args: ['--disable-web-security', '--allow-insecure-localhost']
        }
      },
    },
    {
      name: 'Mobile Safari',
      use: { 
        ...devices['iPhone 12'],
        launchOptions: {
          args: ['--disable-web-security', '--allow-insecure-localhost']
        }
      },
    },
  ],

  webServer: {
    command: 'cd ../.. && flutter run -d web-server --web-port 8080',
    port: 8080,
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
  },
});