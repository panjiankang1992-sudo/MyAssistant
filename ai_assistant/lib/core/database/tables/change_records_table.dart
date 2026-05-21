import 'package:drift/drift.dart';

class ChangeRecords extends Table {
  IntColumn get recordId => integer().autoIncrement()();
  TextColumn get dataId => text()();
  TextColumn get dataType => text()();
  TextColumn get operation => text()();
  TextColumn get changeContent => text()();
  IntColumn get version => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get pushed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {recordId};
}
