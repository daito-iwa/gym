# Gymnastics AI E2E Tests

## Overview
This directory contains end-to-end tests for the Gymnastics AI Flutter app using Playwright.

## Setup

1. Install dependencies:
```bash
cd test/e2e
npm install
```

2. Install Playwright browsers:
```bash
npx playwright install
```

## Running Tests

### Run all tests:
```bash
npm test
```

### Run tests with UI (recommended for debugging):
```bash
npm run test:ui
```

### Run tests in headed mode:
```bash
npm run test:headed
```

### Debug a specific test:
```bash
npm run test:debug
```

### Generate new tests using recorder:
```bash
npm run codegen
```

## Test Structure

- `01-authentication.spec.ts` - Login, signup, and social authentication tests
- `02-ai-chat.spec.ts` - AI chat functionality and usage limits
- `03-dscore-calculator.spec.ts` - D-score calculation features
- `04-premium-features.spec.ts` - Premium vs free user access control
- `05-offline-functionality.spec.ts` - Offline mode and data persistence
- `06-mobile-responsive.spec.ts` - Mobile UI and responsiveness

## Test Data

### Test Users:
- **Free User**: username: `freeuser`, password: `freepass123`
- **Premium User**: username: `premiumuser`, password: `premiumpass123`
- **Test User**: username: `testuser`, password: `testpass123`

## CI/CD Integration

Add to your GitHub Actions workflow:

```yaml
- name: Install E2E test dependencies
  run: |
    cd test/e2e
    npm ci
    npx playwright install --with-deps

- name: Run E2E tests
  run: |
    cd test/e2e
    npm test

- name: Upload test results
  if: always()
  uses: actions/upload-artifact@v3
  with:
    name: playwright-report
    path: test/e2e/playwright-report/
```

## Tips

1. Use `page.waitForTimeout()` sparingly - prefer `waitForSelector()` or `waitForLoadState()`
2. Add data-testid attributes to elements for more reliable selectors
3. Use Page Object Model for complex test scenarios
4. Keep tests independent - each test should work in isolation

## Troubleshooting

### Tests timing out
- Increase timeout in playwright.config.ts
- Check if Flutter web server is running properly

### Element not found
- Use Playwright Inspector to debug selectors
- Check if elements are rendered conditionally
- Add appropriate wait conditions

### Flaky tests
- Avoid hardcoded timeouts
- Use proper wait conditions
- Ensure test data is reset between tests