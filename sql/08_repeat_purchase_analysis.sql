-- 08_repeat_purchase_analysis.sql

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
