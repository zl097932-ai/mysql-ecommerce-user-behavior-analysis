-- 04_conversion_funnel_analysis.sql

-- =========================
-- 4. 漏斗分析
-- =========================

-- 行为次数漏斗
-- 业务问题：从浏览到收藏、加购、购买的行为次数流失情况如何？
-- 分析目的：构建行为次数漏斗，评估用户行为从浏览到购买的转化效率和关键流失环节。
SELECT
  SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END) AS pv_count,
  SUM(CASE WHEN behavior_type = 'fav' THEN 1 ELSE 0 END) AS fav_count,
  SUM(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS cart_count,
  SUM(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS buy_count,
  ROUND(
    SUM(CASE WHEN behavior_type = 'fav' THEN 1 ELSE 0 END)
    / NULLIF(SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END), 0),
    4
  ) AS fav_to_pv_rate,
  ROUND(
    SUM(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END)
    / NULLIF(SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END), 0),
    4
  ) AS cart_to_pv_rate,
  ROUND(
    SUM(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END)
    / NULLIF(SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END), 0),
    4
  ) AS buy_to_pv_rate,
  ROUND(
    SUM(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END)
    / NULLIF(SUM(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END), 0),
    4
  ) AS buy_to_cart_rate
FROM userbehavior_clean;

-- 用户人数漏斗
-- 业务问题：有多少用户进入浏览、收藏、加购、购买等不同转化阶段？
-- 分析目的：基于用户去重口径构建用户人数漏斗，衡量用户层面的转化覆盖情况。
CREATE OR REPLACE VIEW user_behavior_funnel AS
SELECT
  COUNT(DISTINCT CASE WHEN behavior_type = 'pv' THEN user_id END) AS pv_users,
  COUNT(DISTINCT CASE WHEN behavior_type = 'fav' THEN user_id END) AS fav_users,
  COUNT(DISTINCT CASE WHEN behavior_type = 'cart' THEN user_id END) AS cart_users,
  COUNT(DISTINCT CASE WHEN behavior_type = 'buy' THEN user_id END) AS buy_users
FROM userbehavior_clean;

SELECT
  pv_users,
  fav_users,
  cart_users,
  buy_users,
  ROUND(fav_users / NULLIF(pv_users, 0), 4) AS fav_user_rate,
  ROUND(cart_users / NULLIF(pv_users, 0), 4) AS cart_user_rate,
  ROUND(buy_users / NULLIF(pv_users, 0), 4) AS buy_user_rate,
  ROUND(buy_users / NULLIF(cart_users, 0), 4) AS cart_to_buy_user_rate
FROM user_behavior_funnel;