-- 05_user_analysis.sql

-- =========================
-- 5. 用户分析
-- =========================

-- 用户活跃度 TOP 20
-- 业务问题：哪些用户在分析周期内行为次数最多，属于高活跃用户？
-- 分析目的：识别活跃度最高的用户群体，为后续用户分层和精细化运营提供候选对象。
SELECT
  user_id,
  COUNT(*) AS user_activity
FROM userbehavior_clean
GROUP BY user_id
ORDER BY user_activity DESC
LIMIT 20;

-- 用户活跃度 TOP 20 行为拆分
-- 业务问题：高活跃用户的行为结构是什么，他们是浏览型、加购型还是购买型用户？
-- 分析目的：拆分 TOP20 活跃用户的浏览、收藏、加购和购买次数，判断活跃度是否能转化为购买价值。
SELECT
  user_id,
  COUNT(*) AS total_behavior_count,
  SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END) AS pv_count,
  SUM(CASE WHEN behavior_type = 'fav' THEN 1 ELSE 0 END) AS fav_count,
  SUM(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS cart_count,
  SUM(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS buy_count
FROM userbehavior_clean
GROUP BY user_id
ORDER BY total_behavior_count DESC
LIMIT 20;

-- 不同小时段内用户行为
-- 业务问题：一天中不同小时段的用户行为分布如何？
-- 分析目的：按小时和行为类型统计行为次数与用户数，观察各时段用户活跃规律。
SELECT
  HOUR(event_time) AS event_hour,
  behavior_type,
  COUNT(*) AS behavior_count,
  COUNT(DISTINCT user_id) AS user_count
FROM userbehavior_clean
GROUP BY HOUR(event_time), behavior_type
ORDER BY event_hour, behavior_type;

-- 各行为高峰时段
-- 业务问题：不同类型行为分别集中在哪些小时段发生？
-- 分析目的：按行为类型找出高峰时段，为收藏、加购、购买等运营触达时间选择提供依据。
SELECT
  HOUR(event_time) AS event_hour,
  behavior_type,
  COUNT(*) AS behavior_count,
  COUNT(DISTINCT user_id) AS user_count
FROM userbehavior_clean
GROUP BY HOUR(event_time), behavior_type
ORDER BY behavior_type, behavior_count DESC;

-- 整体用户行为高峰期
-- 业务问题：平台整体用户活跃高峰集中在一天中的哪些小时？
-- 分析目的：识别整体行为量最高的时间段，为活动投放、消息推送和资源排班提供参考。
SELECT
  HOUR(event_time) AS event_hour,
  COUNT(*) AS behavior_count,
  COUNT(DISTINCT user_id) AS user_count
FROM userbehavior_clean
GROUP BY HOUR(event_time)
ORDER BY behavior_count DESC;

-- 用户行为汇总，为分层做准备
-- 业务问题：每个用户在分析周期内的完整行为画像是什么？
-- 分析目的：汇总用户级浏览、收藏、加购、购买次数和最近行为时间，为用户分层提供基础宽表。
CREATE OR REPLACE VIEW user_behavior_summary AS
SELECT
  user_id,
  COUNT(*) AS total_behavior_count,
  SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END) AS pv_count,
  SUM(CASE WHEN behavior_type = 'fav' THEN 1 ELSE 0 END) AS fav_count,
  SUM(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS cart_count,
  SUM(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS buy_count,
  MIN(event_time) AS first_event_time,
  MAX(event_time) AS last_event_time,
  MAX(CASE WHEN behavior_type = 'buy' THEN event_time END) AS last_buy_time
FROM userbehavior_clean
GROUP BY user_id;

-- 高价值用户：购买次数 >= 10
-- 业务问题：哪些用户购买频次较高，可能是平台的核心价值用户？
-- 分析目的：筛选购买次数达到 10 次及以上的用户，为会员维护、复购激励和重点运营提供名单。
SELECT
  user_id,
  buy_count,
  total_behavior_count,
  last_buy_time
FROM user_behavior_summary
WHERE buy_count >= 10
ORDER BY buy_count DESC;

-- 潜力用户：有加购或收藏，但没有购买
-- 业务问题：哪些用户已经表现出购买兴趣，但尚未完成购买？
-- 分析目的：识别有收藏或加购但未购买的潜在转化用户，为优惠券、降价提醒和购物车召回提供依据。
SELECT
  user_id,
  cart_count,
  fav_count,
  total_behavior_count,
  last_event_time
FROM user_behavior_summary
WHERE buy_count = 0
  AND (cart_count > 0 OR fav_count > 0)
ORDER BY cart_count + fav_count DESC;

-- 浏览用户：只有 pv 行为
-- 业务问题：哪些用户只浏览商品，没有产生收藏、加购或购买等进一步行为？
-- 分析目的：识别低意向浏览用户，评估流量质量，并为后续提升商品吸引力和推荐精准度提供参考。
SELECT
  user_id,
  pv_count
FROM user_behavior_summary
WHERE pv_count > 0
  AND fav_count = 0
  AND cart_count = 0
  AND buy_count = 0
ORDER BY pv_count DESC;