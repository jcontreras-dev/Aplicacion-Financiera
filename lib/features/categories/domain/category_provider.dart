import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_app/features/categories/domain/category.dart';
import 'package:finance_app/features/categories/data/category_repository.dart';

final categoryRepositoryProvider = Provider((ref) => CategoryRepository());

final categoriesProvider = AsyncNotifierProvider<CategoriesNotifier, List<Category>>(() {
  return CategoriesNotifier();
});

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async {
    final repository = ref.watch(categoryRepositoryProvider);
    return repository.getCategories();
  }

  Future<void> createCategory(Category category) async {
    final repository = ref.read(categoryRepositoryProvider);
    await repository.insertCategory(category);
    ref.invalidateSelf();
  }

  Future<void> updateCategory(Category category) async {
    final repository = ref.read(categoryRepositoryProvider);
    await repository.updateCategory(category);
    ref.invalidateSelf();
  }

  Future<void> deleteCategory(String id) async {
    final repository = ref.read(categoryRepositoryProvider);
    await repository.deleteCategory(id);
    ref.invalidateSelf();
  }
}
