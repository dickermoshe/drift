import 'package:sally/sally.dart';

/// Base class for generated classes.
abstract class TableInfo<TableDsl, DataClass> {
  TableDsl get asDslTable;

  /// The primary key of this table. Can be null if no custom primary key has
  /// been specified
  Set<Column> get $primaryKey => null;

  /// The table name in the sql table
  String get $tableName;
  List<Column> get $columns;

  DataClass map(Map<String, dynamic> data);
}