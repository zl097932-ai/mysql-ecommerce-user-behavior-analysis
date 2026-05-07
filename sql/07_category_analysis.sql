-- 07_category_analysis.sql

-- =========================
-- 7. 类目分析
-- =========================

-- 最受欢迎的类目：所有行为总量最多
-- 业务问题：哪些商品类目获得的用户行为总量最高，整体关注度最强？
-- 分析目的：按类目统计所有行为次数，识别平台流量和互动最集中的类目。
SELECT
  category_id,
  COUNT(*) AS category_behavior_total
FROM userbehavior_clean
GROUP BY category_id
ORDER BY category_behavior_total DESC
LIMIT 10;

-- 最热销的类目
-- 业务问题：哪些商品类目的购买次数最多，销售表现最好？
-- 分析目的：基于购买行为统计热销类目，为类目运营和资源分配提供依据。
SELECT
  category_id,
  COUNT(*) AS category_buy_count
FROM userbehavior_clean
WHERE behavior_type = 'buy'
GROUP BY category_id
ORDER BY category_buy_count DESC
LIMIT 10;

-- 最有潜力的类目：加购和收藏量最多
-- 业务问题：哪些类目收藏和加购行为较多，存在较强潜在购买需求？
-- 分析目的：统计收藏和加购行为最多的类目，识别适合重点促销或优化转化的潜力类目。
SELECT
  category_id,
  COUNT(*) AS category_cart_fav_count
FROM userbehavior_clean
WHERE behavior_type IN ('cart', 'fav')
GROUP BY category_id
ORDER BY category_cart_fav_count DESC
LIMIT 10;

-- 类目转化率
-- 业务问题：哪些类目在获得一定浏览量后，购买转化效率最高？
-- 分析目的：计算类目购买次数与浏览次数的比值，识别高转化类目，为类目运营策略提供依据。
SELECT
  category_id,
  SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END) AS pv_count,
  SUM(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS buy_count,
  ROUND(
    SUM(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END)
    / NULLIF(SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END), 0),
    4
  ) AS category_buy_rate
FROM userbehavior_clean
GROUP BY category_id
HAVING pv_count > 100
   AND buy_count > 10
ORDER BY category_buy_rate DESC
LIMIT 10;
