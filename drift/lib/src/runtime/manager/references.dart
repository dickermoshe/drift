part of 'manager.dart';

/// A function for asynchronously wrapping a [DT] (Dataclass) with references.
typedef ReferenceWrapper<DT, DtWithReferences> = Future<List<DtWithReferences>>
    Function(List<DT>);

/// A [Selectable] that can be used to query a table and map the results to a different type.
///
/// This is used by the manager to wrap the results with getters to reference.
class SelectableWithMapper<MappedType, OriginalType>
    extends Selectable<MappedType> {
  /// The query that will be used to get the data.
  Selectable<OriginalType> $query;

  /// The function that will be used to map the data.
  ReferenceWrapper<OriginalType, MappedType> $withJoinedData;

  /// Create a new [SelectableWithMapper] instance.
  SelectableWithMapper(this.$query, this.$withJoinedData);

  @override
  Future<List<MappedType>> get() {
    return $query.get().then($withJoinedData);
  }

  @override
  Stream<List<MappedType>> watch() {
    return $query.watch().asyncMap($withJoinedData);
  }
}
