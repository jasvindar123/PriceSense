-- ================================================
-- PriceSense | 01_data_cleaning.sql
-- Best combined version
-- ================================================

-- ------------------------------------------------
-- STEP 1: Load all 5 raw CSV files
-- ------------------------------------------------
CREATE OR REPLACE TABLE transactions AS 
SELECT * FROM read_csv_auto('data/transactions.csv');

CREATE OR REPLACE TABLE consumer_insights AS 
SELECT * FROM read_csv_auto('data/consumer_insights.csv');

CREATE OR REPLACE TABLE geography_occasion AS 
SELECT * FROM read_csv_auto('data/geography_occasion.csv');

CREATE OR REPLACE TABLE product_metadata AS 
SELECT * FROM read_csv_auto('data/product_metadata.csv');

CREATE OR REPLACE TABLE competitor_pricing AS 
SELECT * FROM read_csv_auto('data/competitor_pricing.csv');

-- ------------------------------------------------
-- STEP 2: Clean transactions
-- Remove impossible values + deduplicate
-- ------------------------------------------------
CREATE OR REPLACE TABLE transactions_clean AS
SELECT * EXCLUDE(rn)
FROM (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id, product_id
            ORDER BY timestamp
        ) AS rn
    FROM transactions
    WHERE price > 0 
      AND quantity > 0
)
WHERE rn = 1;

-- ------------------------------------------------
-- STEP 3: Clean consumer data
-- Fix nulls, lowercase, trim whitespace
-- ------------------------------------------------
CREATE OR REPLACE TABLE consumer_clean AS
SELECT
    user_id,
    COALESCE(LOWER(TRIM(persona)), 'unknown')            AS persona,
    LOWER(TRIM(trend_affinity))                          AS trend_affinity,
    age_group,
    income_bracket,
    COALESCE(LOWER(TRIM(dietary_restriction)), 'none')   AS dietary_restriction
FROM consumer_insights;

-- ------------------------------------------------
-- STEP 4: Clean product data
-- Fix typos, lowercase, trim whitespace
-- ------------------------------------------------
CREATE OR REPLACE TABLE product_clean AS
SELECT
    product_id,
    CASE
        WHEN LOWER(TRIM(category)) = 'proten shake'
            THEN 'protein shake'
        ELSE LOWER(TRIM(category))
    END                                                  AS category,
    LOWER(TRIM(claims))                                  AS claims,
    LOWER(TRIM(ingredient_tags))                         AS ingredient_tags,
    pack_size
FROM product_metadata;

-- ------------------------------------------------
-- STEP 5: Clean geography data
-- Fix state name inconsistencies and typos
-- ------------------------------------------------
CREATE OR REPLACE TABLE geography_clean AS
SELECT
    order_id,
    CASE
        WHEN LOWER(TRIM(state)) IN ('ny', 'new york')
            THEN 'New York'
        WHEN LOWER(TRIM(state)) IN ('calfornia', 'california')
            THEN 'California'
        ELSE TRIM(state)
    END                                                  AS state,
    COALESCE(TRIM(city_tier), 'Unknown')                 AS city_tier,
    TRIM(LOWER(occasion))                                AS occasion
FROM geography_occasion
WHERE order_id IS NOT NULL;

-- ------------------------------------------------
-- STEP 6: Sanity checks
-- ------------------------------------------------

-- Before vs after row count
SELECT 'original transactions' AS label, COUNT(*) AS rows FROM transactions
UNION ALL
SELECT 'after cleaning',        COUNT(*) FROM transactions_clean;

-- Confirm no duplicates remain
SELECT 
    'duplicate orders remaining' AS label,
    COUNT(*) AS count
FROM (
    SELECT order_id, product_id
    FROM transactions_clean
    GROUP BY order_id, product_id
    HAVING COUNT(*) > 1
);

-- Confirm personas are clean
SELECT persona, COUNT(*) AS count
FROM consumer_clean
GROUP BY persona
ORDER BY count DESC;

-- Confirm categories are clean
SELECT category, COUNT(*) AS count
FROM product_clean
GROUP BY category
ORDER BY count DESC;

-- Confirm states are clean
SELECT state, COUNT(*) AS count
FROM geography_clean
GROUP BY state
ORDER BY count DESC;