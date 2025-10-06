-- Migration: Add Top-Up Purchase Support
-- Created: 2025-01-04
-- Purpose: Add support for consumable in-app purchases (3-hour top-ups)

-- 1. Create topup_purchases table for tracking consumable purchases
CREATE TABLE IF NOT EXISTS topup_purchases (
  transaction_id VARCHAR(255) PRIMARY KEY,
  user_key VARCHAR(255) NOT NULL,
  seconds_credited INT NOT NULL,
  purchased_at TIMESTAMP NOT NULL DEFAULT NOW(),

  -- Metadata
  product_id VARCHAR(100) DEFAULT 'com.kinder.echo.3hours',
  price_paid DECIMAL(10, 2),
  currency VARCHAR(3)
);

-- Index for looking up purchases by user
CREATE INDEX IF NOT EXISTS idx_topup_purchases_user_key
  ON topup_purchases(user_key);

-- Index for sorting by date
CREATE INDEX IF NOT EXISTS idx_topup_purchases_purchased_at
  ON topup_purchases(purchased_at DESC);

-- 2. Add topup_seconds_available column to user_usage
ALTER TABLE user_usage
  ADD COLUMN IF NOT EXISTS topup_seconds_available INT DEFAULT 0;

-- Add comment explaining the column
COMMENT ON COLUMN user_usage.topup_seconds_available IS
  'Remaining seconds from consumable top-up purchases. Does not reset monthly.';

-- 3. Update the check_usage view to include top-up balance
CREATE OR REPLACE VIEW user_usage_with_topups AS
SELECT
  user_key,
  plan,
  subscription_seconds_limit,
  topup_seconds_available,
  seconds_used_this_month,

  -- Calculate total available (subscription remaining + top-ups)
  (subscription_seconds_limit - seconds_used_this_month) + topup_seconds_available
    AS total_seconds_available,

  -- Calculate total used
  seconds_used_this_month,

  -- Calculate total limit (subscription + top-ups)
  subscription_seconds_limit + topup_seconds_available AS total_limit,

  month_year,
  updated_at
FROM user_usage;

-- 4. Function to deduct usage (prefers subscription quota first, then top-ups)
CREATE OR REPLACE FUNCTION deduct_usage(
  p_user_key VARCHAR,
  p_seconds INT
) RETURNS TABLE(
  success BOOLEAN,
  subscription_used INT,
  topup_used INT,
  message TEXT
) AS $$
DECLARE
  v_sub_limit INT;
  v_sub_used INT;
  v_topup_available INT;
  v_sub_remaining INT;
  v_total_available INT;
  v_sub_to_deduct INT := 0;
  v_topup_to_deduct INT := 0;
BEGIN
  -- Get current usage
  SELECT
    subscription_seconds_limit,
    seconds_used_this_month,
    topup_seconds_available
  INTO v_sub_limit, v_sub_used, v_topup_available
  FROM user_usage
  WHERE user_key = p_user_key;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, 0, 0, 'User not found';
    RETURN;
  END IF;

  -- Calculate available seconds
  v_sub_remaining := v_sub_limit - v_sub_used;
  v_total_available := v_sub_remaining + v_topup_available;

  -- Check if enough balance
  IF p_seconds > v_total_available THEN
    RETURN QUERY SELECT FALSE, 0, 0, 'Insufficient balance';
    RETURN;
  END IF;

  -- Deduct from subscription first
  IF p_seconds <= v_sub_remaining THEN
    -- All from subscription
    v_sub_to_deduct := p_seconds;
    v_topup_to_deduct := 0;
  ELSE
    -- Use all remaining subscription, rest from top-up
    v_sub_to_deduct := v_sub_remaining;
    v_topup_to_deduct := p_seconds - v_sub_remaining;
  END IF;

  -- Update the usage
  UPDATE user_usage
  SET
    seconds_used_this_month = seconds_used_this_month + v_sub_to_deduct,
    topup_seconds_available = topup_seconds_available - v_topup_to_deduct,
    updated_at = NOW()
  WHERE user_key = p_user_key;

  RETURN QUERY SELECT TRUE, v_sub_to_deduct, v_topup_to_deduct, 'Success';
END;
$$ LANGUAGE plpgsql;

-- 5. Add RLS policies for topup_purchases (if using RLS)
-- Note: Adjust these based on your auth setup

-- Allow service role to insert (from edge function)
-- Users should be able to view their own purchases

-- Example policies (adjust as needed):
-- ALTER TABLE topup_purchases ENABLE ROW LEVEL SECURITY;

-- CREATE POLICY "Service role can insert purchases"
--   ON topup_purchases FOR INSERT
--   TO service_role
--   WITH CHECK (true);

-- CREATE POLICY "Users can view their own purchases"
--   ON topup_purchases FOR SELECT
--   USING (user_key = current_setting('app.current_user_key', true));

-- 6. Create a function to get total available seconds (for the check endpoint)
CREATE OR REPLACE FUNCTION get_user_available_seconds(p_user_key VARCHAR)
RETURNS TABLE(
  seconds_used INT,
  limit_seconds INT,
  topup_seconds INT,
  total_available INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    seconds_used_this_month,
    subscription_seconds_limit,
    topup_seconds_available,
    (subscription_seconds_limit - seconds_used_this_month) + topup_seconds_available
  FROM user_usage
  WHERE user_key = p_user_key;
END;
$$ LANGUAGE plpgsql;

-- 7. Add some helpful indices for analytics
CREATE INDEX IF NOT EXISTS idx_user_usage_topup_balance
  ON user_usage(topup_seconds_available)
  WHERE topup_seconds_available > 0;

-- Done!
-- This migration adds full support for consumable top-up purchases
