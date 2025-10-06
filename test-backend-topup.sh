#!/bin/bash

# Test script for 3-hour top-up backend integration
# Usage: ./test-backend-topup.sh

# Configuration
PROJECT_REF="rhfhateyqdiysgooiqtd"
ANALYTICS_TOKEN="your_analytics_token_here"  # Replace with actual token
TEST_USER_KEY="test_user_$(date +%s)"
TEST_TRANSACTION_ID="test_txn_$(date +%s)"

echo "🧪 Testing Backend Top-Up Integration"
echo "======================================"
echo "Project: $PROJECT_REF"
echo "Test User: $TEST_USER_KEY"
echo "Transaction: $TEST_TRANSACTION_ID"
echo ""

# Base URLs
INGEST_URL="https://${PROJECT_REF}.supabase.co/functions/v1/ingest"
TOPUP_URL="https://${PROJECT_REF}.supabase.co/functions/v1/usage-credit-topup"

echo "📋 Test 1: Check initial usage (should return defaults for new user)"
echo "----------------------------------------------------------------------"
curl -X POST "$INGEST_URL/usage/check" \
  -H "Content-Type: application/json" \
  -H "x-analytics-token: $ANALYTICS_TOKEN" \
  -d "{\"user_key\": \"$TEST_USER_KEY\"}" \
  -w "\nHTTP Status: %{http_code}\n" \
  -s | jq .

echo ""
echo "💳 Test 2: Credit 3-hour purchase (10800 seconds)"
echo "----------------------------------------------------------------------"
curl -X POST "$TOPUP_URL" \
  -H "Content-Type: application/json" \
  -H "x-analytics-token: $ANALYTICS_TOKEN" \
  -d "{
    \"user_key\": \"$TEST_USER_KEY\",
    \"seconds\": 10800,
    \"transaction_id\": \"$TEST_TRANSACTION_ID\",
    \"price_paid\": 9.99,
    \"currency\": \"EUR\"
  }" \
  -w "\nHTTP Status: %{http_code}\n" \
  -s | jq .

echo ""
echo "📊 Test 3: Check usage after purchase (should show 10800 available)"
echo "----------------------------------------------------------------------"
curl -X POST "$INGEST_URL/usage/check" \
  -H "Content-Type: application/json" \
  -H "x-analytics-token: $ANALYTICS_TOKEN" \
  -d "{\"user_key\": \"$TEST_USER_KEY\"}" \
  -w "\nHTTP Status: %{http_code}\n" \
  -s | jq .

echo ""
echo "🎙️  Test 4: Book 600 seconds of recording (should deduct from top-up)"
echo "----------------------------------------------------------------------"
curl -X POST "$INGEST_URL/usage/book" \
  -H "Content-Type: application/json" \
  -H "x-analytics-token: $ANALYTICS_TOKEN" \
  -d "{
    \"user_key\": \"$TEST_USER_KEY\",
    \"seconds\": 600,
    \"plan\": \"free\"
  }" \
  -w "\nHTTP Status: %{http_code}\n" \
  -s | jq .

echo ""
echo "📊 Test 5: Check usage after recording (should show 10200 available)"
echo "----------------------------------------------------------------------"
curl -X POST "$INGEST_URL/usage/check" \
  -H "Content-Type: application/json" \
  -H "x-analytics-token: $ANALYTICS_TOKEN" \
  -d "{\"user_key\": \"$TEST_USER_KEY\"}" \
  -w "\nHTTP Status: %{http_code}\n" \
  -s | jq .

echo ""
echo "🔁 Test 6: Idempotency - Try crediting same transaction again"
echo "----------------------------------------------------------------------"
curl -X POST "$TOPUP_URL" \
  -H "Content-Type: application/json" \
  -H "x-analytics-token: $ANALYTICS_TOKEN" \
  -d "{
    \"user_key\": \"$TEST_USER_KEY\",
    \"seconds\": 10800,
    \"transaction_id\": \"$TEST_TRANSACTION_ID\",
    \"price_paid\": 9.99,
    \"currency\": \"EUR\"
  }" \
  -w "\nHTTP Status: %{http_code}\n" \
  -s | jq .

echo ""
echo "📋 Test 7: Fetch full usage record"
echo "----------------------------------------------------------------------"
curl -X POST "$INGEST_URL/usage/fetch" \
  -H "Content-Type: application/json" \
  -H "x-analytics-token: $ANALYTICS_TOKEN" \
  -d "{\"user_key\": \"$TEST_USER_KEY\"}" \
  -w "\nHTTP Status: %{http_code}\n" \
  -s | jq .

echo ""
echo "✅ Tests complete!"
echo ""
echo "Expected results:"
echo "  Test 1: secondsUsed=0, limitSeconds=1800 (free tier)"
echo "  Test 2: success=true, new_topup_balance=10800"
echo "  Test 3: secondsUsed=0, limitSeconds=12600 (1800+10800)"
echo "  Test 4: success=true, topup_used=600"
echo "  Test 5: secondsUsed=0, limitSeconds=12000 (1800+10200)"
echo "  Test 6: message='Purchase already credited', same balance"
echo "  Test 7: Full record with topup_seconds_available=10200"
