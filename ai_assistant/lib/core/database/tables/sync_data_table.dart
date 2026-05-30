import 'package:drift/drift.dart';

class SyncData extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncIndexId => text()();
  TextColumn get dataId => text()();
  TextColumn get localTable => text()();
  TextColumn get cloudPath => text().nullable()();
  TextColumn get operationType => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get error => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
