import 'package:drift/drift.dart';

class Todos extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get source => text()();
  TextColumn get routineId => text().nullable()();
  TextColumn get type => text()();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  TextColumn get action => text().withDefault(const Constant('none'))();
  TextColumn get time => text()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(true))();
  IntColumn get reminderMinutesBefore =>
      integer().withDefault(const Constant(10))();

  @override
  Set<Column> get primaryKey => {id};
}
