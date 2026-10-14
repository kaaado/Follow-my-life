import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:follow_my_life/core/constants/app_constants.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dbDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbDir.path, AppConstants.databaseName));
    return NativeDatabase(
      file,
      setup: (rawDb) {
        rawDb.execute('PRAGMA journal_mode = WAL;');
        rawDb.execute('PRAGMA foreign_keys = ON;');
        rawDb.execute('PRAGMA synchronous = NORMAL;');
      },
    );
  });
}
