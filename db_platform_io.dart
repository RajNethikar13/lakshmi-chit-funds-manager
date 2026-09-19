import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

Future<Database> openAppDatabase({
  required int version,
  required OnDatabaseCreateFn onCreate,
  required OnDatabaseVersionChangeFn onUpgrade,
}) async {
  final p = join(await getDatabasesPath(), 'lakshmi_chit_manager.db');
  return openDatabase(
    p,
    version: version,
    onCreate: onCreate,
    onUpgrade: onUpgrade,
  );
}
