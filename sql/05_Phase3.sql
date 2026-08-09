-- ================================================
-- PriceSense | 05_phase3_recommendations.sql
-- Phase 3: Pricing Strategy Recommendations
-- ================================================

-- QUERY 1: Best Revenue Price Bands

SELECT
    FLOOR(price/10)*10 AS price_band,
    ROUND(SUM(revenue),2) AS total_revenue,
    SUM(quantity) AS units_sold
FROM master_analysis
GROUP BY price_band
ORDER BY total_revenue DESC;


-- QUERY 2: Category Pricing Power

SELECT
    category,
    ROUND(AVG(price),2) AS avg_price,
    ROUND(SUM(revenue),2) AS total_revenue,
    SUM(quantity) AS total_units
FROM master_analysis
WHERE category IS NOT NULL
GROUP BY category
ORDER BY avg_price DESC;


-- QUERY 3: Geographic Pricing Strategy

SELECT
    city_tier,
    ROUND(AVG(price),2) AS avg_price,
    ROUND(SUM(revenue),2) AS total_revenue
FROM master_analysis
WHERE city_tier IS NOT NULL
GROUP BY city_tier
ORDER BY avg_price DESC;


-- QUERY 4: Most Valuable Personas

SELECT
    persona,
    ROUND(SUM(revenue),2) AS total_revenue,
    SUM(quantity) AS total_units
FROM master_analysis
GROUP BY persona
ORDER BY total_revenue DESC;


-- QUERY 5: Best Occasions

SELECT
    occasion,
    ROUND(SUM(revenue),2) AS total_revenue,
    SUM(quantity) AS total_units
FROM master_analysis
WHERE occasion IS NOT NULL
GROUP BY occasion
ORDER BY total_revenue DESC;


-- QUERY 6: Premium Product Claims

WITH split_claims AS (
    SELECT 
        *,
        -- Split the string by comma and expand elements into individual lines
        TRIM(UNNEST(STRING_SPLIT(claims, ','))) AS individual_claim
    FROM master_analysis
    WHERE claims IS NOT NULL
)
SELECT
    individual_claim        AS claims,
    ROUND(AVG(price), 2)    AS avg_price,
    ROUND(SUM(revenue), 2)  AS total_revenue
FROM split_claims
GROUP BY individual_claim
ORDER BY avg_price DESC
LIMIT 20;

-- QUERY 7: Data-driven recommendations

-- Best occasion by revenue
SELECT 'Top occasion' AS insight,
    occasion AS value,
    ROUND(SUM(revenue),2) AS total_revenue
FROM master_analysis
WHERE occasion IS NOT NULL
GROUP BY occasion
ORDER BY total_revenue DESC
LIMIT 1;

-- Best city tier by avg price
SELECT 'Highest paying city tier' AS insight,
    city_tier AS value,
    ROUND(AVG(price),2) AS Avg_revenue
FROM master_analysis
WHERE city_tier IS NOT NULL
GROUP BY city_tier
ORDER BY Avg_revenue DESC
LIMIT 1;

-- Best category by revenue
SELECT 'Top category' AS insight,
    category AS value,
    ROUND(SUM(revenue),2) AS total_revenue
FROM master_analysis
WHERE category IS NOT NULL
GROUP BY category
ORDER BY total_revenue DESC
LIMIT 1;

-- Best claim by avg price
WITH split_claims AS (
    SELECT 
        *,
        TRIM(UNNEST(STRING_SPLIT(claims, ','))) AS individual_claim
    FROM master_analysis
    WHERE claims IS NOT NULL
)
SELECT 'Highest priced claim' AS insight,
    individual_claim AS value,
    ROUND(AVG(price),2) AS highest_avg_price
FROM split_claims
GROUP BY individual_claim
ORDER BY highest_avg_price DESC
LIMIT 1;