#!/bin/bash

# Gymnastics AI E2E Test Runner

echo "🏃 Starting Gymnastics AI E2E Tests..."

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Check if Playwright is installed
if ! npx playwright --version > /dev/null 2>&1; then
    echo "🎭 Installing Playwright browsers..."
    npx playwright install --with-deps
fi

# Start Flutter web server in background
echo "🚀 Starting Flutter web server..."
cd ../..
flutter run -d web-server --web-port 8080 &
FLUTTER_PID=$!

# Wait for server to start
echo "⏳ Waiting for server to start..."
sleep 10

# Run tests
echo "🧪 Running E2E tests..."
cd test/e2e
npx playwright test

# Capture exit code
TEST_EXIT_CODE=$?

# Kill Flutter server
echo "🛑 Stopping Flutter web server..."
kill $FLUTTER_PID

# Show results
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "❌ Some tests failed. Check the report with: npm run report"
fi

exit $TEST_EXIT_CODE