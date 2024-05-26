SELECT *
FROM worldlifeexpectancy;

# Column Name are all good, no need to fix
# Create a staging table to work with
CREATE TABLE worldlifeexpectancy_staging2 AS
SELECT *
FROM worldlifeexpectancy;

# Remove Duplicates
DELETE FROM worldlifeexpectancy_staging2
WHERE Row_ID IN (
	SELECT Row_ID
	FROM (
		SELECT *, ROW_NUMBER() OVER (PARTITION BY Country, Year) AS duplicates
		FROM worldlifeexpectancy_staging2
	) AS temp
	WHERE duplicates > 1
);

# Standardize Data
SELECT *
FROM worldlifeexpectancy_staging2;

-- empty values should be replaced with Null
DELIMITER $$
CREATE PROCEDURE convert_empty()
BEGIN
	UPDATE worldlifeexpectancy_staging2
    SET status = NULL
    WHERE status = '';
    UPDATE worldlifeexpectancy_staging2
    SET `Life expectancy` = NULL
    WHERE `Life expectancy` = '';
    UPDATE worldlifeexpectancy_staging2
    SET `Life expectancy` = NULL
    WHERE `Life expectancy` = '';
END $$
DELIMITER ;

CALL convert_empty();

-- `Life expectancy` data type should be double
ALTER TABLE worldlifeexpectancy_staging2
MODIFY COLUMN `Life expectancy` DOUBLE;

# Fix Null
-- Fix Null values if possible, Status and `Life expectancy`
SELECT *
FROM worldlifeexpectancy_staging2
WHERE Status IS NULL;

-- Based on the Development Status of Next Year to fill Null Values
UPDATE worldlifeexpectancy_staging2
SET Status = (
	SELECT table2_status
	FROM (
		SELECT table1.Year AS table1_year, table1.Status AS table1_status, table1.Row_ID AS table1_rowId, table2.Year AS table2_year, table2.Status AS table2_status
		FROM worldlifeexpectancy_staging2 AS table1
		JOIN worldlifeexpectancy_staging2 AS table2
		ON table1.Row_ID = table2.Row_ID + 1
	) AS temp
    WHERE temp.table1_rowId = worldlifeexpectancy_staging2.Row_ID
)
WHERE Status IS NULL;

-- Based on the average value `Life expectancy` of Previous Year and Next Year to fill Null Values
SELECT *
FROM worldlifeexpectancy_staging2
WHERE `Life expectancy` IS NULL;

UPDATE worldlifeexpectancy_staging2
SET `Life expectancy` = (
	SELECT avg_life
    FROM (
		SELECT table1.Country AS table1_country, 
        table2.Country AS table2_country, 
        table3.Country AS table3_country, 
        table1.Row_ID AS table1_rowID,
        table2.Row_ID AS table2_rowID,
        table3.Row_ID AS table3_rowID,
        (table2.`Life expectancy` + table3.`Life expectancy`)/2 AS avg_life
		FROM worldlifeexpectancy_staging2 AS table1
		JOIN worldlifeexpectancy_staging2 AS table2
		ON table1.Row_ID = table2.Row_ID + 1
		JOIN worldlifeexpectancy_staging2 AS table3
		ON table1.Row_ID = table3.Row_ID - 1
    ) AS temp
    WHERE temp.table1_rowID = worldlifeexpectancy_staging2.Row_ID
)
WHERE `Life expectancy` IS NULL;

UPDATE worldlifeexpectancy_staging2
SET `Life expectancy` = ROUND(`Life expectancy`, 1);

# Remove Useless Columns
ALTER TABLE worldlifeexpectancy_staging2
DROP COLUMN Row_ID;

SELECT *
FROM worldlifeexpectancy_staging2;