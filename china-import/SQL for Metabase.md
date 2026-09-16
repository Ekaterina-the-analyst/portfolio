# Запросы SQL для визуализаций

1. Запрос для гистограммы сравнения имеющихся данных за 2026 год с соответствующим периодом прошлого года

```sql
SELECT
    CONCAT(year, '') AS year,
    SUM(units) AS units
FROM china_imp
WHERE year IN ('2025', '2026')
  AND month <= (SELECT MAX(month) FROM china_imp WHERE year = '2026')
GROUP BY year;
```
2. Запрос для расчета CAGR

```sql
WITH yearly_data AS (
    SELECT 
        year,
        SUM(units) AS total_qty
    FROM china_imp
    WHERE year BETWEEN 2015 AND 2020
    GROUP BY year
),
first_last AS (
    SELECT
        (SELECT total_qty FROM yearly_data WHERE year = 2015) AS qty_2015,
        (SELECT total_qty FROM yearly_data WHERE year = 2020) AS qty_2020
)
SELECT 
    (POWER(qty_2020 * 1.0 / qty_2015, 1.0 / 5.0) - 1) AS cagr_decimal
FROM first_last;
```
   
