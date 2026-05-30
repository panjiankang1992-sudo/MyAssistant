import 'package:drift/drift.dart';

class AppSettingsRecords extends Table {
  @override
  String get tableName => 'app_settings';

  TextColumn get id => text()();
  TextColumn get module => text()();
  TextColumn get dataType => text()();
  TextColumn get payloadJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id, dataType};
}
