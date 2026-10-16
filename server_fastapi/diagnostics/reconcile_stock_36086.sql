-- Run in SSMS against the SAME database selected in Busy and the desktop API.
-- Read-only: no stock or voucher records are modified.
SET NOCOUNT ON;

DECLARE @ItemCode nvarchar(50) = N'36086';
DECLARE @AsOn date = CONVERT(date, GETDATE()); -- Match the Busy report date.
DECLARE @YearStart date = DATEFROMPARTS(
    YEAR(@AsOn) - CASE WHEN MONTH(@AsOn) < 4 THEN 1 ELSE 0 END, 4, 1
);
DECLARE @MasterCode int = (
    SELECT MIN(Code) FROM dbo.Master1
    WHERE MasterType = 6 AND Alias = @ItemCode
);

SELECT 'Context' AS Section, DB_NAME() AS DatabaseName,
    GETDATE() AS ServerDateTime, @AsOn AS AsOnDate, @YearStart AS YearStart,
    @MasterCode AS ItemMasterCode;

SELECT 'Matching items' AS Section, Code, Alias, Name
FROM dbo.Master1 WHERE MasterType = 6 AND Alias = @ItemCode;

-- Reproduce the previous API formula to expose non-stock transaction inflation.
;WITH StockLines AS (
    SELECT t.MasterCode2 AS BranchCode, 'Opening' AS Source,
        CAST(ISNULL(t.D1, 0) AS decimal(18, 2)) AS Qty
    FROM dbo.Tran4 t
    LEFT JOIN dbo.Tran1 v ON v.VchCode = t.SrNo
    WHERE t.RecType = 0 AND t.MasterCode1 = @MasterCode
      AND (v.VchCode IS NULL OR
          (ISNULL(v.VchCancelled, 0) = 0 AND ISNULL(v.Cancelled, 0) = 0))
    UNION ALL
    SELECT t.MasterCode2, 'Movement',
        CAST(ISNULL(t.Value1, 0) AS decimal(18, 2))
    FROM dbo.Tran2 t
    LEFT JOIN dbo.Tran1 v ON v.VchCode = t.VchCode
    WHERE t.MasterCode1 = @MasterCode
      AND t.Date >= @YearStart AND t.Date < DATEADD(day, 1, @AsOn)
      AND t.VchType <> 26
      AND (v.VchCode IS NULL OR
          (ISNULL(v.VchCancelled, 0) = 0 AND ISNULL(v.Cancelled, 0) = 0))
)
SELECT 'Previous API components' AS Section, s.BranchCode, b.Name AS BranchName,
    s.Source, COUNT(*) AS [RowCount], SUM(s.Qty) AS Qty
FROM StockLines s
LEFT JOIN dbo.Master1 b ON b.Code = s.BranchCode AND b.MasterType = 11
GROUP BY s.BranchCode, b.Name, s.Source
ORDER BY s.BranchCode, s.Source;

-- Include excluded voucher types and cancelled rows for comparison with Busy.
SELECT 'Movements by type and cancellation' AS Section,
    t.MasterCode2 AS BranchCode, t.RecType, t.VchType,
    ISNULL(v.VchCancelled, 0) AS VchCancelled,
    ISNULL(v.Cancelled, 0) AS Cancelled,
    CASE WHEN v.VchCode IS NULL THEN 0 ELSE 1 END AS HasVoucherHeader,
    COUNT(*) AS [RowCount],
    SUM(CAST(ISNULL(t.Value1, 0) AS decimal(18, 2))) AS Qty,
    MIN(t.Date) AS FirstDate, MAX(t.Date) AS LastDate
FROM dbo.Tran2 t
LEFT JOIN dbo.Tran1 v ON v.VchCode = t.VchCode
WHERE t.MasterCode1 = @MasterCode
  AND t.Date >= @YearStart AND t.Date < DATEADD(day, 1, @AsOn)
GROUP BY t.MasterCode2, t.RecType, t.VchType, ISNULL(v.VchCancelled, 0),
    ISNULL(v.Cancelled, 0), CASE WHEN v.VchCode IS NULL THEN 0 ELSE 1 END
ORDER BY t.MasterCode2, t.VchType;

SELECT 'Opening rows by record type' AS Section,
    MasterCode2 AS BranchCode, RecType, COUNT(*) AS [RowCount],
    SUM(CAST(ISNULL(D1, 0) AS decimal(18, 2))) AS Qty
FROM dbo.Tran4 WHERE MasterCode1 = @MasterCode
GROUP BY MasterCode2, RecType ORDER BY MasterCode2, RecType;

SELECT 'Folio comparison (not a replacement formula)' AS Section,
    COUNT(*) AS [RowCount],
    SUM(CAST(ISNULL(D1, 0) AS decimal(18, 2))) AS Qty
FROM dbo.Folio1 WHERE MasterCode = @MasterCode;

-- Detect joins that could multiply movement/opening quantities.
SELECT 'Repeated voucher header keys' AS Section, v.VchCode,
    COUNT(*) AS HeaderRows
FROM dbo.Tran1 v
WHERE EXISTS (SELECT 1 FROM dbo.Tran2 t
    WHERE t.MasterCode1 = @MasterCode AND t.VchCode = v.VchCode)
   OR EXISTS (SELECT 1 FROM dbo.Tran4 t
    WHERE t.MasterCode1 = @MasterCode AND t.SrNo = v.VchCode)
GROUP BY v.VchCode HAVING COUNT(*) > 1;

SELECT 'Stock table columns' AS Section, TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME IN ('Tran1', 'Tran2', 'Tran4', 'Folio1')
ORDER BY TABLE_NAME, ORDINAL_POSITION;
