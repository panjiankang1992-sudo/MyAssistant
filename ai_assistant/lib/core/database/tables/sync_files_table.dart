import 'package:drift/drift.dart';

class SyncFiles extends Table {
  @override
  String get tableName => 'sync';

  TextColumn get cloudPath => text()();
  TextColumn get module => text()();
  TextColumn get indexName => text()();
  TextColumn get lastModifiedDevice =>
      text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {cloudPath};
}
