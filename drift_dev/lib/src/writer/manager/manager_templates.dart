part of "database_manager_writer.dart";

/// A class which contains utility functions to generate manager class names
///
/// This is used by the [DatabaseManagerWriter] to generate code for the manager classes
class _ManagerCodeTemplates {
  _ManagerCodeTemplates(this._scope);

  /// A Scope class which contains the current scope of the generation
  ///
  /// Used to generating names which require import prefixes
  final Scope _scope;

  /// Returns the name of the manager class for a table
  ///
  /// This classes acts as container for all the table managers
  ///
  /// E.g. `AppDatabaseManager`
  String databaseManagerName(String dbClassName) {
    // This class must be public, remove all _ prefixes
    return '${dbClassName}Manager'.replaceAll(RegExp(r'^_+'), "");
  }

  /// How the database will represented in the generated code
  ///
  /// When doing modular generation the table doesnt have direct access to the database class
  /// so it will use `GeneratedDatabase` as the generic type in such cases
  ///
  /// E.g. `i0.GeneratedDatabase` or `AppDatabase`
  String databaseType(TextEmitter leaf, String dbClassName) {
    return switch (_scope.generationOptions.isModular) {
      true => leaf.drift("GeneratedDatabase"),
      false => dbClassName,
    };
  }

  /// Returns the name of the root manager class for a table
  ///
  /// One of these classes is generated for each table in the database
  ///
  /// E.g. `\$UserTableManager`
  String rootTableManagerName(DriftTable table) {
    return '\$${table.entityInfoName}TableManager';
  }

  /// Returns the name of the manager class for a table
  ///
  /// When using modular generation the manager class will contain the correct prefix
  /// to access the table manager
  ///
  /// E.g. `i0.UserTableTableManager` or `\$UserTableTableManager`
  String rootTableManagerWithPrefix(DriftTable table, TextEmitter leaf) {
    return leaf
        .dartCode(leaf.generatedElement(table, rootTableManagerName(table)));
  }

  /// Returns the name of the processed table manager class for a table
  ///
  /// This does not contain any prefixes, as this will always be generated in the same file
  /// as the table manager and is not used outside of the file
  ///
  /// E.g. `$UserTableProcessedTableManager`
  String processedTableManagerTypeDefName(DriftTable table) {
    return '\$${table.entityInfoName}ProcessedTableManager';
  }

  /// Returns code for the processed table manager class
  String processedTableManagerTypeDef({
    required DriftTable table,
    required String dbClassName,
    required TextEmitter leaf,
    required List<_Relation> relations,
  }) {
    return """typedef ${processedTableManagerTypeDefName(table)} = ${leaf.drift("ProcessedTableManager")}${_tableManagerTypeArguments(table, dbClassName, leaf, relations)};""";
  }

  /// Class which represents a table in the database
  /// Contains the prefix if the generation is modular
  /// E.g. `i0.UserTable`
  String tableClassWithPrefix(DriftTable table, TextEmitter leaf) =>
      leaf.dartCode(leaf.entityInfoType(table));

  /// Class which represents a row in the table
  /// Contains the prefix if the generation is modular
  /// E.g. `i0.User`
  String rowClassWithPrefix(DriftTable table, TextEmitter leaf) =>
      leaf.dartCode(leaf.writer.rowType(table));

  /// Name of the class which is used to represent a row along with it's references
  String rowWithReferencesClassName(DriftTable table) {
    return '\$${table.entityInfoName}WithReferences';
  }

  /// Name of this tables filter composer class
  String filterComposerNameWithPrefix(DriftTable table, TextEmitter leaf) {
    return leaf
        .dartCode(leaf.generatedElement(table, filterComposerName(table)));
  }

  /// Name of this tables filter composer class
  String filterComposerName(
    DriftTable table,
  ) {
    return '\$${table.entityInfoName}FilterComposer';
  }

  /// Name of this tables ordering composer class
  String orderingComposerNameWithPrefix(DriftTable table, TextEmitter leaf) {
    return leaf
        .dartCode(leaf.generatedElement(table, orderingComposerName(table)));
  }

  /// Name of this tables ordering composer class
  String orderingComposerName(DriftTable table) {
    return '\$${table.entityInfoName}OrderingComposer';
  }

  /// Name of the typedef for the create companion builder for a table
  ///
  /// This is the name of the typedef of a function that creates new rows in the table
  String createCompanionBuilderTypeDef(DriftTable table) {
    return '\$${table.entityInfoName}CreateCompanionBuilder';
  }

  /// Name of the typedef for the update companion builder for a table
  ///
  /// This is the name of the typedef of a function that updates rows in the table
  String updateCompanionBuilderTypeDefName(DriftTable table) {
    return '\$${table.entityInfoName}UpdateCompanionBuilder';
  }

  // The name of the type defenition to use for the callback that creates the prefetches class
  String createPrefetchedDataGetterCallbackTypeDefName(DriftTable table) {
    return '\$${table.entityInfoName}CreatePrefetchedDataCallback';
  }

  /// Name for a class which holds prefetches data
  String prefetchedDataClassName(DriftTable table) {
    return '\$${table.entityInfoName}PrefetchedData';
  }

  /// Build the builder for a companion class
  /// This is used to build the create and update companions
  /// Returns a tuple with the typedef and the builder
  /// Use [isUpdate] to determine if the builder is for an update or create companion
  ({String typeDefinition, String companionBuilder}) companionBuilder(
      DriftTable table, TextEmitter leaf,
      {required bool isUpdate}) {
    // Get the name of the typedef
    final typedefName = isUpdate
        ? updateCompanionBuilderTypeDefName(table)
        : createCompanionBuilderTypeDef(table);

    // Get the companion class name
    final companionClassName = leaf.dartCode(leaf.companionType(table));

    // Build the typedef and the builder in 3 parts
    // 1. The typedef definition
    // 2. The arguments for the builder
    // 3. The body of the builder
    final companionBuilderTypeDef =
        StringBuffer('typedef $typedefName = $companionClassName Function({');
    final companionBuilderArguments = StringBuffer('({');
    final StringBuffer companionBuilderBody;
    if (isUpdate) {
      companionBuilderBody = StringBuffer('=> $companionClassName(');
    } else {
      companionBuilderBody = StringBuffer('=> $companionClassName.insert(');
    }
    for (final column in UpdateCompanionWriter(table, _scope).columns) {
      final value = leaf.drift('Value');
      final param = column.nameInDart;
      final typeName = leaf.dartCode(leaf.dartType(column));

      companionBuilderBody.write('$param: $param,');

      // When writing an update companion builder, all fields are optional
      // they are all therefor defaulted to absent
      if (isUpdate) {
        companionBuilderTypeDef.write('$value<$typeName> $param,');
        companionBuilderArguments
            .write('$value<$typeName> $param = const $value.absent(),');
      } else {
        // Otherwise, for create companions, required fields are required
        // and optional fields are defaulted to absent
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
      typeDefinition: companionBuilderTypeDef.toString(),
      companionBuilder:
          companionBuilderArguments.toString() + companionBuilderBody.toString()
    );
  }

  /// Generic type arguments for the root and processed table manager
  String _tableManagerTypeArguments(
    DriftTable table,
    String dbClassName,
    TextEmitter leaf,
    List<_Relation> relations,
  ) {
    final String rowClassWithReferencesTypeArg;
    if (!_scope.generationOptions.isModular && relations.isNotEmpty) {
      rowClassWithReferencesTypeArg = rowWithReferencesClassName(table);
    } else {
      rowClassWithReferencesTypeArg =
          "${leaf.drift('BaseWithReferences')}<${databaseType(leaf, dbClassName)},${rowClassWithPrefix(table, leaf)},${prefetchedDataClassName(table)}>";
    }
    return """
    <${databaseType(leaf, dbClassName)},
    ${tableClassWithPrefix(table, leaf)},
    ${rowClassWithPrefix(table, leaf)},
    ${filterComposerNameWithPrefix(table, leaf)},
    ${orderingComposerNameWithPrefix(table, leaf)},
    ${createCompanionBuilderTypeDef(table)},
    ${updateCompanionBuilderTypeDefName(table)},
    (${rowClassWithPrefix(table, leaf)},$rowClassWithReferencesTypeArg),
    ${rowClassWithPrefix(table, leaf)},${createPrefetchedDataGetterCallbackTypeDefName(table)},
    ${prefetchedDataClassName(table)}>""";
  }

  /// Code for getting a table from inside a composer
  /// handles modular generation correctly
  String _referenceTableFromComposer(DriftTable table, TextEmitter leaf) {
    return leaf.dartCode(leaf.referenceElement(table, '\$state.db'));
  }

  /// Returns code for the root table manager class
  String rootTableManager({
    required DriftTable table,
    required String dbClassName,
    required TextEmitter leaf,
    required String updateCompanionBuilder,
    required String createCompanionBuilder,
    required List<_Relation> relations,
  }) {
    final String rowClassWithReferencesConstructor;
    if (!_scope.generationOptions.isModular && relations.isNotEmpty) {
      rowClassWithReferencesConstructor = rowWithReferencesClassName(table);
    } else {
      rowClassWithReferencesConstructor = leaf.drift('BaseWithReferences');
    }
    final reverseRelations = relations.where((element) => element.isReverse);

    return """class ${rootTableManagerName(table)} extends ${leaf.drift("RootTableManager")}${_tableManagerTypeArguments(table, dbClassName, leaf, relations)} {
    ${rootTableManagerName(table)}(${databaseType(leaf, dbClassName)} db, ${tableClassWithPrefix(table, leaf)} table) : super(
      ${leaf.drift("TableManagerState")}(
        db: db,
        table: table,
        filteringComposer: ${filterComposerNameWithPrefix(table, leaf)}(${leaf.drift("ComposerState")}(db, table)),
        orderingComposer: ${orderingComposerNameWithPrefix(table, leaf)}(${leaf.drift("ComposerState")}(db, table)),
        withReferenceMapper: (p0,p1) => p0.map((e) => (e,$rowClassWithReferencesConstructor(db,e,p1))).toList() ,
                createPrefetchedDataGetterCallback: (${reverseRelations.isEmpty ? "" : "{${reverseRelations.map(
              (e) => "${e.fieldName} = false",
            ).join(",")}}"}) {
            return (db, data) async {
              final managers = data.map((e) => $rowClassWithReferencesConstructor(db, e));

              ${relations.where((i) => i.isReverse).map((relation) {
      return """
                final prefetched${relation.fieldName} = ${relation.fieldName} ? await managers.map((e) => e.${relation.fieldName}).reduceToSingleTableManager()?.get():null;
                """;
    }).join('\n')}

              return ${prefetchedDataClassName(table)}(
                ${relations.where((i) => i.isReverse).map((relation) => "${relation.fieldName}: prefetched${relation.fieldName},").join('\n')}
              );
            };
          },
        updateCompanionCallback: $updateCompanionBuilder,
        createCompanionCallback: $createCompanionBuilder,));
        }
    """;
  }

  /// Returns the code for a tables filter composer
  String filterComposer({
    required DriftTable table,
    required TextEmitter leaf,
    required String dbClassName,
    required List<String> columnFilters,
  }) {
    return """class ${filterComposerName(table)} extends ${leaf.drift("FilterComposer")}<
        ${databaseType(leaf, dbClassName)},
        ${tableClassWithPrefix(table, leaf)}> {
        ${filterComposerName(table)}(super.\$state);
          ${columnFilters.join('\n')}
        }
      """;
  }

  /// Returns the code for a tables ordering composer
  String orderingComposer(
      {required DriftTable table,
      required TextEmitter leaf,
      required String dbClassName,
      required List<String> columnOrderings}) {
    return """class ${orderingComposerName(table)} extends ${leaf.drift("OrderingComposer")}<
        ${databaseType(leaf, dbClassName)},
        ${tableClassWithPrefix(table, leaf)}> {
        ${orderingComposerName(table)}(super.\$state);
          ${columnOrderings.join('\n')}
        }
      """;
  }

  /// Code for a filter for a standard column (no relations or type convertions)
  String standardColumnFilters(
      {required TextEmitter leaf,
      required DriftColumn column,
      required String type}) {
    final filterName = column.nameInDart;
    final columnGetter = column.nameInDart;

    return """${leaf.drift("ColumnFilters")}<$type> get $filterName => \$state.composableBuilder(
      column: \$state.table.$columnGetter,
      builder: (column, joinBuilders) => 
      ${leaf.drift("ColumnFilters")}(column, joinBuilders: joinBuilders));
      """;
  }

  /// Code for a filter for a column that has a type converter
  String columnWithTypeConverterFilters(
      {required TextEmitter leaf,
      required DriftColumn column,
      required String type}) {
    final filterName = column.nameInDart;
    final columnGetter = column.nameInDart;
    final converterType = leaf.dartCode(leaf.writer.dartType(column));
    final nonNullableConverterType = converterType.replaceFirst("?", "");
    return """
          ${leaf.drift("ColumnWithTypeConverterFilters")}<$converterType,$nonNullableConverterType,$type> get $filterName => \$state.composableBuilder(
      column: \$state.table.$columnGetter,
      builder: (column, joinBuilders) => 
      ${leaf.drift("ColumnWithTypeConverterFilters")}(column, joinBuilders: joinBuilders));
      """;
  }

  /// Code for a filter which works over a reference
  String relatedFilter(
      {required _Relation relation, required TextEmitter leaf}) {
    if (relation.isReverse) {
      return """
        ${leaf.drift("ComposableFilter")} ${relation.fieldName}(
          ${leaf.drift("ComposableFilter")}  Function( ${filterComposerNameWithPrefix(relation.referencedTable, leaf)} f) f
        ) {
          ${_referencedComposer(leaf: leaf, relation: relation, composerName: filterComposerNameWithPrefix(relation.referencedTable, leaf))}
          return f(composer);
        }
""";
    } else {
      return """
        ${filterComposerNameWithPrefix(relation.referencedTable, leaf)} get ${relation.fieldName} {
          ${_referencedComposer(leaf: leaf, relation: relation, composerName: filterComposerNameWithPrefix(relation.referencedTable, leaf))}
          return composer;
        }""";
    }
  }

  /// Code for a orderings for a standard column (no relations)
  String standardColumnOrderings(
      {required TextEmitter leaf,
      required DriftColumn column,
      required String type}) {
    final filterName = column.nameInDart;
    final columnGetter = column.nameInDart;

    return """${leaf.drift("ColumnOrderings")}<$type> get $filterName => \$state.composableBuilder(
      column: \$state.table.$columnGetter,
      builder: (column, joinBuilders) => 
      ${leaf.drift("ColumnOrderings")}(column, joinBuilders: joinBuilders));
      """;
  }

  /// Code for a ordering which works over a reference
  String relatedOrderings(
      {required _Relation relation, required TextEmitter leaf}) {
    assert(relation.isReverse == false,
        "Don't generate orderings for reverse relations");
    return """
        ${orderingComposerNameWithPrefix(relation.referencedTable, leaf)} get ${relation.fieldName} {
          ${_referencedComposer(leaf: leaf, relation: relation, composerName: orderingComposerNameWithPrefix(relation.referencedTable, leaf))}
          return composer;
        }""";
  }

  /// Code for creating a referenced composer, used by forward and reverse filters
  String _referencedComposer(
      {required _Relation relation,
      required TextEmitter leaf,
      required String composerName}) {
    return """
      final $composerName composer = \$state.composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.${relation.currentColumn.nameInDart},
      referencedTable: ${_referenceTableFromComposer(relation.referencedTable, leaf)},
      getReferencedColumn: (t) => t.${relation.referencedColumn.nameInDart},
      builder: (joinBuilder, parentComposers) => 
      $composerName(
        ${leaf.drift("ComposerState")}(
          \$state.db, ${_referenceTableFromComposer(relation.referencedTable, leaf)}, joinBuilder, parentComposers
        ))
              );""";
  }

  /// Code for a row class which contains references to other tables
  String? rowClassWithReferences(
      {required DriftTable currentTable,
      required List<_Relation> relations,
      required TextEmitter leaf,
      required String dbClassName}) {
    return """

        class ${rowWithReferencesClassName(currentTable)}  extends ${leaf.drift("BaseWithReferences")}<${databaseType(leaf, dbClassName)},${rowClassWithPrefix(currentTable, leaf)}, ${prefetchedDataClassName(currentTable)}> {
        ${rowWithReferencesClassName(currentTable)}(super.\$_db, super.\$_item,[super.\$_prefetchedData]);
        
        ${relations.map((relation) {
      if (_scope.generationOptions.isModular) {
        /// There is no support for references in modular generation
        return "";
      }
      if (relation.isReverse) {
        // For a reverse relation, we return a filtered table manager
        return """
        ${processedTableManagerTypeDefName(relation.referencedTable)} get ${relation.fieldName} {
        final manager = ${rootTableManagerWithPrefix(relation.referencedTable, leaf)}(
            \$_db, \$_db.${relation.referencedTable.dbGetterName}
            ).filter(
              (f) => f.${relation.referencedColumn.nameInDart}.${relation.currentColumn.nameInDart}(
              \$_item.${relation.currentColumn.nameInDart}
            )
          );
          final state = manager.\$state.copyWith(
          cache:\$_prefetchedData
            ?.${relation.fieldName}
            ?.where((e) => e.${relation.referencedColumn.nameInDart} == \$_item.${relation.currentColumn.nameInDart})
            .toList());
          return ${leaf.drift("ProcessedTableManager")}(state);
        }
        """;
      } else {
        return """
        ${processedTableManagerTypeDefName(relation.referencedTable)}? get ${relation.fieldName} {
          if (\$_item.${relation.currentColumn.nameInDart} == null) return null;
          return ${rootTableManagerWithPrefix(relation.referencedTable, leaf)}(\$_db, \$_db.${relation.referencedTable.dbGetterName}).filter((f) => f.${relation.referencedColumn.nameInDart}(\$_item.${relation.currentColumn.nameInDart}!));
        }
        """;
      }
    }).join('\n')}
        }""";
  }

  /// Type defenition for  the callback that creates the prefetches class
  String createPrefetcherCallbackTypeDef(
      {required DriftTable currentTable,
      required List<_Relation> relations,
      required TextEmitter leaf,
      required String dbClassName}) {
    final reverseReferences =
        relations.where((element) => element.isReverse).toList();
    return 'typedef ${createPrefetchedDataGetterCallbackTypeDefName(currentTable)} = Future<${prefetchedDataClassName(currentTable)}> Function(${databaseType(leaf, dbClassName)},List<${rowClassWithPrefix(currentTable, leaf)}>) Function(${reverseReferences.isEmpty ? "" : "{${reverseReferences.map(
          (e) => "bool ${e.fieldName}",
        ).join(",")}}"});';
  }

  // Code for a managers prefetcher
  String? prefetchedDataClass({
    required DriftTable currentTable,
    required List<_Relation> relations,
    required TextEmitter leaf,
  }) {
    Iterable<({String fieldName, String type})> fields =
        relations.where((relation) => relation.isReverse).map((relation) {
      return (
        fieldName: relation.fieldName,
        type: "List<${rowClassWithPrefix(relation.referencedTable, leaf)}>?"
      );
    });

    return """

        class ${prefetchedDataClassName(currentTable)} {
          ${prefetchedDataClassName(currentTable)}(
            ${fields.isEmpty ? "" : "{${fields.map((e) => "this.${e.fieldName},").join("\n")}}"}
          );
        
          ${fields.map((e) => "final ${e.type} ${e.fieldName};").join("\n")}
        
        }""";
  }
}
