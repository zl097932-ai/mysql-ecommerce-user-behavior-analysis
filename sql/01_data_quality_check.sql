-- 01_data_quality_check

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