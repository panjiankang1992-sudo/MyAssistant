import 'package:drift/drift.dart';

class MetadataOptions extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get value => text()();
  TextColumn get label => text()();
  TextColumn get iconKey => text()();
  TextColumn get colorKey => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isPreset => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
