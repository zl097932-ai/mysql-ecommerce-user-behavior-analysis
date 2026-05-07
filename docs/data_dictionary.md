# 数据字典

## 1. 原始数据表：userbehavior

| 字段名 | 含义 |
|---|---|
| `user_id` | 用户 ID |
| `item_id` | 商品 ID |
| `category_id` | 商品类目 ID |
| `behavior_type` | 用户行为类型 |
| `time_stamp` | 用户行为发生时间戳 |

## 2. 行为类型说明

| 行为类型 | 含义 | 业务解释 |
|---|---|---|
| `pv` | 浏览 | 用户查看商品详情页 |
| `fav` | 收藏 | 用户收藏商品 |
| `cart` | 加购 | 用户将商品加入购物车 |
| `buy` | 购买 | 用户完成购买行为 |

## 3. 清洗后数据表：userbehavior_clean

| 字段名 | 含义 |
|---|---|
| `user_id` | 用户 ID |
| `item_id` | 商品 ID |
| `category_id` | 商品类目 ID |
| `behavior_type` | 用户行为类型 |
| `time_stamp` | 原始时间戳 |
| `event_time` | 转换后的标准时间 |

## 4. 分析周期

```text
2017-11-25 00:00:00 至 2017-12-03 23:59:59
```

## 5. 清洗规则

- 删除关键字段为空的记录。
- 删除异常行为类型，仅保留 `pv`、`fav`、`cart`、`buy`。
- 删除目标时间范围外的数据。
- 删除完全重复记录。
- 保留原始表，新建清洗表 `userbehavior_clean`。
