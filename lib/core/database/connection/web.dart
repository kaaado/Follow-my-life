import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:follow_my_life/core/constants/app_constants.dart';

QueryExecutor openConnection() {
  return DatabaseConnection.delayed(Future.sync(() async {
    final result = await WasmDatabase.open(
      databaseName: AppConstants.databaseName,
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  }));
}
