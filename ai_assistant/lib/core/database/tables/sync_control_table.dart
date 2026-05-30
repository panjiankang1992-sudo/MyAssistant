import 'package:drift/drift.dart';

class SyncControl extends Table {
  TextColumn get id => text()();
  BoolColumn get muted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
