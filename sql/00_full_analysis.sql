-- 本脚本基于 MySQL 8.0 编写，部分函数和语法如 FROM_UNIXTIME、UNIX_TIMESTAMP、LIMIT、ADD INDEX 为 MySQL 方言。
-- 说明：如果 userbehavior_clean 和各类汇总表已经生成，日常查看分析结果时可跳过第 0-2.1 部分，直接执行第 3-8 部分。


-- =========================
-- 0. 初始化设置
-- =========================
-- 设置 MySQL 会话时区，保证 FROM_UNIXTIME 和 UNIX_TIMESTAMP 的时间转换结果一致。
-- 清理上一次运行生成的视图和清洗表，避免重复执行脚本时报错。
-- 注意：这里只删除分析过程中生成的中间表和视图，不会删除原始导入表 userbehavior。

SET time_zone = '+08:00';

DROP VIEW IF EXISTS user_behavior_funnel;
DROP VIEW IF EXISTS user_behavior_summary;
DROP VIEW IF EXISTS user_purchase_summary;

DROP TABLE IF EXISTS userbehavior_clean;

-- =========================
-- 1. 数据质量检查
-- =========================

-- 查询数据总量和缺失值
-- 业务问题：原始数据是否存在关键字段缺失，是否会影响后续用户、商品和行为分析？
-- 分析目的：统计原始数据总量和各字段缺失数量，判断是否需要在清洗阶段过滤缺失记录。
SELECT
  COUNT(*) AS total_rows,
  COUNT(*) - COUNT(user_id) AS missing_user_id,
  COUNT(*) - COUNT(item_id) AS missing_item_id,
  COUNT(*) - COUNT(category_id) AS missing_category_id,
  COUNT(*) - COUNT(behavior_type) AS missing_behavior_type,
  COUNT(*) - COUNT(time_stamp) AS missing_time_stamp
FROM userbehavior;

-- 检查行为类型是否异常
-- 业务问题：用户行为类型是否都属于 pv、fav、cart、buy 四类，是否存在异常行为值？
-- 分析目的：验证 behavior_type 字段的数据规范性，避免异常行为类型干扰后续转化和分层分析。
SELECT
  behavior_type,
  COUNT(*) AS cnt
FROM userbehavior
GROUP BY behavior_type
ORDER BY cnt DESC;

-- 检查时间戳范围
-- 业务问题：原始数据覆盖的时间范围是否符合项目分析周期？
-- 分析目的：查看原始时间戳对应的最早和最晚行为时间，为后续时间过滤提供依据。
SELECT
  MIN(FROM_UNIXTIME(time_stamp)) AS min_event_time,
  MAX(FROM_UNIXTIME(time_stamp)) AS max_event_time
FROM userbehavior;

-- 查询重复行，先观察重复情况
-- 业务问题：原始行为日志是否存在完全重复记录，是否会导致行为次数、转化率等指标被高估？
-- 分析目的：识别重复记录规模和样例，为后续去重生成清洗表提供依据。
SELECT
  user_id,
  item_id,
  category_id,
  behavior_type,
  time_stamp,
  COUNT(*) AS duplicate_count
FROM userbehavior
GROUP BY user_id, item_id, category_id, behavior_type, time_stamp
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;


-- =========================
-- 2. 清洗并生成分析表
-- =========================
-- 不直接改动导入原表 userbehavior，而是生成清洗后的 userbehavior_clean。
-- 后续所有分析都基于 userbehavior_clean。
-- 业务问题：如何在保留原始数据的同时，得到一张适合分析的干净行为明细表？
-- 分析目的：过滤缺失值、异常行为类型和目标时间范围外的数据，并对完全重复记录去重。

CREATE TABLE userbehavior_clean AS
SELECT DISTINCT
  user_id,
  item_id,
  category_id,
  behavior_type,
  time_stamp,
  FROM_UNIXTIME(time_stamp) AS event_time
FROM userbehavior
WHERE user_id IS NOT NULL
  AND item_id IS NOT NULL
  AND category_id IS NOT NULL
  AND behavior_type IS NOT NULL
  AND time_stamp IS NOT NULL
  AND behavior_type IN ('pv', 'fav', 'cart', 'buy')
  AND time_stamp BETWEEN UNIX_TIMESTAMP('2017-11-25 00:00:00')
                     AND UNIX_TIMESTAMP('2017-12-03 23:59:59');

-- 为清洗表添加索引，提升 3000 万数据量下的查询速度
-- 业务问题：在 3000 万级数据量下，如何提升用户、时间、商品和类目维度查询效率？
-- 分析目的：为高频分组、筛选和排序字段添加索引，降低后续分析查询耗时。
ALTER TABLE userbehavior_clean
  ADD INDEX idx_user_time (user_id, event_time),
  ADD INDEX idx_behavior_time (behavior_type, event_time),
  ADD INDEX idx_item_behavior (item_id, behavior_type),
  ADD INDEX idx_category_behavior (category_id, behavior_type),
  ADD INDEX idx_item_time (item_id, event_time),
  ADD INDEX idx_category_time (category_id, event_time);

-- 检查清洗前后数据量
-- 业务问题：经过缺失值过滤、异常行为过滤、时间过滤和去重后，实际保留了多少有效数据？
-- 分析目的：对比清洗前后数据量，量化被剔除的数据规模，评估清洗影响。
SELECT
  (SELECT COUNT(*) FROM userbehavior) AS raw_rows,
  (SELECT COUNT(*) FROM userbehavior_clean) AS clean_rows,
  (SELECT COUNT(*) FROM userbehavior) - (SELECT COUNT(*) FROM userbehavior_clean) AS removed_rows;

-- 检查清洗后的时间范围，应为 2017-11-25 至 2017-12-03
-- 业务问题：清洗后的数据是否严格限定在 2017-11-25 至 2017-12-03 的分析周期内？
-- 分析目的：验证时间过滤结果，确保后续所有分析口径基于同一时间窗口。
SELECT
  MIN(event_time) AS clean_min_event_time,
  MAX(event_time) AS clean_max_event_time
FROM userbehavior_clean;

-- 查看清洗后的数据
-- 业务问题：清洗表字段和样例数据是否符合后续分析要求？
-- 分析目的：抽样查看清洗后的明细记录，确认字段、时间格式和行为类型正常。
SELECT *
FROM userbehavior_clean
LIMIT 10;


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


-- =========================
-- 8. 复购分析
-- =========================

-- 每个用户的购买情况
-- 业务问题：每个购买用户在分析周期内购买了多少次？
-- 分析目的：生成用户购买次数汇总视图，为复购率计算和购买用户价值判断提供基础。
CREATE OR REPLACE VIEW user_purchase_summary AS
SELECT
  user_id,
  COUNT(*) AS buy_count
FROM userbehavior_clean
WHERE behavior_type = 'buy'
GROUP BY user_id;

-- 复购率：购买 2 次及以上的用户 / 购买用户
-- 业务问题：购买用户中有多少人发生了重复购买，用户复购能力如何？
-- 分析目的：计算购买 2 次及以上用户占购买用户的比例，评估用户粘性和复购表现。
SELECT
  COUNT(*) AS buy_user_total,
  SUM(CASE WHEN buy_count > 1 THEN 1 ELSE 0 END) AS repeat_user_total,
  ROUND(
    SUM(CASE WHEN buy_count > 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0),
    4
  ) AS repeat_rate
FROM user_purchase_summary;
