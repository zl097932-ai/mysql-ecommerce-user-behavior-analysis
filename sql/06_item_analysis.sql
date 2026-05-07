-- 06_item_analysis.sql

-- =========================
-- 6. 商品分析
-- =========================

-- 最受欢迎的商品：所有行为总量最多
-- 业务问题：哪些商品获得的用户行为总量最高，整体关注度最强？
-- 分析目的：按商品统计所有行为次数，识别高曝光、高互动的热门商品。
SELECT
  item_id,
  COUNT(*) AS item_behavior_total
FROM userbehavior_clean
GROUP BY item_id
ORDER BY item_behavior_total DESC
LIMIT 10;

-- 最热销的商品
-- 业务问题：哪些商品实际购买次数最多，销售表现最好？
-- 分析目的：基于购买行为统计热销商品，为爆品识别、库存管理和重点推荐提供依据。
SELECT
  item_id,
  COUNT(*) AS item_buy_count
FROM userbehavior_clean
WHERE behavior_type = 'buy'
GROUP BY item_id
ORDER BY item_buy_count DESC
LIMIT 10;

-- 最有潜力的商品：加购和收藏量最多
-- 业务问题：哪些商品被大量收藏或加购，具备较强购买意向但未必已充分转化？
-- 分析目的：统计收藏和加购行为最多的商品，识别适合促销转化的潜力商品。
SELECT
  item_id,
  COUNT(*) AS item_cart_fav_count
FROM userbehavior_clean
WHERE behavior_type IN ('cart', 'fav')
GROUP BY item_id
ORDER BY item_cart_fav_count DESC
LIMIT 10;

-- 商品转化率
-- 业务问题：哪些商品在获得一定浏览量后，购买转化效率最高？
-- 分析目的：计算商品购买次数与浏览次数的比值，筛选高转化商品，避免只看销量忽略流量基础。
SELECT
  item_id,
  SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END) AS pv_count,
  SUM(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS buy_count,
  ROUND(
    SUM(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END)
    / NULLIF(SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END), 0),
    4
  ) AS item_buy_rate
FROM userbehavior_clean
GROUP BY item_id
HAVING pv_count > 100
   AND buy_count > 10
ORDER BY item_buy_rate DESC
LIMIT 10;
