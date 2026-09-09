/// Category repository.
library;

import 'package:drift/drift.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/errors/failures.dart';
import 'package:follow_my_life/core/errors/result.dart';
import 'package:uuid/uuid.dart';

class CategoryRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  CategoryRepository(this._db);

  Future<Result<List<Category>>> getActiveCategories() async {
    try {
      final cats = await (_db.select(_db.categories)
            ..where((t) => t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();
      return Success(cats);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to load categories', e.toString()));
    }
  }

  Stream<List<Category>> watchActiveCategories() {
    return (_db.select(_db.categories)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<Result<Category>> createCategory({
    required String name,
    String icon = 'tag',
    int colorIndex = 0,
  }) async {
    try {
      final id = 'cat_${_uuid.v4().substring(0, 8)}';
      await _db.into(_db.categories).insert(CategoriesCompanion.insert(
            id: id,
            name: name,
            icon: Value(icon),
            colorIndex: Value(colorIndex),
          ));
      final cat = await (_db.select(_db.categories)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      return Success(cat);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to create category', e.toString()));
    }
  }

  Future<Result<void>> archiveCategory(String id) async {
    try {
      await (_db.update(_db.categories)..where((t) => t.id.equals(id)))
          .write(const CategoriesCompanion(isActive: Value(false)));
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to archive category', e.toString()));
    }
  }

  Future<Result<void>> updateCategory({
    required String id,
    required String name,
    String icon = 'tag',
    int colorIndex = 0,
  }) async {
    try {
      await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(
          name: Value(name),
          icon: Value(icon),
          colorIndex: Value(colorIndex),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to update category', e.toString()));
    }
  }
}
