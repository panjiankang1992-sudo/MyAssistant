import 'package:drift/drift.dart';

class Bills extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get categoryId => text()();
  TextColumn get categoryName => text()();
  TextColumn get categoryEmoji => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  RealColumn get cnyAmount => real()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get aiGenerated => boolean().withDefault(const Constant(false))();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class BillCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get emoji => text()();
  IntColumn get color => integer()();
  TextColumn get kind => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
