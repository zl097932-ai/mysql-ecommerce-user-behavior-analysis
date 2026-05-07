-- 02_data_cleaning.sql

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
