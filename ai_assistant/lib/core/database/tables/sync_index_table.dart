import 'package:drift/drift.dart';

class SyncIndex extends Table {
  TextColumn get dataId => text()();
  TextColumn get dataType => text()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get cloudVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  TextColumn get syncIndexPath => text().nullable()();
  TextColumn get cloudPath => text().nullable()();
  TextColumn get lastModifiedDevice =>
      text().withDefault(const Constant('local'))();
  DateTimeColumn get cloudUpdatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {dataId, dataType};
}
