import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:finance_app/features/categories/domain/category.dart';
import 'package:finance_app/features/categories/domain/category_provider.dart';
import 'package:finance_app/core/design_system/app_colors.dart';
import 'package:finance_app/core/design_system/app_spacing.dart';
import 'package:finance_app/core/design_system/app_radius.dart';
import 'package:finance_app/core/design_system/app_text_styles.dart';
import 'package:finance_app/core/design_system/app_card.dart';
import 'package:finance_app/core/design_system/app_button.dart';
import 'package:finance_app/core/design_system/app_empty_state.dart';

IconData getIconFromString(String iconName) {
  switch (iconName) {
    case 'restaurant': return Icons.restaurant;
    case 'bolt': return Icons.bolt;
    case 'attach_money': return Icons.attach_money;
    case 'shopping_cart': return Icons.shopping_cart;
    case 'local_gas_station': return Icons.local_gas_station;
    case 'health_and_safety': return Icons.health_and_safety;
    case 'home': return Icons.home;
    case 'directions_car': return Icons.directions_car;
    default: return Icons.category;
  }
}

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  void _showCategoryForm(BuildContext context, WidgetRef ref, {Category? category}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryFormSheet(category: category),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppColors.secondary, size: 28),
            onPressed: () => _showCategoryForm(context, ref),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return AppEmptyState(
              title: 'No hay categorías',
              subtitle: 'Crea una categoría para organizar tus transacciones.',
              icon: Icons.category_outlined,
              action: AppPrimaryButton(
                text: 'Crear Categoría',
                icon: Icons.add,
                onPressed: () => _showCategoryForm(context, ref),
                isFullWidth: false,
              ),
            );
          }

          final incomeCats = categories.where((c) => c.isIncome).toList();
          final expenseCats = categories.where((c) => !c.isIncome).toList();

          return CustomScrollView(
            slivers: [
              if (incomeCats.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                    child: Text('Ingresos', style: AppTextStyles.h3),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _CategoryTile(category: incomeCats[index], onEdit: () => _showCategoryForm(context, ref, category: incomeCats[index]), ref: ref),
                    childCount: incomeCats.length,
                  ),
                ),
              ],
              if (expenseCats.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                    child: Text('Gastos', style: AppTextStyles.h3),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _CategoryTile(category: expenseCats[index], onEdit: () => _showCategoryForm(context, ref, category: expenseCats[index]), ref: ref),
                    childCount: expenseCats.length,
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl * 2)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text('No se pudo cargar las categorías. Por favor, intenta de nuevo.', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final WidgetRef ref;

  const _CategoryTile({required this.category, required this.onEdit, required this.ref});

  @override
  Widget build(BuildContext context) {
    final color = category.isIncome ? AppColors.success : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(getIconFromString(category.icon), color: color, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(category.name, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text(category.isIncome ? 'Categoría de Ingreso' : 'Categoría de Gasto', style: AppTextStyles.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.secondary),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () {
                    ref.read(categoriesProvider.notifier).deleteCategory(category.id);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFormSheet extends ConsumerStatefulWidget {
  final Category? category;

  const _CategoryFormSheet({this.category});

  @override
  ConsumerState<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<_CategoryFormSheet> {
  final _nameController = TextEditingController();
  bool _isIncome = false;
  String _selectedIcon = 'category';

  final List<String> _availableIcons = [
    'category', 'restaurant', 'bolt', 'shopping_cart', 
    'local_gas_station', 'health_and_safety', 'home', 'directions_car', 'attach_money'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _isIncome = widget.category!.isIncome;
      _selectedIcon = widget.category!.icon;
      if (!_availableIcons.contains(_selectedIcon)) {
         _availableIcons.add(_selectedIcon);
      }
    }
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty) return;

    final cat = Category(
      id: widget.category?.id ?? const Uuid().v4(),
      name: _nameController.text,
      icon: _selectedIcon,
      color: _isIncome ? '0xFF4CAF50' : '0xFFF44336',
      isIncome: _isIncome,
    );

    if (widget.category == null) {
      await ref.read(categoriesProvider.notifier).createCategory(cat);
    } else {
      await ref.read(categoriesProvider.notifier).updateCategory(cat);
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Categoría guardada exitosamente'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.category == null ? 'Crear Categoría' : 'Editar Categoría', style: AppTextStyles.h2),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Gasto', style: TextStyle(fontWeight: FontWeight.bold))),
                      selected: !_isIncome,
                      onSelected: (val) => setState(() => _isIncome = false),
                      selectedColor: AppColors.danger.withValues(alpha: 0.2),
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Ingreso', style: TextStyle(fontWeight: FontWeight.bold))),
                      selected: _isIncome,
                      onSelected: (val) => setState(() => _isIncome = true),
                      selectedColor: AppColors.success.withValues(alpha: 0.2),
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _nameController,
                autofocus: widget.category == null,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la Categoría',
                  prefixIcon: Icon(Icons.label),
                ),
                style: AppTextStyles.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Selecciona un Ícono', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _availableIcons.map((iconName) {
                  final isSelected = _selectedIcon == iconName;
                  return InkWell(
                    onTap: () => setState(() => _selectedIcon = iconName),
                    borderRadius: AppRadius.borderSm,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: AppRadius.borderSm,
                        border: isSelected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : Border.all(color: Colors.transparent, width: 2),
                      ),
                      child: Icon(getIconFromString(iconName), color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: AppSecondaryButton(
                      text: 'Cancelar',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppPrimaryButton(
                      text: 'Guardar',
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
