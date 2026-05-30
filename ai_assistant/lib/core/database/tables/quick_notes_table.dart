import 'package:drift/drift.dart';

class QuickNotes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get summary => text().withDefault(const Constant(''))();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get analyzed => boolean().withDefault(const Constant(false))();
  BoolColumn get isAnalysis => boolean().withDefault(const Constant(false))();
  TextColumn get noteType => text().withDefault(const Constant('document'))();
  TextColumn get category => text().withDefault(const Constant('未分类'))();
  TextColumn get subcategory => text().withDefault(const Constant('未归类'))();
  TextColumn get sourceNoteIds => text().withDefault(const Constant('[]'))();
  TextColumn get attachmentIds => text().withDefault(const Constant('[]'))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
