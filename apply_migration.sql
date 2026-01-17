-- Complete migration script for Supabase Dashboard
-- Copy and paste this entire file into: https://supabase.com/dashboard/project/rhfhateyqdiysgooiqtd/sql

-- Step 1: Clean up old schema
DROP VIEW IF EXISTS public.user_usage_with_remaining CASCADE;
DROP FUNCTION IF EXISTS public.book_usage CASCADE;
DROP FUNCTION IF EXISTS public.fetch_usage CASCADE;
DROP TABLE IF EXISTS public.user_usage CASCADE;
DROP TABLE IF EXISTS public.topup_purchases CASCADE;
DROP TABLE IF EXISTS public.plan_limits CASCADE;

-- Step 2: Apply new schema

-- 1. Create plan_limits table
CREATE TABLE IF NOT EXISTS public.plan_limits (
  plan VARCHAR(50) PRIMARY KEY,
  limit_seconds INT NOT NULL
);

-- Seed plan limits
INSERT INTO public.plan_limits (plan, limit_seconds) VALUES
  ('free', 1800),       -- 30 minutes
  ('standard', 7200),   -- 120 minutes
  ('premium', 36000),   -- 600 minutes
  ('own_key', 600000)   -- 10,000 minutes
ON CONFLICT (plan) DO UPDATE SET limit_seconds = EXCLUDED.limit_seconds;

-- 2. Create user_usage table
CREATE TABLE IF NOT EXISTS public.user_usage (
  user_key VARCHAR(255) NOT NULL,
  period_ym VARCHAR(7) NOT NULL,  -- Format: YYYY-MM (UTC)
  plan VARCHAR(50) NOT NULL DEFAULT 'free',
  seconds_used INT NOT NULL DEFAULT 0,
  topup_seconds_available INT NOT NULL DEFAULT 0,  -- Top-up balance (doesn't reset monthly)
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  PRIMARY KEY (user_key, period_ym),
  FOREIGN KEY (plan) REFERENCES public.plan_limits(plan)
);

-- Indices
CREATE INDEX IF NOT EXISTS idx_user_usage_user_key ON public.user_usage(user_key);
CREATE INDEX IF NOT EXISTS idx_user_usage_period ON public.user_usage(period_ym);

-- 3. Create topup_purchases table (for tracking consumable in-app purchases)
CREATE TABLE IF NOT EXISTS public.topup_purchases (
  transaction_id VARCHAR(255) PRIMARY KEY,
  user_key VARCHAR(255) NOT NULL,
  seconds_credited INT NOT NULL,
  purchased_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  product_id VARCHAR(100) DEFAULT 'com.kinder.echo.3hours',
  price_paid DECIMAL(10, 2),
  currency VARCHAR(3)
);

-- Indices for topup_purchases
CREATE INDEX IF NOT EXISTS idx_topup_purchases_user_key ON public.topup_purchases(user_key);
CREATE INDEX IF NOT EXISTS idx_topup_purchases_date ON public.topup_purchases(purchased_at DESC);

-- 4. Create book_usage RPC function (atomic increment)
CREATE OR REPLACE FUNCTION public.book_usage(
  p_user_key TEXT,
  p_seconds INT,
  p_recorded_at TIMESTAMPTZ,
  p_plan TEXT DEFAULT 'free'
) RETURNS TABLE(
  success BOOLEAN,
  seconds_used INT,
  limit_seconds INT,
  remaining_seconds INT
) AS $$
DECLARE
  v_period_ym VARCHAR(7);
  v_plan VARCHAR(50);
  v_limit INT;
  v_current_used INT;
  v_new_used INT;
  v_remaining INT;
BEGIN
  -- Calculate period from recorded_at (UTC)
  v_period_ym := TO_CHAR(p_recorded_at AT TIME ZONE 'UTC', 'YYYY-MM');

  -- Get plan limit
  SELECT limit_seconds INTO v_limit
  FROM public.plan_limits
  WHERE plan = p_plan;

  -- Default to free tier if plan not found
  IF v_limit IS NULL THEN
    v_limit := 1800;
    v_plan := 'free';
  ELSE
    v_plan := p_plan;
  END IF;

  -- Insert or update atomically
  INSERT INTO public.user_usage (user_key, period_ym, plan, seconds_used, updated_at)
  VALUES (p_user_key, v_period_ym, v_plan, p_seconds, NOW())
  ON CONFLICT (user_key, period_ym)
  DO UPDATE SET
    seconds_used = public.user_usage.seconds_used + p_seconds,
    updated_at = NOW()
  RETURNING public.user_usage.seconds_used INTO v_new_used;

  -- Calculate remaining
  v_remaining := GREATEST(v_limit - v_new_used, 0);

  -- Return result
  RETURN QUERY SELECT
    TRUE::BOOLEAN,
    v_new_used,
    v_limit,
    v_remaining;
END;
$$ LANGUAGE plpgsql;

-- 5. Create fetch_usage RPC function (get current usage for a user)
CREATE OR REPLACE FUNCTION public.fetch_usage(
  p_user_key TEXT,
  p_plan TEXT DEFAULT 'free'
) RETURNS TABLE(
  seconds_used INT,
  limit_seconds INT,
  remaining_seconds INT,
  topup_seconds_available INT
) AS $$
DECLARE
  v_period_ym VARCHAR(7);
  v_limit INT;
BEGIN
  -- Calculate current period (UTC)
  v_period_ym := TO_CHAR(NOW() AT TIME ZONE 'UTC', 'YYYY-MM');

  -- Get plan limit
  SELECT pl.limit_seconds INTO v_limit
  FROM public.plan_limits pl
  WHERE pl.plan = p_plan;

  -- Default to free tier if plan not found
  IF v_limit IS NULL THEN
    v_limit := 1800;
  END IF;

  -- Return current usage from view
  RETURN QUERY
  SELECT
    COALESCE(u.seconds_used, 0)::INT,
    v_limit::INT,
    (GREATEST(v_limit - COALESCE(u.seconds_used, 0), 0) + COALESCE(u.topup_seconds_available, 0))::INT,
    COALESCE(u.topup_seconds_available, 0)::INT
  FROM public.user_usage u
  WHERE u.user_key = p_user_key
    AND u.period_ym = v_period_ym
  LIMIT 1;

  -- If no record exists, return defaults
  IF NOT FOUND THEN
    RETURN QUERY SELECT 0::INT, v_limit::INT, v_limit::INT, 0::INT;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- 6. Create view with remaining seconds (includes top-up balance)
CREATE OR REPLACE VIEW public.user_usage_with_remaining AS
SELECT
  u.user_key,
  u.period_ym,
  u.plan,
  u.seconds_used,
  u.topup_seconds_available,
  u.updated_at,
  p.limit_seconds,
  -- Total limit = subscription limit + top-up balance
  p.limit_seconds + u.topup_seconds_available AS total_limit,
  -- Remaining = (subscription limit - used) + top-up balance
  GREATEST(p.limit_seconds - u.seconds_used, 0) + u.topup_seconds_available AS remaining_seconds
FROM public.user_usage u
JOIN public.plan_limits p ON u.plan = p.plan;

-- Comments
COMMENT ON TABLE public.user_usage IS 'Tracks monthly usage quota for each user (real backend data)';
COMMENT ON TABLE public.plan_limits IS 'Defines quota limits for each subscription plan';
COMMENT ON TABLE public.topup_purchases IS 'Tracks consumable in-app purchase transactions (3-hour top-ups)';
COMMENT ON COLUMN public.user_usage.topup_seconds_available IS 'Remaining seconds from top-up purchases (does not reset monthly)';
COMMENT ON FUNCTION public.book_usage IS 'Atomically books usage seconds for a user in a given period';
COMMENT ON FUNCTION public.fetch_usage IS 'Fetches current usage for a user with calculated remaining seconds';
COMMENT ON VIEW public.user_usage_with_remaining IS 'User usage with calculated remaining seconds (includes top-up balance)';
