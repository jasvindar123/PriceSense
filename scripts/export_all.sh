#!/bin/bash
# PriceSense — Export all results to final_outputs

echo "Exporting cleaned tables..."
duckdb pricesense.db -c "SELECT * FROM transactions_clean;" > final_outputs/01_transactions_clean.csv
duckdb pricesense.db -c "SELECT * FROM consumer_clean;" > final_outputs/02_consumer_clean.csv
duckdb pricesense.db -c "SELECT * FROM product_clean;" > final_outputs/03_product_clean.csv
duckdb pricesense.db -c "SELECT * FROM geography_clean;" > final_outputs/04_geography_clean.csv
duckdb pricesense.db -c "SELECT * FROM master;" > final_outputs/05_master.csv
duckdb pricesense.db -c "SELECT * FROM master_analysis;" > final_outputs/06_master_analysis.csv

echo "Exporting Phase 1 results..."
duckdb pricesense.db -c "SELECT price_bucket, COUNT(*) AS num_transactions, SUM(quantity) AS total_units_sold, ROUND(AVG(quantity),2) AS avg_units_per_order, ROUND(SUM(revenue),2) AS total_revenue FROM master_analysis GROUP BY price_bucket ORDER BY price_bucket;" > final_outputs/07_phase1_q1_demand_by_bucket.csv

duckdb pricesense.db -c "SELECT persona, price_bucket, COUNT(*) AS num_transactions, ROUND(AVG(quantity),2) AS avg_units, ROUND(SUM(revenue),2) AS total_revenue FROM master_analysis WHERE persona IS NOT NULL GROUP BY persona, price_bucket ORDER BY persona, price_bucket;" > final_outputs/08_phase1_q2_sensitivity_by_persona.csv

duckdb pricesense.db -c "SELECT persona, price_bucket, ROUND(SUM(revenue),2) AS total_revenue, SUM(quantity) AS total_units FROM master_analysis WHERE persona IS NOT NULL GROUP BY persona, price_bucket ORDER BY persona, total_revenue DESC;" > final_outputs/09_phase1_q3_best_price_per_persona.csv

duckdb pricesense.db -c "WITH price_demand AS (SELECT FLOOR(price/5)*5 AS price_band, SUM(quantity) AS demand FROM master_analysis GROUP BY price_band), demand_changes AS (SELECT price_band, demand, LAG(demand) OVER (ORDER BY price_band) AS previous_demand, ROUND(100.0*(demand-LAG(demand) OVER (ORDER BY price_band))/NULLIF(LAG(demand) OVER (ORDER BY price_band),0),2) AS demand_change_pct FROM price_demand) SELECT * FROM demand_changes WHERE demand_change_pct <= -20 AND previous_demand >= 20 AND demand >= 100 ORDER BY price_band;" > final_outputs/10_phase1_q4_demand_cliffs.csv

duckdb pricesense.db -c "SELECT FLOOR(price/10)*10 AS price_band, SUM(quantity) AS units_sold, ROUND(SUM(revenue),2) AS total_revenue FROM master_analysis WHERE price <= 200 GROUP BY price_band ORDER BY price_band;" > final_outputs/11_phase1_q5_revenue_curve.csv

duckdb pricesense.db -c "WITH persona_bands AS (SELECT persona, FLOOR(price/10)*10 AS price_band, SUM(quantity) AS total_units FROM master_analysis WHERE persona IS NOT NULL GROUP BY persona, price_band), with_changes AS (SELECT *, LAG(total_units) OVER (PARTITION BY persona ORDER BY price_band) AS prev_units, LAG(price_band) OVER (PARTITION BY persona ORDER BY price_band) AS prev_price FROM persona_bands) SELECT persona, price_band, prev_price, total_units, prev_units, ROUND(((total_units-prev_units)*1.0/NULLIF(prev_units,0))/((price_band-prev_price)*1.0/NULLIF(prev_price,0)),2) AS price_elasticity FROM with_changes WHERE prev_units IS NOT NULL ORDER BY persona, price_band;" > final_outputs/12_phase1_q6_price_elasticity.csv

echo "Exporting Phase 2 results..."
duckdb pricesense.db -c "SELECT state, city_tier, COUNT(*) AS num_transactions, ROUND(AVG(price),2) AS avg_price, SUM(quantity) AS total_units, ROUND(SUM(revenue),2) AS total_revenue, ROUND(AVG(revenue),2) AS avg_order_value FROM master_analysis WHERE state IS NOT NULL GROUP BY state, city_tier ORDER BY avg_price DESC;" > final_outputs/13_phase2_q1_by_state.csv

duckdb pricesense.db -c "SELECT city_tier, COUNT(*) AS num_transactions, ROUND(AVG(price),2) AS avg_price, SUM(quantity) AS total_units, ROUND(SUM(revenue),2) AS total_revenue FROM master_analysis WHERE city_tier IS NOT NULL GROUP BY city_tier ORDER BY avg_price DESC;" > final_outputs/14_phase2_q2_by_tier.csv

duckdb pricesense.db -c "SELECT occasion, COUNT(*) AS num_transactions, ROUND(AVG(price),2) AS avg_price, SUM(quantity) AS total_units, ROUND(SUM(revenue),2) AS total_revenue, ROUND(AVG(quantity),2) AS avg_units_per_order FROM master_analysis WHERE occasion IS NOT NULL GROUP BY occasion ORDER BY avg_price DESC;" > final_outputs/15_phase2_q3_by_occasion.csv

duckdb pricesense.db -c "WITH split_claims AS (SELECT *, TRIM(UNNEST(STRING_SPLIT(claims, ','))) AS individual_claim FROM master_analysis WHERE claims IS NOT NULL) SELECT individual_claim AS product_claim, COUNT(*) AS num_transactions, ROUND(AVG(price),2) AS avg_price, SUM(quantity) AS total_units, ROUND(SUM(revenue),2) AS total_revenue FROM split_claims GROUP BY individual_claim ORDER BY avg_price DESC;" > final_outputs/16_phase2_q4_by_claims.csv

duckdb pricesense.db -c "SELECT 'Our products' AS source, ROUND(AVG(price),2) AS avg_price, ROUND(MIN(price),2) AS min_price, ROUND(MAX(price),2) AS max_price FROM master_analysis UNION ALL SELECT 'Competitors', ROUND(AVG(price),2), ROUND(MIN(price),2), ROUND(MAX(price),2) FROM competitor_pricing WHERE price IS NOT NULL;" > final_outputs/17_phase2_q5_competitor_comparison.csv

duckdb pricesense.db -c "SELECT persona, occasion, ROUND(AVG(price),2) AS avg_price, ROUND(SUM(revenue),2) AS total_revenue, SUM(quantity) AS total_units FROM master_analysis WHERE persona IS NOT NULL AND occasion IS NOT NULL GROUP BY persona, occasion ORDER BY total_revenue DESC LIMIT 15;" > final_outputs/18_phase2_q6_persona_occasion.csv

duckdb pricesense.db -c "SELECT trend_affinity, COUNT(*) AS transactions, ROUND(AVG(price),2) AS avg_price, SUM(quantity) AS units_sold, ROUND(SUM(revenue),2) AS total_revenue FROM master_analysis GROUP BY trend_affinity ORDER BY total_revenue DESC;" > final_outputs/19_phase2_q7_trend_affinity.csv

duckdb pricesense.db -c "SELECT category, COUNT(*) AS transactions, ROUND(AVG(price),2) AS avg_price, SUM(quantity) AS units_sold, ROUND(SUM(revenue),2) AS total_revenue FROM master_analysis WHERE category IS NOT NULL GROUP BY category ORDER BY total_revenue DESC;" > final_outputs/20_phase2_q8_by_category.csv

duckdb pricesense.db -c "SELECT city_tier, persona, ROUND(AVG(price),2) AS avg_price, ROUND(SUM(revenue),2) AS total_revenue FROM master_analysis WHERE city_tier IS NOT NULL AND persona IS NOT NULL GROUP BY city_tier, persona ORDER BY total_revenue DESC;" > final_outputs/21_phase2_q9_persona_tier.csv

duckdb pricesense.db -c "SELECT occasion, category, ROUND(AVG(price),2) AS avg_price, SUM(quantity) AS total_units, ROUND(SUM(revenue),2) AS total_revenue FROM master_analysis WHERE occasion IS NOT NULL AND category IS NOT NULL GROUP BY occasion, category ORDER BY total_revenue DESC LIMIT 20;" > final_outputs/22_phase2_q10_occasion_category.csv

echo "Exporting MDP results..."
duckdb pricesense.db -c "SELECT * FROM mdp_states;" > final_outputs/23_mdp_states.csv
duckdb pricesense.db -c "SELECT * FROM mdp_transitions;" > final_outputs/24_mdp_transitions.csv
duckdb pricesense.db -c "SELECT * FROM mdp_values;" > final_outputs/25_mdp_values.csv
duckdb pricesense.db -c "SELECT * FROM mdp_optimal_policy_v2;" > final_outputs/26_mdp_optimal_policy.csv

echo "Exporting Phase 3 recommendations..."
duckdb pricesense.db -c "SELECT FLOOR(price/10)*10 AS price_band, ROUND(SUM(revenue),2) AS total_revenue, SUM(quantity) AS units_sold FROM master_analysis GROUP BY price_band ORDER BY total_revenue DESC;" > final_outputs/27_phase3_q1_best_price_bands.csv

duckdb pricesense.db -c "SELECT category, ROUND(AVG(price),2) AS avg_price, ROUND(SUM(revenue),2) AS total_revenue, SUM(quantity) AS total_units FROM master_analysis WHERE category IS NOT NULL GROUP BY category ORDER BY avg_price DESC;" > final_outputs/28_phase3_q2_category_power.csv

duckdb pricesense.db -c "SELECT city_tier, ROUND(AVG(price),2) AS avg_price, ROUND(SUM(revenue),2) AS total_revenue FROM master_analysis WHERE city_tier IS NOT NULL GROUP BY city_tier ORDER BY avg_price DESC;" > final_outputs/29_phase3_q3_geographic_strategy.csv

duckdb pricesense.db -c "SELECT persona, ROUND(SUM(revenue),2) AS total_revenue, SUM(quantity) AS total_units FROM master_analysis GROUP BY persona ORDER BY total_revenue DESC;" > final_outputs/30_phase3_q4_valuable_personas.csv

duckdb pricesense.db -c "SELECT occasion, ROUND(SUM(revenue),2) AS total_revenue, SUM(quantity) AS total_units FROM master_analysis WHERE occasion IS NOT NULL GROUP BY occasion ORDER BY total_revenue DESC;" > final_outputs/31_phase3_q5_best_occasions.csv

duckdb pricesense.db -c "WITH split_claims AS (SELECT *, TRIM(UNNEST(STRING_SPLIT(claims, ','))) AS individual_claim FROM master_analysis WHERE claims IS NOT NULL) SELECT individual_claim AS claims, ROUND(AVG(price),2) AS avg_price, ROUND(SUM(revenue),2) AS total_revenue FROM split_claims GROUP BY individual_claim ORDER BY avg_price DESC LIMIT 20;" > final_outputs/32_phase3_q6_premium_claims.csv

echo "All exports complete! Check final_outputs folder."