import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDb {
  AppDb._();
  static final instance = AppDb._();
  Database? _db;
  Database get db => _db!;

  Future<void> init() async {
    final p = join(await getDatabasesPath(), 'lakshmi_chit_manager.db');
    _db = await openDatabase(
      p,
      version: 3,
      onCreate: (db, v) async {
        await db.execute('CREATE TABLE templates(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,months INTEGER NOT NULL,members INTEGER NOT NULL,installment INTEGER NOT NULL,due_day INTEGER NOT NULL,max_payout INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE groups_tbl(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,template_id INTEGER NOT NULL,start_date TEXT NOT NULL)');
        await db.execute('CREATE TABLE members(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,mobile TEXT NOT NULL,address TEXT,group_id INTEGER NOT NULL,member_no INTEGER NOT NULL,lift_month INTEGER,lift_amount INTEGER,lift_date TEXT)');
        await db.execute('CREATE TABLE payments(id INTEGER PRIMARY KEY AUTOINCREMENT,member_id INTEGER NOT NULL,month_no INTEGER NOT NULL,due_amount INTEGER NOT NULL,paid_amount INTEGER NOT NULL DEFAULT 0,paid_date TEXT,status TEXT NOT NULL,mode TEXT NOT NULL,notes TEXT)');
        await db.execute('CREATE TABLE ledger(id INTEGER PRIMARY KEY AUTOINCREMENT,type TEXT NOT NULL,amount INTEGER NOT NULL,date TEXT NOT NULL,member_id INTEGER,group_id INTEGER,category TEXT NOT NULL,notes TEXT)');
        await db.insert('templates', {'name': '25 Months - ₹16,000', 'months': 25, 'members': 25, 'installment': 16000, 'due_day': 5, 'max_payout': 500000});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE templates ADD COLUMN max_payout INTEGER NOT NULL DEFAULT 0');
          await db.execute("UPDATE templates SET max_payout = months * installment WHERE max_payout = 0");
        }
      },
    );
  }

  Future<List<Map<String, Object?>>> templates() => db.query('templates', orderBy: 'id DESC');

  Future<int> addTemplate(String n, int m, int mem, int inst, int due, int maxPayout) =>
      db.insert('templates', {
        'name': n,
        'months': m,
        'members': mem,
        'installment': inst,
        'due_day': due,
        'max_payout': maxPayout,
      });

  Future<void> updateTemplate(int id, String n, int m, int mem, int inst, int due, int maxPayout) =>
      db.update(
        'templates',
        {
          'name': n,
          'months': m,
          'members': mem,
          'installment': inst,
          'due_day': due,
          'max_payout': maxPayout,
        },
        where: 'id=?',
        whereArgs: [id],
      );

  Future<void> deleteTemplate(int id) async {
    final used = await db.query('groups_tbl', where: 'template_id=?', whereArgs: [id]);
    if (used.isNotEmpty) {
      throw Exception('This scheme is used by a group. Delete that group first.');
    }
    await db.delete('templates', where: 'id=?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> groups() => db.rawQuery(
        'SELECT g.*,t.name template_name,t.months,t.members,t.installment,t.due_day,t.max_payout FROM groups_tbl g JOIN templates t ON g.template_id=t.id ORDER BY g.id DESC',
      );

  Future<int> addGroup(String n, int t, DateTime d) =>
      db.insert('groups_tbl', {'name': n, 'template_id': t, 'start_date': d.toIso8601String()});

  Future<void> updateGroup(int id, String n, int t, DateTime d) =>
      db.update('groups_tbl', {'name': n, 'template_id': t, 'start_date': d.toIso8601String()}, where: 'id=?', whereArgs: [id]);

  Future<void> deleteGroup(int id) async {
    await db.transaction((tx) async {
      final ms = await tx.query('members', where: 'group_id=?', whereArgs: [id]);
      for (final m in ms) {
        await tx.delete('payments', where: 'member_id=?', whereArgs: [m['id']]);
        await tx.delete('ledger', where: 'member_id=?', whereArgs: [m['id']]);
      }
      await tx.delete('members', where: 'group_id=?', whereArgs: [id]);
      await tx.delete('groups_tbl', where: 'id=?', whereArgs: [id]);
    });
  }

  Future<List<Map<String, Object?>>> members() => db.rawQuery(
        'SELECT m.*,g.name group_name,t.name template_name,t.months,t.installment,t.due_day,t.max_payout FROM members m JOIN groups_tbl g ON m.group_id=g.id JOIN templates t ON g.template_id=t.id ORDER BY m.name',
      );

  Future<int> addMember(String n, String phone, String address, int gid, int no) =>
      db.insert('members', {'name': n, 'mobile': phone, 'address': address, 'group_id': gid, 'member_no': no});

  Future<void> updateMember(int id, String n, String phone, String address, int gid, int no) =>
      db.update('members', {'name': n, 'mobile': phone, 'address': address, 'group_id': gid, 'member_no': no}, where: 'id=?', whereArgs: [id]);

  Future<void> deleteMember(int id) async {
    await db.delete('payments', where: 'member_id=?', whereArgs: [id]);
    await db.delete('ledger', where: 'member_id=?', whereArgs: [id]);
    await db.delete('members', where: 'id=?', whereArgs: [id]);
  }

  Future<Map<String, Object?>?> member(int id) async {
    final r = await db.rawQuery(
      'SELECT m.*,g.name group_name,t.name template_name,t.months,t.members,t.installment,t.due_day,t.max_payout FROM members m JOIN groups_tbl g ON m.group_id=g.id JOIN templates t ON g.template_id=t.id WHERE m.id=?',
      [id],
    );
    return r.isEmpty ? null : r.first;
  }

  Future<List<Map<String, Object?>>> payments(int id) => db.query('payments', where: 'member_id=?', whereArgs: [id], orderBy: 'month_no');

  Future<void> savePayment({required int memberId, required int month, required int due, required int paid, required String status, required String mode, DateTime? date}) async {
    final old = await db.query('payments', where: 'member_id=? AND month_no=?', whereArgs: [memberId, month]);
    final vals = {
      'member_id': memberId,
      'month_no': month,
      'due_amount': due,
      'paid_amount': paid,
      'paid_date': date?.toIso8601String(),
      'status': status,
      'mode': mode,
      'notes': '',
    };
    final memberRows = await db.query('members', columns: ['group_id'], where: 'id=?', whereArgs: [memberId]);
    final groupId = memberRows.isEmpty ? null : memberRows.first['group_id'];
    await db.transaction((tx) async {
      if (old.isEmpty) {
        await tx.insert('payments', vals);
      } else {
        await tx.update('payments', vals, where: 'id=?', whereArgs: [old.first['id']]);
      }
      await tx.delete('ledger', where: 'member_id=? AND category=? AND notes=?', whereArgs: [memberId, 'Installment', 'Month $month']);
      if (paid > 0) {
        await tx.insert('ledger', {
          'type': 'IN',
          'amount': paid,
          'date': (date ?? DateTime.now()).toIso8601String(),
          'member_id': memberId,
          'group_id': groupId,
          'category': 'Installment',
          'notes': 'Month $month',
        });
      }
    });
  }

  Future<void> saveLift(int id, int month, int amount, DateTime date) async {
    final memberRows = await db.query('members', columns: ['group_id'], where: 'id=?', whereArgs: [id]);
    final groupId = memberRows.isEmpty ? null : memberRows.first['group_id'];
    await db.update('members', {'lift_month': month, 'lift_amount': amount, 'lift_date': date.toIso8601String()}, where: 'id=?', whereArgs: [id]);
    await db.delete('ledger', where: 'member_id=? AND category=?', whereArgs: [id, 'Chit Payout']);
    await db.insert('ledger', {
      'type': 'OUT',
      'amount': amount,
      'date': date.toIso8601String(),
      'member_id': id,
      'group_id': groupId,
      'category': 'Chit Payout',
      'notes': 'Lift month $month',
    });
  }

  Future<Map<String, int>> dashboard() async {
    final g = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM groups_tbl')) ?? 0;
    final m = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM members')) ?? 0;
    final r = Sqflite.firstIntValue(await db.rawQuery("SELECT COALESCE(SUM(amount),0) FROM ledger WHERE type='IN'")) ?? 0;
    final o = Sqflite.firstIntValue(await db.rawQuery("SELECT COALESCE(SUM(amount),0) FROM ledger WHERE type='OUT'")) ?? 0;
    final p = Sqflite.firstIntValue(await db.rawQuery("SELECT COALESCE(SUM(due_amount-paid_amount),0) FROM payments WHERE due_amount>paid_amount")) ?? 0;
    return {'groups': g, 'members': m, 'received': r, 'given': o, 'outstanding': p};
  }

  Future<Map<String, int>> analysis({String period = 'Yearly', required int year, int? month, int? quarter, int? groupId, int? templateId}) async {
    final ledgerRows = await db.query('ledger');
    final memberRows = await db.query('members', columns: ['id', 'group_id']);
    final groupRows = await db.query('groups_tbl', columns: ['id', 'template_id']);
    final paymentRows = await db.query('payments');
    final memberGroup = {for (final m in memberRows) m['id'] as int: m['group_id'] as int};
    final groupTemplate = {for (final g in groupRows) g['id'] as int: g['template_id'] as int};

    bool matchesDate(String raw) {
      final dt = DateTime.tryParse(raw);
      if (dt == null || dt.year != year) return false;
      if (period == 'Monthly') return dt.month == (month ?? DateTime.now().month);
      if (period == 'Quarterly') return ((dt.month - 1) ~/ 3 + 1) == (quarter ?? 1);
      return true;
    }

    bool matchesScope(int? memberId) {
      final gid = memberId == null ? null : memberGroup[memberId];
      final tid = gid == null ? null : groupTemplate[gid];
      if (groupId != null && gid != groupId) return false;
      if (templateId != null && tid != templateId) return false;
      return true;
    }

    var received = 0;
    var given = 0;
    for (final l in ledgerRows) {
      if (!matchesDate(l['date'] as String) || !matchesScope(l['member_id'] as int?)) continue;
      final amount = (l['amount'] as int?) ?? 0;
      if (l['type'] == 'IN') received += amount;
      if (l['type'] == 'OUT') given += amount;
    }

    var outstanding = 0;
    for (final p in paymentRows) {
      final memberId = p['member_id'] as int;
      if (!matchesScope(memberId)) continue;
      final date = p['paid_date'] as String?;
      if (date != null && !matchesDate(date)) continue;
      final due = (p['due_amount'] as int?) ?? 0;
      final paid = (p['paid_amount'] as int?) ?? 0;
      if (due > paid) outstanding += due - paid;
    }

    return {'received': received, 'given': given, 'net': received - given, 'outstanding': outstanding};
  }

  Future<List<Map<String, Object?>>> completedGroupProfits({int? groupId, int? templateId}) async {
    final gs = await groups();
    final ms = await db.query('members');
    final ls = await db.query('ledger');
    final now = DateTime.now();
    final result = <Map<String, Object?>>[];

    for (final g in gs) {
      final gid = g['id'] as int;
      final tid = g['template_id'] as int;
      if (groupId != null && gid != groupId) continue;
      if (templateId != null && tid != templateId) continue;

      final start = DateTime.tryParse(g['start_date'] as String);
      if (start == null) continue;
      final months = g['months'] as int;
      final end = DateTime(start.year, start.month + months - 1, start.day, 23, 59, 59);
      if (now.isBefore(end)) continue;

      final memberIds = ms.where((m) => m['group_id'] == gid).map((m) => m['id'] as int).toSet();
      var received = 0;
      var given = 0;
      for (final l in ls) {
        final mid = l['member_id'] as int?;
        if (mid == null || !memberIds.contains(mid)) continue;
        final amount = (l['amount'] as int?) ?? 0;
        if (l['type'] == 'IN') received += amount;
        if (l['type'] == 'OUT') given += amount;
      }

      result.add({
        'group': g['name'],
        'scheme': g['template_name'],
        'start_date': start,
        'end_date': end,
        'received': received,
        'given_out': given,
        'profit': received - given,
        'completed': true,
      });
    }
    return result;
  }

  Future<Map<String, List<Map<String, Object?>>>> backupData() async {
    return {
      'templates': await db.query('templates', orderBy: 'id'),
      'groups_tbl': await db.query('groups_tbl', orderBy: 'id'),
      'members': await db.query('members', orderBy: 'id'),
      'payments': await db.query('payments', orderBy: 'id'),
      'ledger': await db.query('ledger', orderBy: 'id'),
    };
  }

  int _intValue(Object? value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  Object? _nullableString(Object? value) {
    if (value == null) return null;
    final s = value.toString();
    return s.isEmpty ? null : s;
  }

  Future<void> restoreData(Map<String, List<Map<String, Object?>>> data) async {
    final templatesRows = data['templates'] ?? [];
    final groupsRows = data['groups_tbl'] ?? [];
    final membersRows = data['members'] ?? [];
    final paymentsRows = data['payments'] ?? [];
    final ledgerRows = data['ledger'] ?? [];

    if (templatesRows.isEmpty) throw Exception('Backup contains no schemes.');

    await db.transaction((tx) async {
      await tx.delete('ledger');
      await tx.delete('payments');
      await tx.delete('members');
      await tx.delete('groups_tbl');
      await tx.delete('templates');

      for (final r in templatesRows) {
        await tx.insert('templates', {
          'id': _intValue(r['id']),
          'name': r['name']?.toString() ?? '',
          'months': _intValue(r['months']),
          'members': _intValue(r['members']),
          'installment': _intValue(r['installment']),
          'due_day': _intValue(r['due_day'], 5),
          'max_payout': _intValue(r['max_payout']),
        });
      }
      for (final r in groupsRows) {
        await tx.insert('groups_tbl', {
          'id': _intValue(r['id']),
          'name': r['name']?.toString() ?? '',
          'template_id': _intValue(r['template_id']),
          'start_date': r['start_date']?.toString() ?? DateTime.now().toIso8601String(),
        });
      }
      for (final r in membersRows) {
        await tx.insert('members', {
          'id': _intValue(r['id']),
          'name': r['name']?.toString() ?? '',
          'mobile': r['mobile']?.toString() ?? '',
          'address': _nullableString(r['address']),
          'group_id': _intValue(r['group_id']),
          'member_no': _intValue(r['member_no']),
          'lift_month': r['lift_month'] == null ? null : _intValue(r['lift_month']),
          'lift_amount': r['lift_amount'] == null ? null : _intValue(r['lift_amount']),
          'lift_date': _nullableString(r['lift_date']),
        });
      }
      for (final r in paymentsRows) {
        await tx.insert('payments', {
          'id': _intValue(r['id']),
          'member_id': _intValue(r['member_id']),
          'month_no': _intValue(r['month_no']),
          'due_amount': _intValue(r['due_amount']),
          'paid_amount': _intValue(r['paid_amount']),
          'paid_date': _nullableString(r['paid_date']),
          'status': r['status']?.toString() ?? 'Pending',
          'mode': r['mode']?.toString() ?? 'Cash',
          'notes': r['notes']?.toString() ?? '',
        });
      }
      for (final r in ledgerRows) {
        await tx.insert('ledger', {
          'id': _intValue(r['id']),
          'type': r['type']?.toString() ?? 'IN',
          'amount': _intValue(r['amount']),
          'date': r['date']?.toString() ?? DateTime.now().toIso8601String(),
          'member_id': r['member_id'] == null ? null : _intValue(r['member_id']),
          'group_id': r['group_id'] == null ? null : _intValue(r['group_id']),
          'category': r['category']?.toString() ?? '',
          'notes': r['notes']?.toString() ?? '',
        });
      }
    });
  }
}
