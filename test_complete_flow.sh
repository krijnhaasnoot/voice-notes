#!/bin/bash
set -e

BASE_URL="https://rhfhateyqdiysgooiqtd.supabase.co/functions/v1/ingest"
TOKEN="92942cbd38ee5c9c58663e2b7329cc6beb6e23063a79913529abf8b6a5c676b1"
USER="test_complete_flow_$(date +%s)"

echo "🧪 Testing complete flow with user: $USER"
echo ""

echo "1️⃣ Fetch initial usage (should be 0/1800):"
curl -X POST "$BASE_URL/usage/fetch" \
  -H "Content-Type: application/json" \
  -H "x-analytics-token: $TOKEN" \
  -d "{\"user_key\":\"$USER\",\"plan\":\"free\"}" -s | jq .
echo ""

echo "2️⃣ Book 120 seconds of usage:"
curl -X POST "$BASE_URL/usage/book" \
  -H "Content-Type: application/json" \
  -H "x-analytics-token: $TOKEN" \
  -d "{\"user_key\":\"$USER\",\"seconds\":120,\"recorded_at\":$(date +%s),\"plan\":\"free\"}" -s | jq .
echo ""

echo "3️⃣ Fetch updated usage (should be 120/1800):"
curl -X POST "$BASE_URL/usage/fetch" \
  -H "Content-Type: application/json" \
  -H "x-analytics-token: $TOKEN" \
  -d "{\"user_key\":\"$USER\",\"plan\":\"free\"}" -s | jq .
echo ""

echo "4️⃣ Credit 3-hour top-up (10800 seconds):"
curl -X POST "$BASE_URL/usage/topup" \
  -H "Content-Type: application/json" \
  -H "x-analytics-token: $TOKEN" \
  -d "{\"user_key\":\"$USER\",\"seconds\":10800,\"transaction_id\":\"txn_test_$(date +%s)\"}" -s | jq .
echo ""

echo "5️⃣ Fetch after top-up (should have 10800 top-up balance):"
curl -X POST "$BASE_URL/usage/fetch" \
  -H "Content-Type: application/json" \
  -H "x-analytics-token: $TOKEN" \
  -d "{\"user_key\":\"$USER\",\"plan\":\"free\"}" -s | jq .
echo ""

echo "✅ Complete flow test finished!"
