import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDb {
  AppDb._();
  static final instance = AppDb._();
  Database? _db;
  Database get db => _db!;

  Future<void> init() async {
    final path = join(await getDatabasesPath(), 'lakshmi_chit_manager.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE templates(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          months INTEGER NOT NULL,
          members INTEGER NOT NULL,
          installment INTEGER NOT NULL,
          due_day INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE groups_tbl(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          template_id INTEGER NOT NULL,
          start_date TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE members(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          mobile TEXT NOT NULL,
          address TEXT,
          group_id INTEGER NOT NULL,
          member_no INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE payments(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          member_id INTEGER NOT NULL,
          month_no INTEGER NOT NULL,
          due_amount INTEGER NOT NULL,
          paid_amount INTEGER NOT NULL DEFAULT 0,
          paid_date TEXT,
          status TEXT NOT NULL,
          mode TEXT NOT NULL,
          notes TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE ledger(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          amount INTEGER NOT NULL,
          date TEXT NOT NULL,
          member_id INTEGER,
          group_id INTEGER,
          category TEXT NOT NULL,
          notes TEXT
        )
      ''');

      // Based on the user's supplied 25-month scheme image.
      await db.insert('templates', {
        'name': '25 Months - ₹16,000',
        'months': 25,
        'members': 25,
        'installment': 16000,
        'due_day': 5,
      });
    });
  }

  Future<int> addTemplate(String name, int months, int members, int installment, int dueDay) =>
      db.insert('templates', {'name':name,'months':months,'members':members,'installment':installment,'due_day':dueDay});

  Future<List<Map<String,Object?>>> templates() => db.query('templates', orderBy: 'id DESC');

  Future<int> addGroup(String name, int templateId, DateTime start) =>
      db.insert('groups_tbl', {'name':name,'template_id':templateId,'start_date':start.toIso8601String()});

  Future<List<Map<String,Object?>>> groups() => db.rawQuery('''
    SELECT g.*, t.name template_name, t.months, t.members, t.installment, t.due_day
    FROM groups_tbl g JOIN templates t ON g.template_id=t.id ORDER BY g.id DESC
  ''');

  Future<int> addMember(String name, String mobile, String address, int groupId, int memberNo) =>
      db.insert('members', {'name':name,'mobile':mobile,'address':address,'group_id':groupId,'member_no':memberNo});

  Future<List<Map<String,Object?>>> members() => db.rawQuery('''
    SELECT m.*, g.name group_name, t.installment, t.name template_name, t.months, t.due_day
    FROM members m JOIN groups_tbl g ON m.group_id=g.id JOIN templates t ON g.template_id=t.id
    ORDER BY m.name
  ''');

  Future<Map<String,int>> dashboard() async {
    final groups = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM groups_tbl')) ?? 0;
    final members = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM members')) ?? 0;
    final received = Sqflite.firstIntValue(await db.rawQuery("SELECT COALESCE(SUM(amount),0) FROM ledger WHERE type='IN'")) ?? 0;
    final given = Sqflite.firstIntValue(await db.rawQuery("SELECT COALESCE(SUM(amount),0) FROM ledger WHERE type='OUT'")) ?? 0;
    final outstanding = Sqflite.firstIntValue(await db.rawQuery("SELECT COALESCE(SUM(due_amount-paid_amount),0) FROM payments WHERE due_amount>paid_amount")) ?? 0;
    return {'groups':groups,'members':members,'received':received,'given':given,'outstanding':outstanding};
  }
}
