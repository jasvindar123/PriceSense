-- ================================================
-- PriceSense | 02_phase1_sensitivity.sql
-- Phase 1: Find price thresholds where demand drops
-- ================================================

-- ------------------------------------------------
-- STEP 1: Build master table
-- Join all 4 clean tables into one
-- ------------------------------------------------
CREATE OR REPLACE TABLE master AS
SELECT
    t.order_id,
    t.product_id,
    t.price,
    t.quantity,
    t.channel,
    t.price * t.quantity        AS revenue,
    c.persona,
    c.income_bracket,
    c.trend_affinity,
    g.state,
    g.city_tier,
    g.occasion,
    p.category,
    p.claims,
    p.pack_size
FROM transactions_clean t
LEFT JOIN consumer_clean   c ON t.user_id    = c.user_id
LEFT JOIN geography_clean  g ON t.order_id   = g.order_id
LEFT JOIN product_clean    p ON t.product_id = p.product_id;

-- ------------------------------------------------
-- STEP 2: Build master_analysis
-- Remove outliers + normalize pack size + add price buckets
-- All in ONE creation to avoid double overwrite bug
-- ------------------------------------------------
CREATE OR REPLACE TABLE master_analysis AS
WITH unit_normalized AS (
    SELECT *,
        CASE
            WHEN pack_size = 'Single'  THEN 1
            WHEN pack_size = '4-Pack'  THEN 4
            WHEN pack_size = '12-Pack' THEN 12
            ELSE 1
        END AS total_units_in_pack
    FROM master
)
SELECT *,
    ROUND(price / total_units_in_pack, 2) AS unit_price,
    CASE
        WHEN price < 10  THEN '1) $0-$9'
        WHEN price < 20  THEN '2) $10-$19'
        WHEN price < 35  THEN '3) $20-$34'
        WHEN price < 50  THEN '4) $35-$49'
        WHEN price < 75  THEN '5) $50-$74'
        WHEN price < 100 THEN '6) $75-$99'
        WHEN price < 150 THEN '7) $100-$149'
        ELSE                  '8) $150+'
    END AS price_bucket
FROM unit_normalized
WHERE (price / total_units_in_pack) <= 100;

-- ------------------------------------------------
-- QUERY 1: Demand distribution across price buckets
-- Overall — how does demand change as price rises?
-- ------------------------------------------------
SELECT
    price_bucket,
    COUNT(*)                    AS num_transactions,
    SUM(quantity)               AS total_units_sold,
    ROUND(AVG(quantity), 2)     AS avg_units_per_order,
    ROUND(SUM(revenue), 2)      AS total_revenue
FROM master_analysis
GROUP BY price_bucket
ORDER BY price_bucket;

-- ------------------------------------------------
-- QUERY 2: Sensitivity by persona
-- Do budget users buy less when price goes up?
-- ------------------------------------------------
SELECT
    persona,
    price_bucket,
    COUNT(*)                    AS num_transactions,
    ROUND(AVG(quantity), 2)     AS avg_units,
    ROUND(SUM(revenue), 2)      AS total_revenue
FROM master_analysis
WHERE persona IS NOT NULL
GROUP BY persona, price_bucket
ORDER BY persona, price_bucket;

-- ------------------------------------------------
-- QUERY 3: Best performing price per persona
-- Which price bucket makes the most revenue per persona?
-- ------------------------------------------------
SELECT
    persona,
    price_bucket,
    ROUND(SUM(revenue), 2)      AS total_revenue,
    SUM(quantity)               AS total_units
FROM master_analysis
WHERE persona IS NOT NULL
GROUP BY persona, price_bucket
ORDER BY persona, total_revenue DESC;

-- ------------------------------------------------
-- QUERY 4: Demand cliff detection
-- Finds exact $5 price points where demand drops 20%+
-- ------------------------------------------------
WITH price_demand AS (
    SELECT
        FLOOR(price/5)*5        AS price_band,
        SUM(quantity)           AS demand
    FROM master_analysis
    GROUP BY price_band
),
demand_changes AS (
    SELECT
        price_band,
        demand,
        LAG(demand) OVER (ORDER BY price_band) AS previous_demand,
        ROUND(
            100.0 *
            (demand - LAG(demand) OVER (ORDER BY price_band))
            / NULLIF(LAG(demand) OVER (ORDER BY price_band), 0),
        2) AS demand_change_pct
    FROM price_demand
)
SELECT *
FROM demand_changes
WHERE demand_change_pct <= -20
  AND previous_demand >= 20
  AND demand >= 100
ORDER BY price_band;

-- ------------------------------------------------
-- QUERY 5: Revenue optimization curve
-- Revenue at every $10 price band up to $200
-- ------------------------------------------------
SELECT
    FLOOR(price/10)*10          AS price_band,
    SUM(quantity)               AS units_sold,
    ROUND(SUM(revenue), 2)      AS total_revenue
FROM master_analysis
WHERE price <= 200
GROUP BY price_band
ORDER BY price_band;

-- ------------------------------------------------
-- QUERY 6: Price elasticity per persona
-- Elasticity = % demand change / % price change
-- If elasticity = -2: 1% price rise = 2% demand drop
-- ------------------------------------------------
WITH persona_bands AS (
    SELECT
        persona,
        FLOOR(price/10)*10      AS price_band,
        SUM(quantity)           AS total_units
    FROM master_analysis
    WHERE persona IS NOT NULL
    GROUP BY persona, price_band
),
with_changes AS (
    SELECT *,
        LAG(total_units) OVER (
            PARTITION BY persona ORDER BY price_band
        ) AS prev_units,
        LAG(price_band) OVER (
            PARTITION BY persona ORDER BY price_band
        ) AS prev_price
    FROM persona_bands
)
SELECT
    persona,
    price_band,
    prev_price,
    total_units,
    prev_units,
    ROUND(
        ((total_units - prev_units) * 1.0 / NULLIF(prev_units, 0)) /
        ((price_band  - prev_price) * 1.0 / NULLIF(prev_price, 0))
    , 2) AS price_elasticity
FROM with_changes
WHERE prev_units IS NOT NULL
ORDER BY persona, price_band;