import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/work_type_model.dart';
import '../../data/repositories/work_type_repository.dart';

// Work types list provider with filters
final workTypesProvider = FutureProvider.autoDispose
    .family<List<WorkTypeModel>, WorkTypeFilters>((ref, filters) async {
  final repository = ref.watch(workTypeRepositoryProvider);
  return repository.getWorkTypes(
    categoryId: filters.categoryId,
    isActive: filters.isActive,
  );
});

// Work types for specific category provider
final workTypesForCategoryProvider =
    FutureProvider.autoDispose.family<List<WorkTypeModel>, int>((ref, categoryId) async {
  final repository = ref.watch(workTypeRepositoryProvider);
  return repository.getWorkTypesForCategory(categoryId);
});

// Single work type provider
final workTypeProvider =
    FutureProvider.autoDispose.family<WorkTypeModel?, int>((ref, id) async {
  final repository = ref.watch(workTypeRepositoryProvider);
  return repository.getWorkType(id);
});

// Filters class for work types
class WorkTypeFilters {
  final int? categoryId;
  final bool? isActive;

  const WorkTypeFilters({
    this.categoryId,
    this.isActive,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is WorkTypeFilters &&
        other.categoryId == categoryId &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(categoryId, isActive);
}
