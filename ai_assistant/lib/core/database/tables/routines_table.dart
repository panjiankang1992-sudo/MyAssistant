import 'package:drift/drift.dart';

class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get type => text()();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  TextColumn get action => text().withDefault(const Constant('none'))();
  TextColumn get time => text()();
  TextColumn get repeatRule => text().withDefault(const Constant('daily'))();
  TextColumn get repeatDays => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
}
