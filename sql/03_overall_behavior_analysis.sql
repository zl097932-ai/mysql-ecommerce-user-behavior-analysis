-- 03_overall_behavior_analysis.sql

-- =========================
-- 3. 整体行为分析
-- =========================

-- 各行为占比
-- 业务问题：用户在平台上的主要行为类型是什么，各类行为在整体行为中占比如何？
-- 分析目的：评估浏览、收藏、加购、购买行为结构，判断用户行为是否集中在浏览阶段。
SELECT
  behavior_type,
  COUNT(*) AS behavior_count,
  SUM(COUNT(*)) OVER () AS total_count,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER (), 4) AS behavior_ratio
FROM userbehavior_clean
GROUP BY behavior_type
ORDER BY behavior_count DESC;

-- PV、UV、购买次数、购买用户数、整体购买转化率
-- 业务问题：平台整体流量规模、用户规模和购买转化水平如何？
-- 分析目的：统计 PV、UV、购买次数、购买用户数和用户购买转化率，建立整体经营指标概览。
SELECT
  COUNT(CASE WHEN behavior_type = 'pv' THEN 1 END) AS pv_count,
  COUNT(DISTINCT user_id) AS uv_count,
  COUNT(CASE WHEN behavior_type = 'buy' THEN 1 END) AS buy_count,
  COUNT(DISTINCT CASE WHEN behavior_type = 'buy' THEN user_id END) AS buy_user_count,
  ROUND(
    COUNT(DISTINCT CASE WHEN behavior_type = 'buy' THEN user_id END)
    / NULLIF(COUNT(DISTINCT user_id), 0),
    4
  ) AS user_buy_rate
FROM userbehavior_clean;

-- 每日行为趋势
-- 业务问题：不同日期的用户行为是否存在波动，哪些日期活跃度或购买行为更高？
-- 分析目的：按天观察各行为次数和行为用户数变化，为后续活动节奏和时间趋势分析提供依据。
SELECT
  DATE(event_time) AS event_date,
  behavior_type,
  COUNT(*) AS behavior_count,
  COUNT(DISTINCT user_id) AS user_count
FROM userbehavior_clean
GROUP BY DATE(event_time), behavior_type
ORDER BY event_date, behavior_type;