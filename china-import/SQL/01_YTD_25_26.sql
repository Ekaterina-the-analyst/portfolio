
# Запрос для гистограммы сравнения имеющихся данных за 2026 год с соответствующим периодом прошлого года
SELECT
    CONCAT(year, '') AS year,
    SUM(units) AS units
FROM china_imp
WHERE year IN ('2025', '2026')
  AND month <= (SELECT MAX(month) FROM china_imp WHERE year = '2026')
GROUP BY year;
