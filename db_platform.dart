// Platform-specific database opener.
// On Android/iOS/desktop we use the normal sqflite database.
// On web, the conditional import selects db_platform_web.dart.
export 'db_platform_io.dart'
    if (dart.library.html) 'db_platform_web.dart';
