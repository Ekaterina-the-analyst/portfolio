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
    (POWER(qty_2023 * 1.0 / qty_2020, 1.0 / 5.0) - 1) AS cagr_decimal
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
    (POWER(qty_2025 * 1.0 / qty_2023, 1.0 / 5.0) - 1) AS cagr_decimal
FROM first_last;
```
