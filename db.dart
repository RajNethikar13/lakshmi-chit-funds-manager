import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDb {
  AppDb._();
  static final instance = AppDb._();
  Database? _db;
  Database get db => _db!;

  Future<void> init() async {
    final p = join(await getDatabasesPath(), 'lakshmi_chit_manager.db');
    _db = await openDatabase(p, version: 2, onCreate: (db, v) async {
      await db.execute('CREATE TABLE templates(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,months INTEGER NOT NULL,members INTEGER NOT NULL,installment INTEGER NOT NULL,due_day INTEGER NOT NULL)');
      await db.execute('CREATE TABLE groups_tbl(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,template_id INTEGER NOT NULL,start_date TEXT NOT NULL)');
      await db.execute('CREATE TABLE members(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,mobile TEXT NOT NULL,address TEXT,group_id INTEGER NOT NULL,member_no INTEGER NOT NULL,lift_month INTEGER,lift_amount INTEGER,lift_date TEXT)');
      await db.execute('CREATE TABLE payments(id INTEGER PRIMARY KEY AUTOINCREMENT,member_id INTEGER NOT NULL,month_no INTEGER NOT NULL,due_amount INTEGER NOT NULL,paid_amount INTEGER NOT NULL DEFAULT 0,paid_date TEXT,status TEXT NOT NULL,mode TEXT NOT NULL,notes TEXT)');
      await db.execute('CREATE TABLE ledger(id INTEGER PRIMARY KEY AUTOINCREMENT,type TEXT NOT NULL,amount INTEGER NOT NULL,date TEXT NOT NULL,member_id INTEGER,group_id INTEGER,category TEXT NOT NULL,notes TEXT)');
      await db.insert('templates', {'name':'25 Months - ₹16,000','months':25,'members':25,'installment':16000,'due_day':5});
    });
  }

  Future<List<Map<String,Object?>>> templates() => db.query('templates', orderBy:'id DESC');
  Future<int> addTemplate(String n,int m,int mem,int inst,int due) => db.insert('templates',{'name':n,'months':m,'members':mem,'installment':inst,'due_day':due});
  Future<void> updateTemplate(int id,String n,int m,int mem,int inst,int due) => db.update('templates',{'name':n,'months':m,'members':mem,'installment':inst,'due_day':due},where:'id=?',whereArgs:[id]);
  Future<void> deleteTemplate(int id) async {
    final used=await db.query('groups_tbl',where:'template_id=?',whereArgs:[id]);
    if(used.isNotEmpty) throw Exception('This scheme is used by a group. Delete that group first.');
    await db.delete('templates',where:'id=?',whereArgs:[id]);
  }

  Future<List<Map<String,Object?>>> groups() => db.rawQuery('SELECT g.*,t.name template_name,t.months,t.members,t.installment,t.due_day FROM groups_tbl g JOIN templates t ON g.template_id=t.id ORDER BY g.id DESC');
  Future<int> addGroup(String n,int t,DateTime d) => db.insert('groups_tbl',{'name':n,'template_id':t,'start_date':d.toIso8601String()});
  Future<void> updateGroup(int id,String n,int t,DateTime d) => db.update('groups_tbl',{'name':n,'template_id':t,'start_date':d.toIso8601String()},where:'id=?',whereArgs:[id]);
  Future<void> deleteGroup(int id) async {
    await db.transaction((tx) async {
      final ms=await tx.query('members',where:'group_id=?',whereArgs:[id]);
      for(final m in ms) {
        await tx.delete('payments',where:'member_id=?',whereArgs:[m['id']]);
        await tx.delete('ledger',where:'member_id=?',whereArgs:[m['id']]);
      }
      await tx.delete('members',where:'group_id=?',whereArgs:[id]);
      await tx.delete('groups_tbl',where:'id=?',whereArgs:[id]);
    });
  }

  Future<List<Map<String,Object?>>> members() => db.rawQuery('SELECT m.*,g.name group_name,t.name template_name,t.months,t.installment,t.due_day FROM members m JOIN groups_tbl g ON m.group_id=g.id JOIN templates t ON g.template_id=t.id ORDER BY m.name');
  Future<int> addMember(String n,String phone,String address,int gid,int no) => db.insert('members',{'name':n,'mobile':phone,'address':address,'group_id':gid,'member_no':no});
  Future<void> updateMember(int id,String n,String phone,String address,int gid,int no) => db.update('members',{'name':n,'mobile':phone,'address':address,'group_id':gid,'member_no':no},where:'id=?',whereArgs:[id]);
  Future<void> deleteMember(int id) async {
    await db.delete('payments',where:'member_id=?',whereArgs:[id]);
    await db.delete('ledger',where:'member_id=?',whereArgs:[id]);
    await db.delete('members',where:'id=?',whereArgs:[id]);
  }
  Future<Map<String,Object?>?> member(int id) async {
    final r=await db.rawQuery('SELECT m.*,g.name group_name,t.name template_name,t.months,t.members,t.installment,t.due_day FROM members m JOIN groups_tbl g ON m.group_id=g.id JOIN templates t ON g.template_id=t.id WHERE m.id=?',[id]);
    return r.isEmpty?null:r.first;
  }
  Future<List<Map<String,Object?>>> payments(int id) => db.query('payments',where:'member_id=?',whereArgs:[id],orderBy:'month_no');

  Future<void> savePayment({required int memberId,required int month,required int due,required int paid,required String status,required String mode,DateTime? date}) async {
    final old=await db.query('payments',where:'member_id=? AND month_no=?',whereArgs:[memberId,month]);
    final vals={'member_id':memberId,'month_no':month,'due_amount':due,'paid_amount':paid,'paid_date':date?.toIso8601String(),'status':status,'mode':mode,'notes':''};
    await db.transaction((tx) async {
      if(old.isEmpty) {
        await tx.insert('payments',vals);
      } else {
        await tx.update('payments',vals,where:'id=?',whereArgs:[old.first['id']]);
      }
      await tx.delete('ledger',where:'member_id=? AND category=? AND notes=?',whereArgs:[memberId,'Installment','Month $month']);
      if(paid>0) {
        await tx.insert('ledger',{'type':'IN','amount':paid,'date':(date??DateTime.now()).toIso8601String(),'member_id':memberId,'category':'Installment','notes':'Month $month'});
      }
    });
  }

  Future<void> saveLift(int id,int month,int amount,DateTime date) async {
    await db.update('members',{'lift_month':month,'lift_amount':amount,'lift_date':date.toIso8601String()},where:'id=?',whereArgs:[id]);
    await db.delete('ledger',where:'member_id=? AND category=?',whereArgs:[id,'Chit Payout']);
    await db.insert('ledger',{'type':'OUT','amount':amount,'date':date.toIso8601String(),'member_id':id,'category':'Chit Payout','notes':'Lift month $month'});
  }

  Future<Map<String,int>> dashboard() async {
    final g=Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM groups_tbl'))??0;
    final m=Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM members'))??0;
    final r=Sqflite.firstIntValue(await db.rawQuery("SELECT COALESCE(SUM(amount),0) FROM ledger WHERE type='IN'"))??0;
    final o=Sqflite.firstIntValue(await db.rawQuery("SELECT COALESCE(SUM(amount),0) FROM ledger WHERE type='OUT'"))??0;
    final p=Sqflite.firstIntValue(await db.rawQuery("SELECT COALESCE(SUM(due_amount-paid_amount),0) FROM payments WHERE due_amount>paid_amount"))??0;
    return {'groups':g,'members':m,'received':r,'given':o,'outstanding':p};
  }
}
