-- =====================================================================
-- 4 užduotis — Mantas Kaminskas
-- MS SQL Server (T-SQL), paleidžiama per SSMS
-- =====================================================================

USE telekomunikacijos;
GO

-- 1. Abonentas: atributas nuolaida DECIMAL(3,2) NOT NULL DEFAULT 0,00
ALTER TABLE Abonentas
ADD nuolaida DECIMAL(3,2) NOT NULL
    CONSTRAINT DF_Abonentas_nuolaida DEFAULT 0.00;
GO

-- 2. Asmuo: atributas elPastas VARCHAR(50) NULL
ALTER TABLE Asmuo
ADD elPastas VARCHAR(50) NULL;
GO

-- 3. Lentelė Domenas (domenoID su IDENTITY)
CREATE TABLE Domenas (
    domenoID    INT IDENTITY(1,1) PRIMARY KEY,
    pavadinimas VARCHAR(15)
);
GO

-- 4. Domenų įrašai
INSERT INTO Domenas (pavadinimas)
VALUES ('gmail.com'),
       ('yahoo.com'),
       ('hotmail.com'),
       ('eif.viko.lt');
GO

-- 5. El. paštas kiekvienam asmeniui: vardas.pavarde@domenas,
--    domenas parenkamas atsitiktinai.
--    Kiekvienam asmeniui sugeneruojamas atsitiktinis numeris (NEWID()
--    skaičiuojamas kiekvienai eilutei atskirai), išsaugomas laikinoje
--    lentelėje, tada pagal jį prijungiamas domenas.
DROP TABLE IF EXISTS #AsmuoDomenas;

SELECT a.asmensID,
       ABS(CHECKSUM(NEWID())) % (SELECT COUNT(*) FROM Domenas) + 1 AS nr
INTO #AsmuoDomenas
FROM Asmuo a;

WITH D AS (
    SELECT pavadinimas,
           ROW_NUMBER() OVER (ORDER BY domenoID) AS nr
    FROM Domenas
)
UPDATE a
SET a.elPastas = LOWER(a.vardas + '.' + a.pavarde + '@' + D.pavadinimas)
FROM Asmuo a
JOIN #AsmuoDomenas t ON t.asmensID = a.asmensID
JOIN D               ON D.nr = t.nr;

DROP TABLE #AsmuoDomenas;
GO

-- 6. Lentelė Mob_telefonas
--    mobTelID su IDENTITY, nes .txt faile šis stulpelis tuščias.
--    "kaina/men" turi '/', todėl rašomas laužtiniuose skliaustuose.
CREATE TABLE Mob_telefonas (
    mobTelID    INT IDENTITY(1,1) PRIMARY KEY,
    gamintojas  VARCHAR(15),
    modelis     VARCHAR(30),
    kaina       FLOAT,
    [kaina/men] FLOAT
);
GO

-- 7. Abonentas: atributas mobTelID (NULL, nes ne visi perka telefoną)
ALTER TABLE Abonentas
ADD mobTelID INT NULL;
GO

-- 8. Išorinis raktas Abonentas.mobTelID -> Mob_telefonas.mobTelID
ALTER TABLE Abonentas
ADD CONSTRAINT FK_Abonentas_Mob_telefonas
    FOREIGN KEY (mobTelID) REFERENCES Mob_telefonas(mobTelID);
GO

-- 9. Mob_telefonas pildymas iš .txt su BULK INSERT
--    FIRSTROW = 2    -> praleidžiama antraštės eilutė
--    ROWTERMINATOR   -> failas su LF eilučių pabaigomis (0x0a);
--                       jei failas su CRLF, naudok '\n'
--    Be KEEPIDENTITY tušti mobTelID laukai ignoruojami, ID sugeneruoja IDENTITY.
BULK INSERT Mob_telefonas
FROM 'C:\dbvs-4-uzduotis\mobilieji-telefonai.txt'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0a'
);
GO

-- 10. Telefoną pasirinko abonentai, kurių sutarties pabaigos data neapibrėžta
--     (NULL). Kiekvienam parenkamas atsitiktinis telefonas.
DROP TABLE IF EXISTS #AbonentasTel;

SELECT ab.abonentoID,
       ABS(CHECKSUM(NEWID())) % (SELECT COUNT(*) FROM Mob_telefonas) + 1 AS nr
INTO #AbonentasTel
FROM Abonentas ab
WHERE ab.sutartiesPabaiga IS NULL;

WITH Tel AS (
    SELECT mobTelID,
           ROW_NUMBER() OVER (ORDER BY mobTelID) AS nr
    FROM Mob_telefonas
)
UPDATE ab
SET ab.mobTelID = Tel.mobTelID
FROM Abonentas ab
JOIN #AbonentasTel x ON x.abonentoID = ab.abonentoID
JOIN Tel             ON Tel.nr = x.nr;

DROP TABLE #AbonentasTel;
GO

-- Patikrinimas
SELECT * FROM Domenas;
SELECT asmensID, vardas, pavarde, elPastas FROM Asmuo;
SELECT * FROM Mob_telefonas;
SELECT abonentoID, sutartiesPabaiga, nuolaida, mobTelID FROM Abonentas;