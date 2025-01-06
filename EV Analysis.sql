
SELECT * FROM electric_vehicle_sales_by_state;
SELECT * FROM electric_vehicle_sales_by_makers;
SELECT * FROM dim_date;

-- 1. List the top 3 and bottom 3 makers for the fiscal years 2023 and 2024 in terms of the number of 2-wheelers sold.

WITH cte AS (
SELECT m.maker, d.fiscal_year, SUM(m.electric_vehicles_sold) AS total_ev_sales,
DENSE_RANK() OVER(PARTITION BY d.fiscal_year ORDER BY SUM(m.electric_vehicles_sold) DESC) AS d_top
FROM dim_date d
JOIN electric_vehicle_sales_by_makers m ON d.date = m.date
WHERE m.vehicle_category = '2-Wheelers' AND fiscal_year IN (2023, 2024)
GROUP BY d.fiscal_year, m.maker
)
SELECT maker AS top_3_makers, fiscal_year, total_ev_sales
FROM cte
WHERE d_top < = 3;


WITH cte AS (
SELECT m.maker, d.fiscal_year, SUM(m.electric_vehicles_sold) AS total_ev_sales,
DENSE_RANK() OVER(PARTITION BY d.fiscal_year ORDER BY SUM(m.electric_vehicles_sold)) AS d_bottom
FROM dim_date d
JOIN electric_vehicle_sales_by_makers m ON d.date = m.date
WHERE m.vehicle_category = '2-Wheelers' AND fiscal_year IN (2023, 2024)
GROUP BY d.fiscal_year, m.maker
)
SELECT maker AS bottom_3_makers, fiscal_year, total_ev_sales
FROM cte
WHERE d_bottom < = 3;




-- 2. Identify the top 5 states with the highest penetration rate in 2-wheeler and 4-wheeler EV sales in FY 2024.

SELECT TOP 5 s.state, 
CONCAT(FORMAT(100.0 * SUM(s.electric_vehicles_sold) / SUM(s.total_vehicles_sold), '00.00'), ' %') AS penetration_rate_2_wheeler
FROM dim_date d
JOIN electric_vehicle_sales_by_state s ON d.date = s.date
WHERE d.fiscal_year = 2024 AND s.vehicle_category = '2-Wheelers'  
GROUP BY s.state
ORDER BY 2 DESC;

SELECT TOP 5 s.state, 
CONCAT(FORMAT(100.0 * SUM(s.electric_vehicles_sold) / SUM(s.total_vehicles_sold), '0.00'), ' %') AS penetration_rate_4_wheeler
FROM dim_date d
JOIN electric_vehicle_sales_by_state s ON d.date = s.date
WHERE d.fiscal_year = 2024 AND s.vehicle_category = '4-Wheelers'  
GROUP BY s.state
ORDER BY 2 DESC;


-- 3. List the states with negative penetration (decline) in EV sales from 2022 to 2024?

SELECT s.state, 
SUM(CASE WHEN fiscal_year = 2022 THEN electric_vehicles_sold ELSE 0 END) AS sales_2022,
SUM(CASE WHEN fiscal_year = 2024 THEN electric_vehicles_sold ELSE 0 END) AS sales_2024,	
CONCAT(FORMAT(100.0 * SUM(CAST(s.electric_vehicles_sold AS DECIMAL(18,2))) / SUM(CAST(s.total_vehicles_sold AS DECIMAL(18,2))), '0.00'), ' %') AS positive_penetration_rate
FROM dim_date d
JOIN electric_vehicle_sales_by_state s ON d.date = s.date
WHERE d.fiscal_year BETWEEN 2022 AND 2024  
GROUP BY s.state
ORDER BY s.state;

-- 4. What are the quarterly trends based on sales volume for the top 5 EV makers (4-wheelers) from 2022 to 2024?

SELECT maker, fiscal_year, quarter, SUM(electric_vehicles_sold) AS total_sales
FROM electric_vehicle_sales_by_makers m 
JOIN dim_date d ON d.date = m.date
WHERE vehicle_category='4-Wheelers' AND 
maker IN (
	SELECT TOP 5 maker
	FROM 
	electric_vehicle_sales_by_makers m
	JOIN dim_date d ON d.date = m.date
	WHERE vehicle_category='4-Wheelers'
	GROUP BY maker
	ORDER BY SUM(electric_vehicles_sold) DESC
)
GROUP BY maker,fiscal_year,quarter
ORDER BY maker,fiscal_year,quarter;

-- 5. How do the EV sales and penetration rates in Delhi compare to Karnataka for 2024?

SELECT s.state, d.fiscal_year, SUM(s.electric_vehicles_sold) EV_sales,
CONCAT(FORMAT(100.0 * SUM(s.electric_vehicles_sold) / SUM(s.total_vehicles_sold), '0.00'), ' %') AS penetration_rate 
FROM dim_date d
JOIN electric_vehicle_sales_by_state s ON d.date = s.date
WHERE d.fiscal_year = 2024 AND s.state IN ('Delhi','Karnataka')
GROUP BY s.state, d.fiscal_year;

-- 6. List down the compounded annual growth rate (CAGR) in 4-wheeler units for the top 5 makers from 2022 to 2024.

SELECT m.maker, POWER(SUM(CASE WHEN d.fiscal_year = 2024 THEN m.electric_vehicles_sold ELSE 0 END) / 
NULLIF(SUM(CASE WHEN d.fiscal_year = 2022 THEN m.electric_vehicles_sold ELSE 0 END), 0), 0.5) - 1 AS CAGR 
FROM dim_date d
JOIN electric_vehicle_sales_by_makers m ON d.date = m.date
WHERE m.vehicle_category = '4-Wheelers' AND 
m.maker IN (
	SELECT TOP 5 maker
	FROM electric_vehicle_sales_by_makers 
	WHERE vehicle_category='4-Wheelers'
	GROUP BY maker
	ORDER BY SUM(electric_vehicles_sold) DESC
) 
GROUP BY m.maker;


-- 7. List down the top 10 states that had the highest compounded annual growth rate (CAGR) from 2022 to 2024 in total vehicles sold.

SELECT s.state , POWER(SUM(CASE WHEN d.fiscal_year = 2024 THEN s.electric_vehicles_sold ELSE 0 END) / 
NULLIF(SUM(CASE WHEN d.fiscal_year = 2022 THEN s.electric_vehicles_sold ELSE 0 END), 0), 0.5) - 1 AS CAGR 
FROM dim_date d
JOIN electric_vehicle_sales_by_state s ON d.date = s.date
WHERE s.state IN (
	SELECT TOP 10 state
	FROM electric_vehicle_sales_by_state 
	GROUP BY state
	ORDER BY SUM(electric_vehicles_sold) DESC
) 
GROUP BY s.state
ORDER BY 2 DESC;

-- 8. What are the peak and low season months for EV sales based on the data from 2022 to 2024?

SELECT MONTH(d.date) AS month, DATENAME(MONTH, d.date) AS month_name, SUM(s.electric_vehicles_sold) AS EV_sales
FROM dim_date d
JOIN electric_vehicle_sales_by_state s ON d.date = s.date
GROUP BY MONTH(d.date), DATENAME(MONTH, d.date)
ORDER BY month;

-- 9. What is the projected number of EV sales (including 2-wheelers and 4-wheelers) for the top 10 states by penetration rate in 2030, based on the 
--    compounded annual growth rate (CAGR) from previous years?

WITH t10sp AS (
SELECT TOP 10 state, 100.0 * sum(electric_vehicles_sold)/sum(total_vehicles_sold) as penetration_rate
FROM electric_vehicle_sales_by_state 
GROUP BY state
),
CAGR_CTE AS (
SELECT state, POWER(SUM(CASE WHEN d.fiscal_year = 2024 THEN s.electric_vehicles_sold ELSE 0 END) / 
NULLIF(SUM(CASE WHEN d.fiscal_year = 2022 THEN s.electric_vehicles_sold ELSE 0 END), 0), 0.5) - 1 AS CAGR
FROM electric_vehicle_sales_by_state s
JOIN dim_date d ON d.date = s.date 
WHERE state IN (select state from t10sp)
GROUP BY state
),
sales22 AS (
SELECT t10sp.state, SUM(ev.electric_vehicles_sold) as sales_2022
FROM electric_vehicle_sales_by_state ev 
JOIN dim_date d ON d.date = ev.date
JOIN t10sp on ev.state = t10sp.state
WHERE fiscal_year = 2022
GROUP BY t10sp.state
)
SELECT sales22.state, sales_2022, CAGR_CTE.CAGR, round(sales_2022*power(1+ CAGR,8),2) AS projection_2030
FROM sales22 
JOIN CAGR_CTE ON sales22.state = CAGR_CTE.state
GROUP BY sales22.state, sales_2022, CAGR_CTE.CAGR
ORDER BY projection_2030 DESC;



-- 10. Estimate the revenue growth rate of 4-wheeler and 2-wheelers EVs in India for 2022 vs 2024 and 2023 vs 2024, assuming an average unit price. H

WITH cte AS (
SELECT m.vehicle_category, d.fiscal_year,
CASE 
	WHEN m.vehicle_category = '2-Wheelers' THEN SUM(CAST(m.electric_vehicles_sold AS BIGINT) * 85000) 
	ELSE SUM(CAST(m.electric_vehicles_sold AS BIGINT) * 1500000)
END AS revenue_growth
FROM dim_date d
JOIN electric_vehicle_sales_by_makers m ON d.date = m.date
GROUP BY m.vehicle_category, d.fiscal_year
)
SELECT vehicle_category,
CONCAT(FORMAT(100.0 * (SUM(CASE WHEN fiscal_year = 2024 THEN revenue_growth END) - SUM(CASE WHEN fiscal_year = 2022 THEN revenue_growth END)) /
SUM(CASE WHEN fiscal_year = 2022 THEN revenue_growth END), '000.00'), ' %') AS revenue_growth_rate_2022_vs_2024,
CONCAT(FORMAT(100.0 * (SUM(CASE WHEN fiscal_year = 2024 THEN revenue_growth END) - SUM(CASE WHEN fiscal_year = 2023 THEN revenue_growth END)) /
SUM(CASE WHEN fiscal_year = 2023 THEN revenue_growth END), '00.00'), ' %') AS revenue_growth_rate_2023_vs_2024
FROM cte
GROUP BY vehicle_category;











































































































































