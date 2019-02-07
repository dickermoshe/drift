import 'package:sally/sally.dart';
import 'package:sally/src/runtime/migration.dart';

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 6, max: 32)();
  BoolColumn get isAwesome => boolean()();
}

// Example tables and data classes, these would be generated by sally_generator
// in a real project
class UserDataObject {
  final int id;
  final String name;
  UserDataObject(this.id, this.name);
}

class GeneratedUsersTable extends Users with TableInfo<Users, UserDataObject> {
  final GeneratedDatabase db;

  GeneratedUsersTable(this.db);

  @override
  Set<Column> get $primaryKey => Set()..add(id);
  @override
  IntColumn id = GeneratedIntColumn('id', false);
  @override
  TextColumn name = GeneratedTextColumn('name', false);
  @override
  BoolColumn isAwesome = GeneratedBoolColumn('is_awesome', true);
  @override
  List<Column<dynamic, SqlType>> get $columns => [id, name, isAwesome];
  @override
  String get $tableName => 'users';
  @override
  Users get asDslTable => this;
  @override
  UserDataObject map(Map<String, dynamic> data) {
    return null;
  }
}

class TestDatabase extends GeneratedDatabase {
  TestDatabase(QueryExecutor executor)
      : super(const SqlTypeSystem.withDefaults(), executor);

  GeneratedUsersTable get users => GeneratedUsersTable(this);

  @override
  MigrationStrategy get migration => MigrationStrategy();

  @override
  int get schemaVersion => 1;
}
