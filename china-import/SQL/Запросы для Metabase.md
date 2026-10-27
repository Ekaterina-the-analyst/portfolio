# 01. Базовые запросы по общим данным
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
2. Структура импорта по продукта
```sql
-- Доли Топ-3 продуктов + «прочие» за весь период
-- Топ-3 определяются по суммарному импорту 
-- «прочие» всегда последние

WITH product_totals AS (
    SELECT
        product,
        SUM(units) AS total_units
    FROM china_imp
    GROUP BY product
),
ranked AS (
    SELECT
        product,
        total_units,
        ROW_NUMBER() OVER (ORDER BY total_units DESC) AS rn
    FROM product_totals
),
grouped AS (
    SELECT
        CASE
            WHEN rn <= 3 THEN product
            ELSE 'прочие'
        END AS product_group,
        CASE
            WHEN rn <= 3 THEN 0
            ELSE 1
        END AS sort_flag,
        SUM(total_units) AS total_units
    FROM ranked
    GROUP BY product_group, sort_flag
),
grand AS (
    SELECT SUM(total_units) AS grand_total FROM grouped
)
SELECT
    g.product_group,
    g.total_units,
    ROUND(g.total_units * 100.0 / gr.grand_total, 1) AS share_pct
FROM grouped g
CROSS JOIN grand gr
ORDER BY g.sort_flag, g.total_units DESC;
```
# Запросы для расчета CAGR

1. CAGR 2015 - 2020 по общим данным
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

2. CAGR 2020 - 2023 по общим данным
```sql
WITH yearly_data AS (
    SELECT 
        year,
        SUM(units) AS total_qty
    FROM china_imp
    WHERE year BETWEEN 2020 AND 2023
    GROUP BY year
),
first_last AS (
    SELECT
        (SELECT total_qty FROM yearly_data WHERE year = 2020) AS qty_2020,
        (SELECT total_qty FROM yearly_data WHERE year = 2023) AS qty_2023
)
SELECT 
    (POWER(qty_2023 * 1.0 / qty_2020, 1.0 / 3.0) - 1) AS cagr_decimal
FROM first_last;
```

3. CAGR 2023 - 2025 по общим данным
```sql
WITH yearly_data AS (
    SELECT 
        year,
        SUM(units) AS total_qty
    FROM china_imp
    WHERE year BETWEEN 2023 AND 2025
    GROUP BY year
),
first_last AS (
    SELECT
        (SELECT total_qty FROM yearly_data WHERE year = 2023) AS qty_2023,
        (SELECT total_qty FROM yearly_data WHERE year = 2025) AS qty_2025
)
SELECT 
    (POWER(qty_2025 * 1.0 / qty_2023, 1.0 / 2.0) - 1) AS cagr_decimal
FROM first_last;
```

4. Таблица CAGR по всем продуктам и периодам
```sql
-- CAGR по продуктам и периодам в виде таблицы
-- Периоды: 2015-2020 (n=5), 2020-2023 (n=3), 2023-2025 (n=2)
-- Формула: (End / Start)^(1/n) - 1

WITH yearly AS (
    SELECT
        product,
        year,
        SUM(units) AS total_qty
    FROM china_imp
    WHERE year BETWEEN 2015 AND 2025
    GROUP BY product, year
),
pivoted AS (
    SELECT
        product,
        MAX(CASE WHEN year = 2015 THEN total_qty END) AS q_2015,
        MAX(CASE WHEN year = 2020 THEN total_qty END) AS q_2020,
        MAX(CASE WHEN year = 2023 THEN total_qty END) AS q_2023,
        MAX(CASE WHEN year = 2025 THEN total_qty END) AS q_2025
    FROM yearly
    GROUP BY product
)
SELECT
    product as Продукт,
    CASE 
        WHEN q_2015 > 0 AND q_2020 IS NOT NULL 
        THEN POWER(q_2020 * 1.0 / q_2015, 1.0 / 5.0) - 1 
    END AS cagr_2015_2020,
    CASE 
        WHEN q_2020 > 0 AND q_2023 IS NOT NULL 
        THEN POWER(q_2023 * 1.0 / q_2020, 1.0 / 3.0) - 1 
    END AS cagr_2020_2023,
    CASE 
        WHEN q_2023 > 0 AND q_2025 IS NOT NULL 
        THEN POWER(q_2025 * 1.0 / q_2023, 1.0 / 2.0) - 1 
    END AS cagr_2023_2025
FROM pivoted
WHERE q_2015 IS NOT NULL 
   OR q_2020 IS NOT NULL 
   OR q_2023 IS NOT NULL
ORDER BY product;
```
