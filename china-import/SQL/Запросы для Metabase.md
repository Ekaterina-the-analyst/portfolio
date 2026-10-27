# SQL-Запросы для Metabase
Часть графиков отчета строится через конструктор Metabase. Для более сложных используются sql-запросы, продублированные в этом файле

## Базовые запросы по общим данным
### 1. Запрос для гистограммы сравнения имеющихся данных за 2026 год с соответствующим периодом прошлого года
```sql
SELECT
    CONCAT(year, '') AS year,
    SUM(units) AS units
FROM china_imp
WHERE year IN ('2025', '2026')
  AND month <= (SELECT MAX(month) FROM china_imp WHERE year = '2026')
GROUP BY year;
```
### 2. Структура импорта по продукта
```sql
-- Top-3 продукта + «прочие» за весь период (Top-3 определяется по суммарному импорту)
-- сортировка с учетом "прочих" в конце

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
### 3. Запрос для расчета, во сколько раз вырос импорт по продуктам
```sql
-- Во сколько раз выросли units с 2015 по 2025 по продуктам
SELECT
    product,
    ROUND(
        MAX(CASE WHEN year = 2025 THEN total_units END) * 1.0
        / NULLIF(MAX(CASE WHEN year = 2015 THEN total_units END), 0),
        1
    ) AS growth_ratio
FROM (
    SELECT
        product,
        year,
        SUM(units) AS total_units
    FROM china_imp
    WHERE year IN ('2015', '2025')
    GROUP BY product, year
) AS yearly
GROUP BY product
ORDER BY growth_ratio DESC;
```
### 4. Запросы для расчета изменения долей продуктов

```sql
-- Доли продуктов в общем импорте — только КРУПНЫЕ (доля >= 15% в 2025)

WITH yearly_total AS (
    SELECT year, SUM(units) AS grand_total
    FROM china_imp
    WHERE year IN ('2015', '2025')
    GROUP BY year
),
product_year AS (
    SELECT product, year, SUM(units) AS product_total
    FROM china_imp
    WHERE year IN ('2015', '2025')
    GROUP BY product, year
),
shares AS (
    SELECT
        py.product,
        py.year,
        ROUND(py.product_total  / yt.grand_total, 2) AS share_pct
    FROM product_year py
    JOIN yearly_total yt ON py.year = yt.year
),
product_groups AS (
    SELECT
        product,
        MAX(CASE WHEN year = '2025' THEN share_pct END) AS share_2025,
        CASE
            WHEN MAX(CASE WHEN year = '2025' THEN share_pct END) >= 0.15 THEN 'Крупные'
            ELSE 'Мелкие'
        END AS product_group
    FROM shares
    GROUP BY product
)
SELECT
    s.product,
    s.year,
    s.share_pct
FROM shares s
JOIN product_groups pg ON s.product = pg.product
WHERE pg.product_group = 'Крупные'
-- Аналогичный запрос для мелких продуктов
ORDER BY s.product, s.year;
```

### 5. Динамика средних цен

```sql
-- Изменение средней цены за штуку: 2015 → 2025, в %
WITH product_year AS (
    SELECT
        product,
        year,
        SUM(units) AS total_units,
        SUM(usd) AS total_usd
    FROM china_imp
    WHERE year IN ('2015', '2025')
    GROUP BY product, year
),
prices AS (
    SELECT
        product,
        MAX(CASE WHEN year = '2015' THEN total_usd * 1.0 / NULLIF(total_units, 0) END) AS price_2015,
        MAX(CASE WHEN year = '2025' THEN total_usd * 1.0 / NULLIF(total_units, 0) END) AS price_2025
    FROM product_year
    GROUP BY product
)
SELECT
    product as 'продукт',
    ROUND(price_2015, 0) AS 'цена_2015',
    ROUND(price_2025, 0) AS 'цена_2025',
    ROUND((price_2025  / NULLIF(price_2015, 0) - 1) , 2) AS 'изменение'
FROM prices
WHERE price_2015 IS NOT NULL AND price_2025 IS NOT NULL
ORDER BY ROUND((price_2025  / NULLIF(price_2015, 0) - 1) , 2) DESC;
```
## Запросы для расчета CAGR

### 1. CAGR 2015 - 2020 по общим данным
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
-- аналогичные запросы для других периодов.
--  (POWER(qty_2023 * 1.0 / qty_2020, 1.0 / 3.0) - 1) AS cagr_decimal
--  (POWER(qty_2025 * 1.0 / qty_2023, 1.0 / 2.0) - 1) AS cagr_decimal
FROM first_last;
```

### 2. Таблица CAGR по всем продуктам и периодам
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
