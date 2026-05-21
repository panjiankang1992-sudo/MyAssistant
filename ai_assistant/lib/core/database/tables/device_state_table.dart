import 'package:drift/drift.dart';

class DeviceSyncState extends Table {
  TextColumn get deviceId => text()();
  DateTimeColumn get lastSyncTime => dateTime().nullable()();
  DateTimeColumn get lastPullTime => dateTime().nullable()();
  DateTimeColumn get lastPushTime => dateTime().nullable()();
  IntColumn get syncErrors => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {deviceId};
}
