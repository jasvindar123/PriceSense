-- ================================================
-- PriceSense | 04_mdp_optimization_v2.sql
-- MDP-Based Pricing Optimization
-- Based on: Bellman (1957) Value Iteration
-- Reference: Springer - MDP in Dynamic Pricing
-- ================================================

-- -----------------------------------------------
-- STEP 1: Define State Space
-- Every unique price band = one state
-- -----------------------------------------------
CREATE OR REPLACE TABLE mdp_states AS
SELECT
    persona,
    city_tier,
    occasion,
    FLOOR(price/10)*10          AS price_band,   -- $5 bands = states
    COUNT(*)                    AS num_transactions,
    SUM(quantity)               AS total_units,
    ROUND(AVG(price), 2)        AS avg_price,
    ROUND(SUM(revenue), 2)      AS total_reward,   -- R(s) immediate reward
    ROUND(AVG(revenue), 2)      AS avg_reward
FROM master_analysis
WHERE persona   IS NOT NULL
  AND city_tier IS NOT NULL
  AND occasion  IS NOT NULL
GROUP BY persona, city_tier, occasion, price_band
HAVING COUNT(*) >= 5;  -- only states with enough data

-- -----------------------------------------------
-- STEP 2: Transition Probabilities
-- How does demand change between price states?
-- T(s, a, s') = probability of moving to s' from s
-- -----------------------------------------------
CREATE OR REPLACE TABLE mdp_transitions AS
WITH with_lag AS (
    SELECT *,
        LAG(total_units) OVER (
            PARTITION BY persona, city_tier, occasion
            ORDER BY price_band
        ) AS prev_units
    FROM mdp_states
)
SELECT *,
    ROUND(COALESCE(
        (total_units - prev_units) * 1.0
        / NULLIF(prev_units, 0), 0
    ), 4) AS transition_prob   -- negative = demand dropped
FROM with_lag;

-- -----------------------------------------------
-- STEP 3: Value Iteration (Bellman Equation)
-- V(s) = R(s) + γ · max V(s')
-- γ = 0.9 (discount factor)
-- Run 5 iterations until values converge
-- -----------------------------------------------
CREATE OR REPLACE TABLE mdp_values AS
WITH iter0 AS (
    SELECT 
        persona, 
        city_tier, 
        occasion, 
        price_band, 
        avg_reward,
        avg_reward AS state_value, 
        0 AS iteration
    FROM mdp_states
),
iter1 AS (
    SELECT 
        t.persona, 
        t.city_tier, 
        t.occasion, 
        t.price_band, 
        t.avg_reward,
        ROUND(t.avg_reward + 0.9 * COALESCE(prev.state_value * (1.0 + t.transition_prob), 0), 2) AS state_value,
        1 AS iteration
    FROM mdp_transitions t
    LEFT JOIN iter0 prev 
      ON t.persona = prev.persona 
     AND t.city_tier = prev.city_tier 
     AND t.occasion = prev.occasion
     AND t.price_band = prev.price_band
),
iter2 AS (
    SELECT 
        t.persona, 
        t.city_tier, 
        t.occasion, 
        t.price_band, 
        t.avg_reward,
        ROUND(t.avg_reward + 0.9 * COALESCE(prev.state_value * (1.0 + t.transition_prob), 0), 2) AS state_value,
        2 AS iteration
    FROM mdp_transitions t
    LEFT JOIN iter1 prev 
      ON t.persona = prev.persona 
     AND t.city_tier = prev.city_tier 
     AND t.occasion = prev.occasion
     AND t.price_band = prev.price_band
),
iter3 AS (
    SELECT 
        t.persona, 
        t.city_tier, 
        t.occasion, 
        t.price_band, 
        t.avg_reward,
        ROUND(t.avg_reward + 0.9 * COALESCE(prev.state_value * (1.0 + t.transition_prob), 0), 2) AS state_value,
        3 AS iteration
    FROM mdp_transitions t
    LEFT JOIN iter2 prev 
      ON t.persona = prev.persona 
     AND t.city_tier = prev.city_tier 
     AND t.occasion = prev.occasion
     AND t.price_band = prev.price_band
),
iter4 AS (
    SELECT 
        t.persona, 
        t.city_tier, 
        t.occasion, 
        t.price_band, 
        t.avg_reward,
        ROUND(t.avg_reward + 0.9 * COALESCE(prev.state_value * (1.0 + t.transition_prob), 0), 2) AS state_value,
        4 AS iteration
    FROM mdp_transitions t
    LEFT JOIN iter3 prev 
      ON t.persona = prev.persona 
     AND t.city_tier = prev.city_tier 
     AND t.occasion = prev.occasion
     AND t.price_band = prev.price_band
),
iter5 AS (
    SELECT 
        t.persona, 
        t.city_tier, 
        t.occasion, 
        t.price_band, 
        t.avg_reward,
        ROUND(t.avg_reward + 0.9 * COALESCE(prev.state_value * (1.0 + t.transition_prob), 0), 2) AS state_value,
        5 AS iteration
    FROM mdp_transitions t
    LEFT JOIN iter4 prev 
      ON t.persona = prev.persona 
     AND t.city_tier = prev.city_tier 
     AND t.occasion = prev.occasion
     AND t.price_band = prev.price_band
)
-- Combine all iteration sweeps into a single reference matrix
SELECT * FROM iter0 
UNION ALL 
SELECT * FROM iter1 
UNION ALL 
SELECT * FROM iter2
UNION ALL 
SELECT * FROM iter3
UNION ALL 
SELECT * FROM iter4
UNION ALL 
SELECT * FROM iter5;

-- -----------------------------------------------
-- STEP 4: Extract Optimal Policy
-- π*(s) = argmax V(s) for each situation
-- -----------------------------------------------
CREATE OR REPLACE TABLE mdp_optimal_policy_v2 AS
WITH final_values AS (
    SELECT * FROM mdp_values WHERE iteration = 5
),
ranked AS (
    SELECT *,
        RANK() OVER (
            PARTITION BY persona, city_tier, occasion
            ORDER BY state_value DESC
        ) AS value_rank
    FROM final_values
)
SELECT
    persona,
    city_tier,
    occasion,
    price_band              AS optimal_price_band,
    price_band + 9          AS optimal_price_max,
    avg_reward              AS immediate_revenue,
    state_value             AS mdp_value_score,
    ROUND(state_value - avg_reward, 2) AS future_value_added
FROM ranked
WHERE value_rank = 1
ORDER BY persona, city_tier, mdp_value_score DESC;

-- Show the final policy
SELECT * FROM mdp_optimal_policy_v2;

-- -----------------------------------------------
-- STEP 5: Sensitivity to discount factor
-- Compare policies at γ=0.5 vs γ=0.9 vs γ=0.99
-- -----------------------------------------------
SELECT
    persona,
    city_tier,
    occasion,
    price_band,
    avg_reward                                    AS immediate_reward,
    ROUND(avg_reward + 0.5 * avg_reward, 2)       AS value_gamma_05,
    ROUND(avg_reward + 0.9 * avg_reward, 2)       AS value_gamma_09,
    ROUND(avg_reward + 0.99 * avg_reward, 2)      AS value_gamma_099
FROM mdp_states
ORDER BY persona, city_tier, price_band
LIMIT 30;