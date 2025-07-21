
/*	PONIØSZE ZAPYTANIE PRZYGOTOWUJE BAZ  DANYCH RECENZJI WIN Z PORTALU "WINE ENTHUSIAST" ZBIERANYCH DO 2017 ROKU.
	OBEJMUJE:
		- TWORZENIE NOWEJ BAZY DANYCH
		- TWORZENIE TABEL STG, WYMIAR”W I FAKTU. 
		- FUNKCJ , KT”REJ ZADANIEM JEST WYODR BNIENIE LICZB Z KOLUMNY "TITLE", KT”RE W P”èNIEJSZYM ETAPIE WYKORZYSTANE S• DO USTALENIA ROCZNIKA WINA.
		- PROCEDUR  WPROWADZENIA/AKTUALIZACJI DANYCH POBIERANYCH Z PLIKU JSON ORAZ PRZYPISYWANIE ODPOWIEDNICH ID DLA TABLEI FAKTU.

	***W LINIJCE 323 NALEØY WPROWADZI∆ åCIEØK  DO PLIKU JSON ZAWIERAJ•CEGO RECENZJE***

	PO PIERWSZYM WPROWADZENIU DANYCH DO TABEL, PROCEDUR  MOZNA POWT”RZY∆ AKTUALIZUJ•C "proUpdateData" ZMIENIAJ•C NAZW  PLIKU NA "winemag-data-130k-V5S",
	SYMULUJ•C SCENARIUSZ POBRANIA NOWYCH DANYCH I AKTUALIZACJI BAZY DANYCH.
*/
-----------------------------------------------------------------------------------	Tworzenie bazy danych
/*
DROP DATABASE IF EXISTS WineReviews
GO
*/

/*
CREATE DATABASE WineReviews
GO
USE WineReviews
*/

-----------------------------------------------------------------------------------	Tworzenie funkcji wyciπgania liczb z kolumny (przyda siÍ do ustalenia rocznika wina)
CREATE FUNCTION ufnWine_reviews_date (@InputString NVARCHAR(max)) 
RETURNS NVARCHAR(max) 
AS 
	BEGIN 
		WHILE Patindex('%[^0-9]%', @InputString) <> 0 
		BEGIN 
			SET @InputString = Stuff(@InputString, Patindex('%[^0-9]%', 
													@InputString),1, '') 
		END 
		RETURN @InputString 
	END
 GO

-----------------------------------------------------------------------------------	Tworzenie tabeli stg
CREATE TABLE Winemag_data
(
		title NVARCHAR (100),	
		points INT,
		description NVARCHAR(MAX), 
		taster_name NVARCHAR(200), 
		taster_twitter_handle NVARCHAR (200),
		price INT,
		designation NVARCHAR (100),
		variety NVARCHAR (100),
		region_1 NVARCHAR (100),
		region_2 NVARCHAR (100), 
		province NVARCHAR (100), 
		country VARCHAR (100), 
		winery NVARCHAR (100)
	)
GO

-----------------------------------------------------------------------------------	Tworzenie schema stg
 IF (NOT EXISTS (SELECT * FROM sys.schemas WHERE NAME = 'stg')) 
BEGIN
    EXEC ('CREATE SCHEMA [stg] AUTHORIZATION [dbo]')
END

ALTER SCHEMA stg
TRANSFER [dbo].[Winemag_data]
GO

-----------------------------------------------------------------------------------	Tworzenie tabel dim
-----------------------------------------	dimOrigin
DROP TABLE IF EXISTS dimOrigin
CREATE TABLE dimOrigin
(	Origin_ID INT IDENTITY PRIMARY KEY,
	Country VARCHAR(50),
	Province NVARCHAR(100),
	Region_1 NVARCHAR(100),
	Region_2 NVARCHAR(100)
)
-----------------------------------------	dimTaster
DROP TABLE IF EXISTS dimTaster
CREATE TABLE dimTaster
(	Taster_ID INT IDENTITY PRIMARY KEY,
	Taster_name NVARCHAR(200) NOT NULL, 
	Taster_twitter_handle NVARCHAR (200)
)
-----------------------------------------	dimVariety
DROP TABLE IF EXISTS dimVariety
CREATE TABLE dimVariety
(	Variety_ID INT IDENTITY PRIMARY KEY,
	Variety NVARCHAR(200) NOT NULL,
)
-----------------------------------------	dimWines
DROP TABLE IF EXISTS dimWines
CREATE TABLE dimWines
(	Wine_ID INT IDENTITY PRIMARY KEY,
	Title NVARCHAR(200) NOT NULL, 
	Designation NVARCHAR (100)
)
-----------------------------------------	dimWineries
DROP TABLE IF EXISTS dimWineries
CREATE TABLE dimWineries
(	Winery_ID INT IDENTITY PRIMARY KEY,
	Winery NVARCHAR(200) NOT NULL
)
GO

-----------------------------------------------------------------------------------	Procedura wyciπgania danych do tabel wymiarÛw - proDim
CREATE PROCEDURE proDim AS

DROP TABLE IF EXISTS #dimOrigin
SELECT
	country,
	province,
	region_1,
	region_2
INTO #dimOrigin FROM 
	(
		SELECT DISTINCT 
		country,
		province,
		region_1,
		region_2 
	
		FROM stg.Winemag_data
		WHERE country IS NOT NULL
	) AS Origin

MERGE dimOrigin AS TARGET
USING #dimOrigin AS SOURCE
ON		TARGET.country	= SOURCE.country
	AND TARGET.province	= SOURCE.province
	AND TARGET.region_1 = SOURCE.region_1
	AND TARGET.region_2 = SOURCE.region_2

	WHEN NOT MATCHED BY TARGET
	THEN
		INSERT
			(
			[country],
			[province],
			[region_1],
			[region_2]
			)
			 
		VALUES
			(
			SOURCE.[country],
			SOURCE.[province],
			SOURCE.[region_1],
			SOURCE.[region_2]
			)

	WHEN NOT MATCHED BY SOURCE 
	THEN DELETE;
-----------------------------------------	dimTaster
DROP TABLE IF EXISTS #dimTaster
SELECT
	taster_name,
	taster_twitter_handle
INTO #dimTaster FROM 
	(
	SELECT DISTINCT 
	taster_name,
	taster_twitter_handle
	
	FROM stg.Winemag_data
	WHERE taster_name IS NOT NULL
	) AS Teaster

MERGE dimTaster AS TARGET
USING #dimTaster AS SOURCE
ON		TARGET.taster_name				= SOURCE.taster_name

	WHEN NOT MATCHED BY TARGET
	THEN
		INSERT
			(
			taster_name,
			taster_twitter_handle
			)
			 
		VALUES
			(
			SOURCE.taster_name,
			SOURCE.taster_twitter_handle
			)

	WHEN MATCHED AND (TARGET.taster_twitter_handle <> SOURCE.taster_twitter_handle)
	THEN UPDATE SET TARGET.taster_twitter_handle = SOURCE.taster_twitter_handle

	WHEN NOT MATCHED BY SOURCE 
	THEN DELETE;
	
-----------------------------------------	dimVariety
DROP TABLE IF EXISTS #dimVariety
SELECT
	Variety
INTO #dimVariety FROM 
	(
		SELECT DISTINCT 
		Variety
	
		FROM stg.Winemag_data
		WHERE Variety  IS NOT NULL
	) 
	AS Variety

MERGE dimVariety AS TARGET
USING #dimVariety AS SOURCE
ON	TARGET.Variety = SOURCE.Variety

	WHEN NOT MATCHED BY TARGET
	THEN
		INSERT
			(
			Variety
			)
			 
		VALUES
			(
			SOURCE.Variety
			)

	WHEN NOT MATCHED BY SOURCE 
	THEN DELETE;
-----------------------------------------	dimWines
DROP TABLE IF EXISTS #dimWines
SELECT
	title,
	designation
INTO #dimWines FROM 
	(
	SELECT DISTINCT 
	title,
	designation 
	
	FROM stg.Winemag_data
	WHERE title IS NOT NULL
	) AS Wines

MERGE dimWines AS TARGET
USING #dimWines AS SOURCE
ON		TARGET.title				= SOURCE.title
	AND TARGET.designation			= SOURCE.designation

	WHEN NOT MATCHED BY TARGET
	THEN
		INSERT
			(
			title,
			designation
			)
			 
		VALUES
			(
			SOURCE.title,
			SOURCE.designation
			)

	WHEN NOT MATCHED BY SOURCE 
	THEN DELETE;
-----------------------------------------	dimWineries
DROP TABLE IF EXISTS #dimWineries
SELECT
	winery
INTO #dimWineries FROM 
	(
	SELECT DISTINCT 
	winery 
	
	FROM stg.Winemag_data
	WHERE winery IS NOT NULL
	) AS Wineries

MERGE dimWineries AS TARGET
USING #dimWineries AS SOURCE
ON	TARGET.winery =	SOURCE.winery

	WHEN NOT MATCHED BY TARGET
	THEN
		INSERT
			(
			winery
			)
			 
		VALUES
			(
			winery
			)

	WHEN NOT MATCHED BY SOURCE 
	THEN DELETE;
	GO

-----------------------------------------------------------------------------------	Tworzenie tabeli fct
DROP TABLE IF EXISTS fctWine_reviews
GO
CREATE TABLE fctWine_reviews
	(
		Origin_ID	INT,
		Variety_ID	INT,
		Wine_ID		INT,
		Winery_ID	INT,
		Taster_ID	INT,
		Vintage		INT,
		Points		INT,
		Price		INT,
		Description NVARCHAR(MAX)
	)
GO

-------------------------------------------------------------------------Zrzut  danych do STG----------------------------------------------------------------------------
CREATE PROCEDURE proUpdateData AS

TRUNCATE TABLE  stg.Winemag_data;

DROP TABLE IF EXISTS #Winemag_data_1;
DROP TABLE IF EXISTS #Winemag_data_2;

--------------------------------- pobieranie danych z JSON do tabeli tymczasowej #Winemag_data_1
DECLARE @json VARCHAR(max);
SELECT @json = Bulkcolumn
FROM OPENROWSET (BULK '...\winemag-data-130K-V5T.json', SINGLE_CLOB) AS j;

SELECT * INTO #Winemag_data_1 FROM Openjson (@json)
	WITH (
		title NVARCHAR (100),	
		points INT,
		description VARCHAR(max), 
		taster_name NVARCHAR(200), 
		taster_twitter_handle NVARCHAR (200),
		price INT,
		designation NVARCHAR (100),
		variety NVARCHAR (100),
		region_1 NVARCHAR (100),
		region_2 NVARCHAR (100), 
		province NVARCHAR (100), 
		country VARCHAR (100), 
		winery NVARCHAR (100)
	);

SELECT
		title		=ISNULL(title, 'N/A'), 
		points		=ISNULL(points, '0'),
		description	=ISNULL(description, 'N/A'), 
		taster_name	=ISNULL(taster_name, 'N/A'), 
		taster_twitter_handle=ISNULL(taster_twitter_handle, 'N/A'),
		price		=ISNULL(points, '0'),
		designation	=ISNULL(designation, 'N/A'),
		variety		=ISNULL(variety, 'N/A'),
		region_1	=ISNULL(region_1, 'N/A'),
		region_2	=ISNULL(region_2, 'N/A'), 
		province	=ISNULL(province, 'N/A'), 
		country		=ISNULL(country, 'N/A'),
		winery		=ISNULL(winery, 'N/A')
	
	INTO #Winemag_data_2 FROM #Winemag_data_1

	INSERT INTO stg.Winemag_data
	SELECT * FROM #Winemag_data_2

-------------------------------------------------------------------------Zrzut danych do FCT ----------------------------------------------------------------------------

DROP TABLE IF EXISTS #Winemag_data;
DROP TABLE IF EXISTS #Unique_SOURCE;
DROP TABLE IF EXISTS #Unique_SOURCE_1;
DROP TABLE IF EXISTS #Unique_SOURCE_2;


 
SELECT
		rok	=[DBO].[ufnWine_reviews_date](title),
		*
INTO #Winemag_data FROM stg.Winemag_data
		


--------------------------------- nadawanie poprawego foramtu roku i wstawianie do tabeli tymczasowej #Unique_SOURCE_1
SELECT DISTINCT  rok2 = CASE
						WHEN substring (rok, Patindex('%20%', rok), 4) < 1900 or substring (rok, Patindex('%20%', rok), 4) > 2017
						THEN 1950
						ELSE substring (rok, Patindex('%20%', rok), 4)
						END,
				rok3 = CASE
						WHEN substring (rok, Patindex('%199%', rok), 4) < 1900 or substring (rok, Patindex('%199%', rok), 4) > 2017
						THEN 1950
						ELSE substring (rok, Patindex('%199%', rok), 4)
						END,
					* 

	INTO #Unique_SOURCE_1 FROM #Winemag_data;

--------------------------------- nadawanie prawdziwego roku i wstawianie do tabeli tymczasowej #Unique_SOURCE_2
SELECT	
		vintage	=	CASE
					WHEN rok2 > 1950 
					THEN rok2
					ELSE rok3
					END,
		title, 
		points,
		description, 
		taster_name, 
		taster_twitter_handle,
		price,
		designation,
		variety,
		region_1,
		region_2, 
		province, 
		country, 
		winery 
INTO #Unique_SOURCE_2 FROM #Unique_SOURCE_1;

--------------------------------- Aktualizacja DIM

EXEC proDim

--------------------------------- JOIN - przypisanie numerÛw ID
DROP TABLE IF EXISTS #Wine_reviews

SELECT	
		dimOrigin.Origin_ID,
		dimVariety.Variety_ID,
		dimTaster.Taster_ID,
		dimWines.Wine_ID,
		dimWineries.Winery_ID,
		#Unique_SOURCE_2.Vintage,
		#Unique_SOURCE_2.Points,
		#Unique_SOURCE_2.Price,
		#Unique_SOURCE_2.Description

INTO #Wine_reviews

FROM	#Unique_SOURCE_2
LEFT JOIN	dimOrigin 
	ON	#Unique_SOURCE_2.Country	= dimOrigin.Country
	AND #Unique_SOURCE_2.Province	= dimOrigin.Province
	AND	#Unique_SOURCE_2.Region_1	= dimOrigin.Region_1
	AND	#Unique_SOURCE_2.Region_2	= dimOrigin.Region_2

LEFT JOIN	dimVariety 
	ON	#Unique_SOURCE_2.Variety	= dimVariety.Variety

LEFT JOIN	dimTaster
	ON	#Unique_SOURCE_2.Taster_name			= dimTaster.Taster_name
	AND #Unique_SOURCE_2.Taster_twitter_handle	= dimTaster.Taster_twitter_handle

LEFT JOIN	dimWines
	ON	#Unique_SOURCE_2.Title			= dimWines.Title
	AND #Unique_SOURCE_2.Designation	= dimWines.Designation

LEFT JOIN	dimWineries
	ON	#Unique_SOURCE_2.Winery		= dimWineries.Winery
	
---------------------------------  MERGE - aktualizacja starych danych i dodanie nowych
MERGE fctWine_reviews AS TARGET
USING #Wine_reviews AS SOURCE
ON TARGET.description = SOURCE.description
AND TARGET.wine_ID = SOURCE.wine_ID

	WHEN NOT MATCHED BY TARGET
	THEN
		INSERT
			(
			Origin_ID,
			Variety_ID,
			Wine_ID	,
			Winery_ID,
			Taster_ID,
			Vintage,
			Points,
			Price,
			Description 
			)
			 
		VALUES
			( 
			SOURCE.Origin_ID,
			SOURCE.Variety_ID, 
			SOURCE.Wine_ID,
			SOURCE.Winery_ID,
			SOURCE.Taster_ID,
			SOURCE.Vintage,
			SOURCE.Points,
			SOURCE.Price, 
			SOURCE.Description
			)

	WHEN MATCHED AND 
			
			[TARGET].Origin_ID		<>[SOURCE].Origin_ID
		OR	[TARGET].Variety_ID		<>[SOURCE].Variety_ID
		OR	[TARGET].Winery_ID		<>[SOURCE].Winery_ID
		OR	[TARGET].Taster_ID		<>[SOURCE].Taster_ID
		OR	[TARGET].Vintage		<>[SOURCE].Vintage
		OR	[TARGET].Points			<>[SOURCE].Points
		OR	[TARGET].Price			<>[SOURCE].Price

	THEN UPDATE SET
			 
			[TARGET].Origin_ID		=[SOURCE].Origin_ID,
			[TARGET].Variety_ID		=[SOURCE].Variety_ID,
			[TARGET].Winery_ID		=[SOURCE].Winery_ID,
			[TARGET].Taster_ID		=[SOURCE].Taster_ID,
			[TARGET].Vintage		=[SOURCE].Vintage,
			[TARGET].Points			=[SOURCE].Points,
			[TARGET].Price			=[SOURCE].Price

	WHEN NOT MATCHED BY SOURCE 
	THEN DELETE;

SELECT * FROM fctWine_reviews
GO

EXEC proUpdateData