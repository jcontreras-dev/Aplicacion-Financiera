import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:finance_app/core/design_system/app_colors.dart';
import 'package:finance_app/core/design_system/app_spacing.dart';
import 'package:finance_app/core/design_system/app_text_styles.dart';
import 'package:finance_app/core/design_system/app_card.dart';
import 'package:finance_app/core/design_system/app_button.dart';
import 'package:finance_app/core/design_system/app_empty_state.dart';

// ─── Model ────────────────────────────────────────────────────────────────────
class SavingsGoal {
  final String id;
  final String name;
  final double targetAmount;
  double currentAmount;
  final String emoji;
  final DateTime? deadline;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.emoji,
    this.deadline,
  });

  double get progress => currentAmount / targetAmount;
  bool get isCompleted => currentAmount >= targetAmount;
  double get remaining => (targetAmount - currentAmount).clamp(0, double.infinity);
}

// ─── Provider ─────────────────────────────────────────────────────────────────
class SavingsGoalsNotifier extends Notifier<List<SavingsGoal>> {
  static const _key = 'savings_goals_json';

  @override
  List<SavingsGoal> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_key) ?? [];
    final goals = rawList.map((raw) {
      final parts = raw.split('||');
      return SavingsGoal(
        id: parts[0],
        name: parts[1],
        targetAmount: double.parse(parts[2]),
        currentAmount: double.parse(parts[3]),
        emoji: parts[4],
        deadline: parts.length > 5 && parts[5].isNotEmpty ? DateTime.tryParse(parts[5]) : null,
      );
    }).toList();
    state = goals;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = state.map((g) =>
      '${g.id}||${g.name}||${g.targetAmount}||${g.currentAmount}||${g.emoji}||${g.deadline?.toIso8601String() ?? ""}'
    ).toList();
    await prefs.setStringList(_key, rawList);
  }

  Future<void> addGoal(SavingsGoal goal) async {
    state = [...state, goal];
    await _save();
  }

  Future<void> deposit(String id, double amount) async {
    state = state.map((g) {
      if (g.id == id) {
        g.currentAmount = (g.currentAmount + amount).clamp(0, g.targetAmount);
      }
      return g;
    }).toList();
    await _save();
  }

  Future<void> deleteGoal(String id) async {
    state = state.where((g) => g.id != id).toList();
    await _save();
  }
}

final savingsGoalsProvider = NotifierProvider<SavingsGoalsNotifier, List<SavingsGoal>>(() {
  return SavingsGoalsNotifier();
});

// ─── Screen ───────────────────────────────────────────────────────────────────
class SavingsGoalsScreen extends ConsumerWidget {
  const SavingsGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(savingsGoalsProvider);
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metas de Ahorro', style: AppTextStyles.h2),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.secondary),
            onPressed: () => _showAddGoalDialog(context, ref),
          ),
        ],
      ),
      body: goals.isEmpty
          ? const AppEmptyState(
              title: 'Sin metas todavía',
              subtitle: 'Crea tu primera meta: un viaje, un fondo de emergencia, lo que quieras.',
              icon: Icons.savings_outlined,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: goals.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final goal = goals[index];
                return _GoalCard(goal: goal, formatter: formatter, ref: ref);
              },
            ),
    );
  }

  void _showAddGoalDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String selectedEmoji = '🎯';
    final emojis = ['🎯', '✈️', '🏠', '🚗', '🎓', '💊', '🛍️', '🏖️', '💻', '🎸', '👶', '🐾'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: AppSpacing.lg),
                const Text('Nueva Meta de Ahorro', style: AppTextStyles.h2),
                const SizedBox(height: AppSpacing.md),

                // Emoji selector
                const Text('Elige un ícono:', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  children: emojis.map((e) => GestureDetector(
                    onTap: () => setModalState(() => selectedEmoji = e),
                    child: Container(
                      width: 42, height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selectedEmoji == e ? AppColors.secondary.withValues(alpha: 0.1) : AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selectedEmoji == e ? AppColors.secondary : AppColors.borderLight),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre de la meta', hintText: 'Ej: Viaje a la playa')),
                const SizedBox(height: AppSpacing.md),
                TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Meta de ahorro (\$)', hintText: 'Ej: 500000')),
                const SizedBox(height: AppSpacing.lg),
                AppPrimaryButton(
                  text: 'Crear Meta',
                  isFullWidth: true,
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '')) ?? 0;
                    if (name.isEmpty || amount <= 0) return;
                    ref.read(savingsGoalsProvider.notifier).addGoal(SavingsGoal(
                      id: const Uuid().v4(),
                      name: name,
                      targetAmount: amount,
                      currentAmount: 0,
                      emoji: selectedEmoji,
                    ));
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final NumberFormat formatter;
  final WidgetRef ref;

  const _GoalCard({required this.goal, required this.formatter, required this.ref});

  @override
  Widget build(BuildContext context) {
    final progress = goal.progress.clamp(0.0, 1.0);
    final color = goal.isCompleted ? AppColors.success : AppColors.secondary;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(goal.emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                    Text(
                      goal.isCompleted ? '¡Meta alcanzada! 🎉' : 'Faltan ${formatter.format(goal.remaining)}',
                      style: AppTextStyles.label.copyWith(color: goal.isCompleted ? AppColors.success : AppColors.textSecondaryLight),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                onPressed: () => ref.read(savingsGoalsProvider.notifier).deleteGoal(goal.id),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatter.format(goal.currentAmount), style: AppTextStyles.label.copyWith(color: color, fontWeight: FontWeight.bold)),
              Text('${(progress * 100).toStringAsFixed(0)}%', style: AppTextStyles.label.copyWith(color: AppColors.textSecondaryLight)),
              Text(formatter.format(goal.targetAmount), style: AppTextStyles.label.copyWith(color: AppColors.textSecondaryLight)),
            ],
          ),
          if (!goal.isCompleted) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar dinero'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  side: const BorderSide(color: AppColors.secondary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showDepositDialog(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDepositDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Agregar a "${goal.name}"', style: AppTextStyles.h3),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Monto a agregar (\$)'),
        ),
        actions: [
          AppSecondaryButton(text: 'Cancelar', isFullWidth: false, onPressed: () => Navigator.pop(ctx)),
          AppPrimaryButton(
            text: 'Agregar',
            isFullWidth: false,
            onPressed: () {
              final amount = double.tryParse(ctrl.text.replaceAll(',', '')) ?? 0;
              if (amount > 0) {
                ref.read(savingsGoalsProvider.notifier).deposit(goal.id, amount);
                Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    );
  }
}
