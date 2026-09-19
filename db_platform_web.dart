import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<Database> openAppDatabase({
  required int version,
  required OnDatabaseCreateFn onCreate,
  required OnDatabaseVersionChangeFn onUpgrade,
}) async {
  return databaseFactoryFfiWeb.openDatabase(
    'lakshmi_chit_manager.db',
    options: OpenDatabaseOptions(
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    ),
  );
}
