-- ================================================
-- PriceSense | 03_phase2_contextual.sql
-- Phase 2: Geography, Occasions, Trend Claims, Competitors
-- ================================================

-- ------------------------------------------------
-- QUERY 1: Revenue and demand by State
-- Which states tolerate higher prices?
-- ------------------------------------------------
SELECT
    state,
    city_tier,
    COUNT(*)                    AS num_transactions,
    ROUND(AVG(price), 2)        AS avg_price,
    SUM(quantity)               AS total_units,
    ROUND(SUM(revenue), 2)      AS total_revenue,
    ROUND(AVG(revenue), 2)      AS avg_order_value
FROM master_analysis
WHERE state IS NOT NULL
GROUP BY state, city_tier
ORDER BY avg_price DESC;

-- ------------------------------------------------
-- QUERY 2: Revenue by City Tier
-- Do Tier 1 cities pay more?
-- ------------------------------------------------
SELECT
    city_tier,
    COUNT(*)                    AS num_transactions,
    ROUND(AVG(price), 2)        AS avg_price,
    SUM(quantity)               AS total_units,
    ROUND(SUM(revenue), 2)      AS total_revenue
FROM master_analysis
WHERE city_tier IS NOT NULL
GROUP BY city_tier
ORDER BY avg_price DESC;

-- ------------------------------------------------
-- QUERY 3: Occasion analysis
-- Which occasions drive highest prices and revenue?
-- ------------------------------------------------
SELECT
    occasion,
    COUNT(*)                    AS num_transactions,
    ROUND(AVG(price), 2)        AS avg_price,
    SUM(quantity)               AS total_units,
    ROUND(SUM(revenue), 2)      AS total_revenue,
    ROUND(AVG(quantity), 2)     AS avg_units_per_order
FROM master_analysis
WHERE occasion IS NOT NULL
GROUP BY occasion
ORDER BY avg_price DESC;

-- ------------------------------------------------
-- QUERY 4: Do trend claims justify higher prices?
-- Compare avg price of products with vs without claims
-- ------------------------------------------------
WITH split_claims AS (
    SELECT 
        *,
        -- Split string by comma and expand array elements into distinct rows
        TRIM(UNNEST(STRING_SPLIT(claims, ','))) AS individual_claim
    FROM master_analysis
    WHERE claims IS NOT NULL
)
SELECT
    individual_claim            AS product_claim,
    COUNT(*)                    AS num_transactions,
    ROUND(AVG(price), 2)        AS avg_price,
    SUM(quantity)               AS total_units,
    ROUND(SUM(revenue), 2)      AS total_revenue
FROM split_claims
GROUP BY individual_claim
ORDER BY avg_price DESC;

-- ------------------------------------------------
-- QUERY 5: Competitor pricing comparison
-- How do our prices compare to competitors?
-- ------------------------------------------------
SELECT 'Our products' AS source,
    ROUND(AVG(price),2) AS avg_price,
    ROUND(MIN(price),2) AS min_price,
    ROUND(MAX(price),2) AS max_price
FROM master_analysis
UNION ALL
SELECT 'Competitors' AS source,
    ROUND(AVG(price),2) AS avg_price,
    ROUND(MIN(price),2) AS min_price,
    ROUND(MAX(price),2) AS max_price
FROM competitor_pricing
WHERE price IS NOT NULL;

-- ------------------------------------------------
-- QUERY 6: Persona x Occasion sweet spots
-- Which persona + occasion combo drives most revenue?
-- ------------------------------------------------
SELECT
    persona,
    occasion,
    ROUND(AVG(price), 2)        AS avg_price,
    ROUND(SUM(revenue), 2)      AS total_revenue,
    SUM(quantity)               AS total_units
FROM master_analysis
WHERE persona IS NOT NULL
AND occasion IS NOT NULL
GROUP BY persona, occasion
ORDER BY total_revenue DESC
LIMIT 15;

-- ------------------------------------------------
-- QUERY 7: Trend Affinity Analysis
-- Do trend-focused consumers pay more?
-- ------------------------------------------------
SELECT
    trend_affinity,
    COUNT(*) AS transactions,
    ROUND(AVG(price),2) AS avg_price,
    SUM(quantity) AS units_sold,
    ROUND(SUM(revenue),2) AS total_revenue
FROM master_analysis
GROUP BY trend_affinity
ORDER BY total_revenue DESC;

-- ------------------------------------------------
-- QUERY 8: Product Category Pricing Power
-- Which categories support premium pricing?
-- ------------------------------------------------

SELECT
    category,
    COUNT(*) AS transactions,
    ROUND(AVG(price),2) AS avg_price,
    SUM(quantity) AS units_sold,
    ROUND(SUM(revenue),2) AS total_revenue
FROM master_analysis
WHERE category IS NOT NULL  
GROUP BY category
ORDER BY total_revenue DESC;

-- ------------------------------------------------
-- QUERY 9: Persona x City Tier
-- Which customer segments pay more in each city tier?
-- ------------------------------------------------

SELECT
    city_tier,
    persona,
    ROUND(AVG(price),2) AS avg_price,
    ROUND(SUM(revenue),2) AS total_revenue
FROM master_analysis
WHERE city_tier IS NOT NULL AND persona IS NOT NULL
GROUP BY city_tier, persona
ORDER BY total_revenue DESC;

-- ------------------------------------------------
-- QUERY 10: Occasion x Category
-- Which products perform best for each occasion?
-- ------------------------------------------------

SELECT
    occasion,
    category,
    ROUND(AVG(price),2) AS avg_price,
    SUM(quantity) AS total_units,
    ROUND(SUM(revenue),2) AS total_revenue
FROM master_analysis
WHERE occasion IS NOT NULL
  AND category IS NOT NULL
GROUP BY occasion, category
ORDER BY total_revenue DESC
LIMIT 20;

