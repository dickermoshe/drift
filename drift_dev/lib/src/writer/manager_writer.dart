// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:collection/collection.dart';
import 'package:drift_dev/src/analysis/results/results.dart';
import 'package:drift_dev/src/writer/modules.dart';
import 'package:drift_dev/src/writer/tables/update_companion_writer.dart';
import 'package:drift_dev/src/writer/writer.dart';
import 'package:recase/recase.dart';

abstract class _FilterWriter {
  /// The getter for the column on this table
  ///
  /// E.G `id` in `table.id`
  final String fieldGetter;

  /// The getter for the columns filter
  ///
  /// E.G `id` in `f.id.equals(5)`
  final String filterName;

  /// An abstract class for all filters
  _FilterWriter(this.filterName, {required this.fieldGetter});

  /// Write the filter to a provider [TextEmitter]
  void writeFilter(TextEmitter leaf);
}

class _RegularFilterWriter extends _FilterWriter {
  /// The type that this column is
  ///
  /// E.G `int`, `String`, etc
  final String type;

  /// A class used for writing `ColumnFilters` with regular types
  _RegularFilterWriter(super.filterName,
      {required super.fieldGetter, required this.type});

  @override
  void writeFilter(TextEmitter leaf) {
    leaf
      ..writeDriftRef("ColumnFilters")
      ..write("<$type> get $filterName =>")
      ..write("\$state.composableBuilder(")
      ..write("column: \$state.table.$fieldGetter,")
      ..write("builder: (column, joinBuilders) => ")
      ..writeDriftRef("ColumnFilters")
      ..write("(column, joinBuilders: joinBuilders));");
  }
}

class _FilterWithConverterWriter extends _FilterWriter {
  /// The type that this column is
  ///
  /// E.G `int`, `String`, etc
  final String type;

  /// The type of the user provided converter
  ///
  /// E.G `Color` etc
  final String converterType;

  /// A class used for writing `ColumnFilters` with custom converters
  _FilterWithConverterWriter(super.filterName,
      {required super.fieldGetter,
      required this.type,
      required this.converterType});

  @override
  void writeFilter(TextEmitter leaf) {
    final nonNullableConverterType = converterType.replaceFirst("?", "");
    leaf
      ..writeDriftRef("ColumnWithTypeConverterFilters")
      ..write(
          "<$converterType,$nonNullableConverterType,$type> get $filterName =>")
      ..write("\$state.composableBuilder(")
      ..write("column: \$state.table.$fieldGetter,")
      ..write("builder: (column, joinBuilders) => ")
      ..writeDriftRef("ColumnWithTypeConverterFilters")
      ..write("(column, joinBuilders: joinBuilders));");
  }
}

class _ReferencedFilterWriter extends _FilterWriter {
  /// The full function used to get the referenced table
  ///
  /// E.G `\$db.resultSet<$CategoryTable>('categories')`
  /// or `\$db.categories`
  final String referencedTableField;

  /// The getter for the column on the referenced table
  ///
  /// E.G `id` in `table.id`
  final String referencedColumnGetter;

  /// The name of the referenced table's filter composer
  ///
  /// E.G `CategoryFilterComposer`
  final String referencedFilterComposer;

  /// Whether this is a reverse reference or not.
  /// On a simple reference (Foreign Key) we are filtering on a single object,
  /// in which case the Filter API uses the following design:
  ///
  /// ```dart
  /// todos.filter((f) => f.category.name.equals("School")); // Todos in School category
  /// ```
  ///
  /// However, when filtering on the reverse reference, we are filtering on a list of objects,
  /// in which case the Filter API uses a callback which filters on that list:
  ///
  /// ```dart
  /// categories.filter((f) => f.todos((f) => f.name.equals("Supper"))); // Categories with a todo named Supper
  /// ```
  final bool isReverseReference;

  /// A class used for building filters for referenced tables
  _ReferencedFilterWriter(
    super.filterName, {
    required this.referencedTableField,
    required this.referencedColumnGetter,
    required this.referencedFilterComposer,
    required super.fieldGetter,
    this.isReverseReference = false,
  });

  @override
  void writeFilter(TextEmitter leaf) {
    // If it is a reverse reference, we include a callback to the filter
    // e.g `f.categories((f) => f.id(1))`
    // Otherwise we return the filter directly
    // e.g `f.category.id(1)`
    if (isReverseReference) {
      leaf
        ..writeDriftRef("ComposableFilter")
        ..write(" $filterName(")
        ..writeDriftRef("ComposableFilter")
        ..writeln(" Function( $referencedFilterComposer f) f) {");
    } else {
      leaf.write("$referencedFilterComposer get $filterName {");
    }

    // Write the filter composer for the referenced table
    // This handles the join and the filter for the referenced table
    leaf
      ..write(
          "final $referencedFilterComposer composer = \$state.composerBuilder(")
      ..write("composer: this,")
      ..write("getCurrentColumn: (t) => t.$fieldGetter,")
      ..write("referencedTable: $referencedTableField,")
      ..write("getReferencedColumn: (t) => t.$referencedColumnGetter,")
      ..write("builder: (joinBuilder, parentComposers) => ")
      ..write("$referencedFilterComposer(")
      ..writeDriftRef("ComposerState")
      ..write(
          "(\$state.db, $referencedTableField, joinBuilder, parentComposers)));");

    if (isReverseReference) {
      leaf
        ..writeln("return f(composer);")
        ..writeln("}");
    } else {
      leaf.write("return composer;}");
    }
  }
}

abstract class _OrderingWriter {
  /// The getter for the column on this table
  ///
  /// E.G `id` in `table.id`
  final String fieldGetter;

  /// The getter for the columns ordering
  ///
  /// E.G `id` in `f.id.equals(5)`
  final String orderingName;

  /// Abstract class for all orderings
  _OrderingWriter(this.orderingName, {required this.fieldGetter});

  /// Write the ordering to a provider [TextEmitter]
  void writeOrdering(TextEmitter leaf);
}

class _RegularOrderingWriter extends _OrderingWriter {
  /// The type that this column is
  ///
  /// E.G `int`, `String`, etc
  final String type;

  /// A class used for writing `ColumnOrderings` with regular types
  _RegularOrderingWriter(super.orderingName,
      {required super.fieldGetter, required this.type});

  @override
  void writeOrdering(TextEmitter leaf) {
    leaf
      ..writeDriftRef("ColumnOrderings")
      ..write("<$type>  get $orderingName =>")
      ..write("\$state.composableBuilder(")
      ..write("column: \$state.table.$fieldGetter,")
      ..write("builder: (column, joinBuilders) => ")
      ..writeDriftRef("ColumnOrderings")
      ..write("(column, joinBuilders: joinBuilders));");
  }
}

class _ReferencedOrderingWriter extends _OrderingWriter {
  /// The full function used to get the referenced table
  ///
  /// E.G `\$db.resultSet<$CategoryTable>('categories')`
  /// or `\$db.categories`
  final String referencedTableField;

  /// The getter for the column on the referenced table
  ///
  /// E.G `id` in `table.id`
  final String referencedColumnGetter;

  /// The name of the referenced table's ordering composer
  ///
  /// E.G `CategoryOrderingComposer`
  final String referencedOrderingComposer;

  /// A class used for building orderings for referenced tables
  _ReferencedOrderingWriter(super.orderingName,
      {required this.referencedTableField,
      required this.referencedColumnGetter,
      required this.referencedOrderingComposer,
      required super.fieldGetter});
  @override
  void writeOrdering(TextEmitter leaf) {
    leaf
      ..write("$referencedOrderingComposer get $orderingName {")
      ..write(
          "final $referencedOrderingComposer composer = \$state.composerBuilder(")
      ..write("composer: this,")
      ..write("getCurrentColumn: (t) => t.$fieldGetter,")
      ..write("referencedTable: $referencedTableField,")
      ..write("getReferencedColumn: (t) => t.$referencedColumnGetter,")
      ..write("builder: (joinBuilder, parentComposers) => ")
      ..write("$referencedOrderingComposer(")
      ..writeDriftRef("ComposerState")
      ..write(
          "(\$state.db, $referencedTableField, joinBuilder, parentComposers)));")
      ..write("return composer;}");
  }
}

class _ColumnReferenceReader {
  /// The generic that the column reader will use, e.g. T1, T2, etc
  final String generic;

  /// The getter for the column on the referencing table
  final String referenceColumnGetter;

  /// The name of the field that the record should use for the actual rows data
  final String fieldName;

  /// The name of function that will be added to the tables reference reader
  /// for actually getting the referenced object. E.g `_getCategory`
  String get getterMethodName => "_get${fieldName.pascalCase}";

  /// The method call that will be added to the tables reference reader
  /// for the user to add which references they want returned. E.g `withCategory()`
  String get withMethodName => "with${fieldName.pascalCase}";

  /// Whether this is a reverse reference or not
  final bool isReverseReference;

  /// Names of the referenced table
  final _TableManagerWriter referencedTableNames;

  /// The name of the column on the referenced table
  final String referencedColumnGetter;

  _ColumnReferenceReader(
      {required this.generic,
      required this.referenceColumnGetter,
      required this.referencedTableNames,
      required this.referencedColumnGetter,
      required this.fieldName,
      required this.isReverseReference});
}

class _ColumnManagerWriter {
  /// The getter for the field
  ///
  /// E.G `id` in `table.id`
  final String fieldGetter;

  /// List of filters for this column
  final List<_FilterWriter> filters;

  /// List of orderings for this column
  final List<_OrderingWriter> orderings;

  /// A class used for writing filters and orderings for columns
  _ColumnManagerWriter(this.fieldGetter)
      : filters = [],
        orderings = [];
}

class _TableManagerWriter {
  /// The current table
  final DriftTable table;

  /// Generation Scope
  final Scope scope;

  /// Generation Scope for the entire database
  final Scope dbScope;

  /// The name of the filter composer class
  ///
  /// E.G `UserFilterComposer`
  AnnotatedDartCode get filterComposer =>
      scope.generatedElement(table, '\$${table.entityInfoName}FilterComposer');

  /// The name of the ordering composer class
  ///
  /// E.G `UserOrderingComposer`
  AnnotatedDartCode get orderingComposer => scope.generatedElement(
      table, '\$${table.entityInfoName}OrderingComposer');

  /// The name of the processed table manager class
  ///
  /// E.G `UserProcessedTableManager`
  String get processedTableManager =>
      '\$${table.entityInfoName}ProcessedTableManager';

  /// The name of the reference reader class
  ///
  /// E.G `UserReferenceReader`
  String get referenceReaderName => '\$${table.entityInfoName}ReferenceReader';

  /// The name of the root table manager class
  ///
  /// E.G `UserTableManager`
  String get rootTableManager => ManagerWriter._rootManagerName(table);

  /// Name of the typedef for the insertCompanionBuilder
  ///
  /// E.G. `insertCompanionBuilder`
  String get insertCompanionBuilderTypeDefName =>
      '\$${table.entityInfoName}InsertCompanionBuilder';

  /// Name of the arguments for the updateCompanionBuilder
  ///
  /// E.G. `updateCompanionBuilderTypeDef`
  String get updateCompanionBuilderTypeDefName =>
      '\$${table.entityInfoName}UpdateCompanionBuilder';

  /// Table class name, this may be different from the entity name
  /// if modular generation is enabled
  /// E.G. `i5.$CategoriesTable`
  String get tableClassName => dbScope.dartCode(dbScope.entityInfoType(table));

  /// Row class name, this may be different from the entity name
  /// if modular generation is enabled
  /// E.G. `i5.$Category`
  String get rowClassName => dbScope.dartCode(dbScope.writer.rowType(table));

  /// Whether this table has a custom row class
  /// We use this row to determine if we should generate a manager for this table
  bool get hasCustomRowClass => table.existingRowClass != null;

  /// The name of the database class
  ///
  /// E.G. `i5.$GeneratedDatabase`
  final String databaseGenericName;

  /// Writers for the columns of this table
  final List<_ColumnManagerWriter> columns;

  /// Filters for back references
  final List<_ReferencedFilterWriter> backRefFilters;

  /// A list a classes that contain all the data needed to create a reference reader for this table
  final List<_ColumnReferenceReader> columnReferenceReaders;

  _TableManagerWriter(
      this.table, this.scope, this.dbScope, this.databaseGenericName)
      : backRefFilters = [],
        columns = [],
        columnReferenceReaders = [];

  void _writeReferenceReader(TextEmitter leaf) {
    if (columnReferenceReaders.isEmpty) {
      return;
    }
    // The name of the field that the record should use for the actual rows data
    final tableDataClassFieldName = rowClassName.split('.').last.camelCase;

    // The record type for the reference reader. e.g ({User user, T1? category})
    final dataClassWithRecordType =
        '({$rowClassName $tableDataClassFieldName,${columnReferenceReaders.map((e) => '${e.generic}? ${e.fieldName}').join(',')}})';

    // The generic for the reference reader. e.g <T1, T2>
    final referenceReaderGenerics = dataClassWithRecordType.isEmpty
        ? null
        : '<${columnReferenceReaders.map((e) => e.generic).join(',')}>';

    leaf
      ..write(
          'class $referenceReaderName${referenceReaderGenerics ?? ""} extends ')
      ..writeDriftRef('ReferenceReader')
      ..writeln('<$rowClassName,$dataClassWithRecordType> {')
      ..writeln('$referenceReaderName(this.\$manager);')
      ..writeln(
          '$databaseGenericName get _db => \$manager.\$state.db as $databaseGenericName;')
      ..write('final ')
      ..writeDriftRef('BaseTableManager')
      ..writeln(' \$manager;')
      ..writeln("@override")
      ..write(
          'Future<$dataClassWithRecordType> \$withReferences($rowClassName value) async {')
      ..writeln(
          'return ($tableDataClassFieldName:value, ${columnReferenceReaders.map((e) => '${e.fieldName}: await ${e.getterMethodName}(value)').join(',')});')
      ..writeln('}');

    for (var reader in columnReferenceReaders) {
      if (reader.isReverseReference) {
        leaf.writeln(
            "Future<${reader.generic}?> ${reader.getterMethodName}($rowClassName value) async {");
        leaf.writeln(
            "final result = await \$getReverseReferenced<${reader.generic},${reader.referencedTableNames.rowClassName}>(value.${reader.referenceColumnGetter}, _db.${reader.referencedTableNames.table.dbGetterName}.${reader.referencedColumnGetter});");
        leaf.writeln("return result as ${reader.generic}?;");
        leaf.writeln("}");
      } else {
        leaf.writeln(
            "Future<${reader.generic}?> ${reader.getterMethodName}($rowClassName value) async {");
        leaf.writeln(
            "return \$getSingleReferenced<${reader.referencedTableNames.rowClassName}>(value.${reader.referenceColumnGetter}, _db.${reader.referencedTableNames.table.dbGetterName}.${reader.referencedColumnGetter})  as ${reader.generic}?;");
        leaf.writeln("}");
      }

      final actualType = reader.isReverseReference
          ? 'List<${reader.referencedTableNames.rowClassName}>'
          : reader.referencedTableNames.rowClassName;

      leaf.writeln(
          "$referenceReaderName${referenceReaderGenerics!.replaceFirst(reader.generic, actualType)} ${reader.withMethodName}() {");
      leaf.writeln("return $referenceReaderName(this.\$manager);");
      leaf.writeln("}");
    }

    leaf.writeln('}');
  }

  void _writeFilterComposer(TextEmitter leaf) {
    leaf
      ..write('class $filterComposer extends ')
      ..writeDriftRef('FilterComposer')
      ..writeln('<$databaseGenericName,$tableClassName> {')
      ..writeln('$filterComposer(super.\$state);');
    for (var c in columns) {
      for (var f in c.filters) {
        f.writeFilter(leaf);
      }
    }
    for (var f in backRefFilters) {
      f.writeFilter(leaf);
    }
    leaf.writeln('}');
  }

  void _writeOrderingComposer(TextEmitter leaf) {
    // Write the OrderingComposer
    leaf
      ..write('class $orderingComposer extends ')
      ..writeDriftRef('OrderingComposer')
      ..writeln('<$databaseGenericName,$tableClassName> {')
      ..writeln('$orderingComposer(super.\$state);');
    for (var c in columns) {
      for (var o in c.orderings) {
        o.writeOrdering(leaf);
      }
    }
    leaf.writeln('}');
  }

  void _writeProcessedTableManager(TextEmitter leaf) {
    leaf
      ..write('class $processedTableManager extends ')
      ..writeDriftRef('ProcessedTableManager')
      ..writeln(
          '<$databaseGenericName,$tableClassName,$rowClassName,$filterComposer,$orderingComposer,$processedTableManager,$insertCompanionBuilderTypeDefName,$updateCompanionBuilderTypeDefName> {')
      ..writeln('const $processedTableManager(super.\$state);');
    if (columnReferenceReaders.isNotEmpty) {
      leaf.writeln('$referenceReaderName withReferences(){');
      leaf.writeln('return $referenceReaderName(this);');
      leaf.writeln('}');
    }

    leaf.writeln('}');
  }

  /// Build the builder for a companion class
  /// This is used to build the insert and update companions
  /// Returns a tuple with the typedef and the builder
  /// Use [isUpdate] to determine if the builder is for an update or insert companion
  (String, String) _companionBuilder(String typedefName,
      {required bool isUpdate}) {
    final companionClassName = scope.dartCode(scope.companionType(table));

    final companionBuilderTypeDef =
        StringBuffer('typedef $typedefName = $companionClassName Function({');

    final companionBuilderArguments = StringBuffer('({');

    final StringBuffer companionBuilderBody;
    if (isUpdate) {
      companionBuilderBody = StringBuffer('=> $companionClassName(');
    } else {
      companionBuilderBody = StringBuffer('=> $companionClassName.insert(');
    }

    for (final column in UpdateCompanionWriter(table, scope).columns) {
      final value = scope.drift('Value');
      final param = column.nameInDart;
      final typeName = scope.dartCode(scope.dartType(column));

      companionBuilderBody.write('$param: $param,');

      if (isUpdate) {
        // The update companion has no required fields, they are all defaulted to absent
        companionBuilderTypeDef.write('$value<$typeName> $param,');
        companionBuilderArguments
            .write('$value<$typeName> $param = const $value.absent(),');
      } else {
        // The insert compantion has some required arguments and some that are defaulted to absent
        if (!column.isImplicitRowId &&
            table.isColumnRequiredForInsert(column)) {
          companionBuilderTypeDef.write('required $typeName $param,');
          companionBuilderArguments.write('required $typeName $param,');
        } else {
          companionBuilderTypeDef.write('$value<$typeName> $param,');
          companionBuilderArguments
              .write('$value<$typeName> $param = const $value.absent(),');
        }
      }
    }
    companionBuilderTypeDef.write('});');
    companionBuilderArguments.write('})');
    companionBuilderBody.write(")");
    return (
      companionBuilderTypeDef.toString(),
      companionBuilderArguments.toString() + companionBuilderBody.toString()
    );
  }

  void _writeRootTable(TextEmitter leaf) {
    final (insertCompanionBuilderTypeDef, insertCompanionBuilder) =
        _companionBuilder(insertCompanionBuilderTypeDefName, isUpdate: false);
    final (updateCompanionBuilderTypeDef, updateCompanionBuilder) =
        _companionBuilder(updateCompanionBuilderTypeDefName, isUpdate: true);

    leaf.writeln(insertCompanionBuilderTypeDef);
    leaf.writeln(updateCompanionBuilderTypeDef);

    leaf
      ..write('class $rootTableManager extends ')
      ..writeDriftRef('RootTableManager')
      ..writeln(
          '<$databaseGenericName,$tableClassName,$rowClassName,$filterComposer,$orderingComposer,$processedTableManager,$insertCompanionBuilderTypeDefName,$updateCompanionBuilderTypeDefName>   {')
      ..writeln(
          '$rootTableManager($databaseGenericName db, $tableClassName table)')
      ..writeln(": super(")
      ..writeDriftRef("TableManagerState")
      ..write("""(db: db, table: table, filteringComposer:$filterComposer(""")
      ..writeDriftRef("ComposerState")
      ..write("""(db, table)),orderingComposer:$orderingComposer(""")
      ..writeDriftRef("ComposerState")
      ..write(
          """(db, table)),getChildManagerBuilder :(p0) => $processedTableManager(p0),getUpdateCompanionBuilder: $updateCompanionBuilder,
            getInsertCompanionBuilder:$insertCompanionBuilder));""");
    if (columnReferenceReaders.isNotEmpty) {
      leaf.writeln('$referenceReaderName withReferences(){');
      leaf.writeln('return $referenceReaderName(this);');
      leaf.writeln('}');
    }
    leaf.writeln('}');
  }

  /// Write the manager for this table, with all the filters and orderings
  void writeManager(TextEmitter leaf) {
    _writeFilterComposer(leaf);
    _writeOrderingComposer(leaf);
    _writeProcessedTableManager(leaf);
    _writeRootTable(leaf);
    _writeReferenceReader(leaf);
  }

  String _referenceTable(DriftTable table) {
    if (scope.generationOptions.isModular) {
      final extension = scope.refUri(
          ModularAccessorWriter.modularSupport, 'ReadDatabaseContainer');
      final type = scope.dartCode(scope.entityInfoType(table));
      return "$extension(\$state.db).resultSet<$type>('${table.schemaName}')";
    } else {
      return '\$state.db.${table.dbGetterName}';
    }
  }

  /// Add filters and orderings for the columns of this table
  void addFiltersAndOrderingsAndReaders(List<DriftTable> tables) {
    // Utility function to get the referenced table and column
    (DriftTable, DriftColumn)? getReferencedTableAndColumn(
        DriftColumn column, List<DriftTable> tables) {
      final referencedCol = column.constraints
          .whereType<ForeignKeyReference>()
          .firstOrNull
          ?.otherColumn;
      if (referencedCol != null && referencedCol.owner is DriftTable) {
        final referencedTable = referencedCol.owner as DriftTable;
        return (referencedTable, referencedCol);
      }
      return null;
    }

    // Utility function to get the duplicates in a list
    List<String> duplicates(List<String> items) {
      final seen = <String>{};
      final duplicates = <String>[];
      for (var item in items) {
        if (!seen.add(item)) {
          duplicates.add(item);
        }
      }
      return duplicates;
    }

    /// First add the filters and orderings for the columns
    /// of the current table
    for (var column in table.columns) {
      final c = _ColumnManagerWriter(column.nameInDart);

      // The type that this column is (int, string, etc)
      final innerColumnType =
          scope.dartCode(scope.innerColumnType(column.sqlType));

      // Get the referenced table and column if this column is a foreign key
      final referenced = getReferencedTableAndColumn(column, tables);
      final isForeignKey = referenced != null;

      // If the column has a type converter, add a filter with a converter
      if (column.typeConverter != null) {
        final converterType = scope.dartCode(scope.writer.dartType(column));
        c.filters.add(_FilterWithConverterWriter(c.fieldGetter,
            converterType: converterType,
            fieldGetter: c.fieldGetter,
            type: innerColumnType));
      } else if (!isForeignKey) {
        c.filters.add(_RegularFilterWriter(c.fieldGetter,
            type: innerColumnType, fieldGetter: c.fieldGetter));
      }

      // Add the ordering for the column

      if (!isForeignKey) {
        c.orderings.add(_RegularOrderingWriter(
            c.fieldGetter + (isForeignKey ? "Id" : ""),
            type: innerColumnType,
            fieldGetter: c.fieldGetter));
      }

      /// If this column is a foreign key to another table, add a filter and ordering
      /// for the referenced table
      if (referenced != null && !referenced.$1.hasExistingRowClass) {
        final (referencedTable, referencedCol) = referenced;
        final referencedTableNames = _TableManagerWriter(
            referencedTable, scope, dbScope, databaseGenericName);
        final referencedColumnNames =
            _ColumnManagerWriter(referencedCol.nameInDart);
        final referencedTableField = _referenceTable(referencedTable);

        c.filters.add(_ReferencedFilterWriter(c.fieldGetter,
            fieldGetter: c.fieldGetter,
            referencedColumnGetter: referencedColumnNames.fieldGetter,
            referencedFilterComposer:
                scope.dartCode(referencedTableNames.filterComposer),
            referencedTableField: referencedTableField));
        c.orderings.add(_ReferencedOrderingWriter(c.fieldGetter,
            fieldGetter: c.fieldGetter,
            referencedColumnGetter: referencedColumnNames.fieldGetter,
            referencedOrderingComposer:
                scope.dartCode(referencedTableNames.orderingComposer),
            referencedTableField: referencedTableField));
        columnReferenceReaders.add(_ColumnReferenceReader(
            generic: "T${columnReferenceReaders.length}",
            isReverseReference: false,
            referencedTableNames: referencedTableNames,
            referencedColumnGetter: referencedColumnNames.fieldGetter,
            fieldName: c.fieldGetter,
            referenceColumnGetter: c.fieldGetter));
      }
      columns.add(c);
    }

    // Iterate over all other tables to find back references
    for (var ot in tables) {
      for (var oc in ot.columns) {
        // Check if the column is a foreign key to the current table
        final reference = getReferencedTableAndColumn(oc, tables);
        if (reference != null &&
            reference.$1.entityInfoName == table.entityInfoName) {
          final referencedTableNames =
              _TableManagerWriter(ot, scope, dbScope, databaseGenericName);
          final referencedColumnNames = _ColumnManagerWriter(oc.nameInDart);
          final referencedTableField = _referenceTable(ot);

          final filterName = oc.referenceName ??
              "${referencedTableNames.table.dbGetterName}Refs";

          backRefFilters.add(_ReferencedFilterWriter(filterName,
              fieldGetter: reference.$2.nameInDart,
              referencedColumnGetter: referencedColumnNames.fieldGetter,
              referencedFilterComposer:
                  scope.dartCode(referencedTableNames.filterComposer),
              referencedTableField: referencedTableField,
              isReverseReference: true));

          columnReferenceReaders.add(_ColumnReferenceReader(
              generic: "T${columnReferenceReaders.length}",
              isReverseReference: true,
              referencedTableNames: referencedTableNames,
              referencedColumnGetter: referencedColumnNames.fieldGetter,
              fieldName: filterName,
              referenceColumnGetter: reference.$2.nameInDart));
        }
      }
    }

    // Remove the filters and orderings that have duplicates
    final duplicatedFilterNames = duplicates(columns
            .map((e) => e.filters.map((e) => e.filterName))
            .expand((e) => e)
            .toList() +
        backRefFilters.map((e) => e.filterName).toList());
    final duplicatedOrderingNames = duplicates(columns
        .map((e) => e.orderings.map((e) => e.orderingName))
        .expand((e) => e)
        .toList());
    final duplicateReferenceReaderNames = duplicates(
        columnReferenceReaders.map((e) => e.referenceColumnGetter).toList());
    if (duplicatedFilterNames.isNotEmpty ||
        duplicatedOrderingNames.isNotEmpty ||
        duplicateReferenceReaderNames.isNotEmpty) {
      print(
          "The code generator encountered an issue while attempting to create filters/orderings for $tableClassName manager. The following filters/orderings were not created ${(duplicatedFilterNames + duplicatedOrderingNames).toSet()}. Use the @ReferenceName() annotation to resolve this issue.");
      // Remove the duplicates
      for (var c in columns) {
        c.filters
            .removeWhere((e) => duplicatedFilterNames.contains(e.filterName));
        c.orderings.removeWhere(
            (e) => duplicatedOrderingNames.contains(e.orderingName));
      }
      backRefFilters
          .removeWhere((e) => duplicatedFilterNames.contains(e.filterName));
      columnReferenceReaders.removeWhere((e) =>
          duplicateReferenceReaderNames.contains(e.referenceColumnGetter));
    }
  }
}

class ManagerWriter {
  final Scope _scope;
  final Scope _dbScope;
  final String _dbClassName;
  late final List<DriftTable> _addedTables;

  /// Class used to write a manager for a database
  ManagerWriter(this._scope, this._dbScope, this._dbClassName) {
    _addedTables = [];
  }

  /// Add a table to the manager
  void addTable(DriftTable table) {
    _addedTables.add(table);
  }

  /// The generic of the database that the manager will use
  /// Will be `GeneratedDatabase` if modular generation is enabled
  /// or the name of the database class if not
  String get databaseGenericName {
    if (_scope.generationOptions.isModular) {
      return _scope.drift("GeneratedDatabase");
    } else {
      return _dbClassName;
    }
  }

  /// The name of the manager class
  String get databaseManagerName => '${_dbClassName}Manager';

  /// The getter for the manager that will be added to the database
  String get managerGetter {
    return '$databaseManagerName get managers => $databaseManagerName(this);';
  }

  static String _rootManagerName(DriftTable table) {
    return '\$${table.entityInfoName}TableManager';
  }

  AnnotatedDartCode _referenceRootManager(DriftTable table) {
    return _scope.generatedElement(table, _rootManagerName(table));
  }

  void writeTableManagers() {
    final leaf = _scope.leaf();

    // create the manager class for each table
    final tableWriters = <_TableManagerWriter>[];
    for (var table in _addedTables) {
      tableWriters.add(
          _TableManagerWriter(table, _scope, _dbScope, databaseGenericName)
            ..addFiltersAndOrderingsAndReaders(_addedTables));
    }

    // Remove ones that have custom row classes
    tableWriters.removeWhere((t) => t.hasCustomRowClass);

    // Write each tables manager to the leaf and append the getter to the main manager
    for (var table in tableWriters) {
      table.writeManager(leaf);
    }
  }

  /// Writes the main manager class referencing the generated classes for each
  /// table using a getter.
  void writeMainClass() {
    final leaf = _scope.leaf();
    leaf
      ..writeln('class $databaseManagerName{')
      ..writeln('final $_dbClassName _db;')
      ..writeln('$databaseManagerName(this._db);');

    for (final table in _addedTables) {
      if (!table.hasExistingRowClass) {
        final type = leaf.dartCode(_referenceRootManager(table));

        leaf.writeln(
            '$type get ${table.dbGetterName} => $type(_db, _db.${table.dbGetterName});');
      }
    }

    leaf.writeln('}');
  }
}
