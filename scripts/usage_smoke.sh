#!/bin/bash
# Smoke test for usage tracking backend
# Tests: fetch → book 120s → fetch

set -e

# Configuration (can be overridden via env)
BASE_URL="${INGEST_URL:-https://rhfhateyqdiysgooiqtd.functions.supabase.co/ingest}"
TOKEN="${ANALYTICS_TOKEN:-92942cbd38ee5c9c58663e2b7329cc6beb6e23063a79913529abf8b6a5c676b1}"
TEST_USER="${TEST_USER_KEY:-smoke_test_$(date +%s)}"

echo "🧪 Usage Tracking Smoke Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Base URL: $BASE_URL"
echo "Test User: $TEST_USER"
echo ""

# 1. Initial fetch (should return 0 seconds used)
echo "📊 Test 1: Initial fetch (new user)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE1=$(curl -s -X POST "$BASE_URL/usage/fetch" \
  -H "Content-Type: application/json" \
  -H "x-analytics-token: $TOKEN" \
  -d "{\"user_key\":\"$TEST_USER\",\"plan\":\"free\"}")

echo "Response: $RESPONSE1"
SECONDS_USED_1=$(echo "$RESPONSE1" | grep -o '"seconds_used":[0-9]*' | cut -d':' -f2)
LIMIT_1=$(echo "$RESPONSE1" | grep -o '"limit_seconds":[0-9]*' | cut -d':' -f2)

echo "Seconds used: $SECONDS_USED_1"
echo "Limit: $LIMIT_1"
echo ""

if [ "$SECONDS_USED_1" != "0" ]; then
  echo "❌ FAIL: Expected 0 seconds used for new user, got $SECONDS_USED_1"
  exit 1
fi

if [ "$LIMIT_1" != "1800" ]; then
  echo "⚠️  WARNING: Expected 1800 second limit (30 min), got $LIMIT_1"
fi

echo "✅ PASS: New user has 0 seconds used"
echo ""

# 2. Book 120 seconds
echo "📊 Test 2: Book 120 seconds"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
CURRENT_TS=$(date +%s)
RESPONSE2=$(curl -s -X POST "$BASE_URL/usage/book" \
  -H "Content-Type: application/json" \
  -H "x-analytics-token: $TOKEN" \
  -d "{\"user_key\":\"$TEST_USER\",\"seconds\":120,\"plan\":\"free\",\"recorded_at\":$CURRENT_TS}")

echo "Response: $RESPONSE2"
SUCCESS=$(echo "$RESPONSE2" | grep -o '"success":[a-z]*' | cut -d':' -f2)
SECONDS_USED_2=$(echo "$RESPONSE2" | grep -o '"seconds_used":[0-9]*' | cut -d':' -f2)

echo "Success: $SUCCESS"
echo "Seconds used after booking: $SECONDS_USED_2"
echo ""

if [ "$SUCCESS" != "true" ]; then
  echo "❌ FAIL: Book request failed"
  exit 1
fi

if [ "$SECONDS_USED_2" != "120" ]; then
  echo "❌ FAIL: Expected 120 seconds used, got $SECONDS_USED_2"
  exit 1
fi

echo "✅ PASS: Successfully booked 120 seconds"
echo ""

# 3. Fetch again (should show 120 seconds used)
echo "📊 Test 3: Fetch after booking"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE3=$(curl -s -X POST "$BASE_URL/usage/fetch" \
  -H "Content-Type: application/json" \
  -H "x-analytics-token: $TOKEN" \
  -d "{\"user_key\":\"$TEST_USER\",\"plan\":\"free\"}")

echo "Response: $RESPONSE3"
SECONDS_USED_3=$(echo "$RESPONSE3" | grep -o '"seconds_used":[0-9]*' | cut -d':' -f2)

echo "Seconds used: $SECONDS_USED_3"
echo ""

if [ "$SECONDS_USED_3" != "120" ]; then
  echo "❌ FAIL: Expected 120 seconds used, got $SECONDS_USED_3"
  exit 1
fi

echo "✅ PASS: Usage correctly persisted"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 All tests passed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
