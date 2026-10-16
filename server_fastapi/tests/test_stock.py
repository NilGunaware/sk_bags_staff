"""Exercise production stock SQL with a small Busy-shaped database fixture."""
import re
import sqlite3
import unittest

from app.service import ITEM_BASE_CTE_DATED_STOCK, _load_branch_stocks


class BusyCursor:
    def __init__(self, connection):
        self.cursor = connection.cursor()

    def execute(self, sql, params=None):
        # SQLite supplies the same relational operations; freeze SQL Server's date bounds.
        sql = sql.replace(
            'DATEADD(month, 3, DATEADD(year, DATEDIFF(year, 0, DATEADD(month, -3, GETDATE())), 0))',
            "'2026-04-01'",
        ).replace("DATEADD(day, DATEDIFF(day, 0, GETDATE()) + 1, 0)", "'2026-10-17'")
        sql = sql.replace('dbo.', '').replace('ISNULL(', 'IFNULL(')
        sql = re.sub(r'%\((\w+)\)s', r':\1', sql)
        self.cursor.execute(sql, params or {})
        return self

    @property
    def description(self):
        return self.cursor.description

    def fetchall(self):
        return self.cursor.fetchall()


class StockTests(unittest.TestCase):
    def setUp(self):
        self.connection = sqlite3.connect(':memory:')
        self.addCleanup(self.connection.close)
        self.connection.executescript('''
            CREATE TABLE Master1 (Code INT, Name TEXT, Alias TEXT, MasterType INT, ParentGrp INT, HSNCode TEXT);
            CREATE TABLE MasterSupport (MasterCode INT, MasterType INT, I1 INT, D1 REAL, D2 REAL, D3 REAL, C1 TEXT);
            CREATE TABLE Tran1 (VchCode INT, VchCancelled INT, Cancelled INT);
            CREATE TABLE Tran4 (SrNo INT, MasterCode1 INT, MasterCode2 INT, RecType INT, D1 REAL, D3 REAL);
            CREATE TABLE Tran2 (VchCode INT, MasterCode1 INT, MasterCode2 INT, RecType INT, VchType INT, Date TEXT, Value1 REAL, Value3 REAL);
            INSERT INTO Master1 VALUES
                (3838, 'Carnaby', '36086', 6, NULL, ''),
                (201, 'Khargate', '', 11, NULL, ''),
                (14874, 'Sample', '', 11, NULL, ''),
                (19321, 'Narol', '', 11, NULL, '');
            INSERT INTO Tran4 VALUES
                (0, 3838, 201, 0, 1318, 13180),
                (0, 3838, 14874, 0, 2, 20);
            INSERT INTO Tran1 VALUES (8, 1, 0), (9, 0, 1);
        ''')
        # Real backup's physical totals plus its non-stock 1440 and 227 quantities.
        rows = [
            (1, 3838, 201, 2, 2, '2026-06-17', 1727),
            (2, 3838, 201, 2, 3, '2026-06-23', 33),
            (3, 3838, 201, 2, 9, '2026-10-16', -1987),
            (4, 3838, 201, 2, 5, '2026-04-28', -1),
            (4, 3838, 19321, 2, 5, '2026-04-28', 1),
            (5, 3838, 201, 4, 13, '2026-09-25', 1440),
            (6, 3838, 201, 20, 26, '2026-08-17', 227),
            (7, 3838, 201, 2, 2, '2026-10-17', 500),
            (8, 3838, 201, 2, 2, '2026-10-01', 100),
            (9, 3838, 201, 2, 2, '2026-10-01', 100),
            (10, 3838, 201, 2, 2, '2026-03-31', 500),
            (11, 9999, 201, 2, 2, '2026-10-01', 1000),
        ]
        self.connection.executemany('INSERT INTO Tran2 VALUES (?,?,?,?,?,?,?,?)',
            [(*row, row[-1] * 10) for row in rows])

    def test_branch_stock_excludes_non_stock_records_and_cancelled_or_out_of_period_movements(self):
        branches = _load_branch_stocks(BusyCursor(self.connection), 3838)
        self.assertEqual({b['branchName']: b['itemQuantity'] for b in branches},
            {'Khargate': 1090, 'Sample': 2, 'Narol': 1})
        self.assertEqual(sum(b['itemQuantityValue'] for b in branches), 10930)

    def test_item_base_uses_the_same_stock_record_filter(self):
        cursor = BusyCursor(self.connection)
        cursor.execute(ITEM_BASE_CTE_DATED_STOCK +
            " SELECT itemQuantity, itemQuantityValue FROM ItemBase WHERE itemCode='36086'")
        self.assertEqual(cursor.fetchall(), [(1093, 10930)])
