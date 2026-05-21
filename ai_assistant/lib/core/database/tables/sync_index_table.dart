import 'package:drift/drift.dart';

class SyncIndex extends Table {
  TextColumn get dataId => text()();
  TextColumn get dataType => text()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get cloudVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {dataId, dataType};
}
