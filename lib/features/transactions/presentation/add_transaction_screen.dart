import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:finance_app/features/categories/domain/category_provider.dart';
import 'package:finance_app/features/transactions/domain/transaction.dart';
import 'package:finance_app/features/transactions/domain/transaction_provider.dart';
import 'package:finance_app/features/receipts/domain/image_service.dart';
import 'package:finance_app/features/ocr_processor/domain/ocr_service.dart';
import 'package:finance_app/features/categorization/domain/categorization_engine.dart';
import 'package:finance_app/features/budgets/domain/budget_provider.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:intl/intl.dart';

import 'package:finance_app/core/design_system/app_colors.dart';
import 'package:finance_app/core/design_system/app_spacing.dart';
import 'package:finance_app/core/design_system/app_radius.dart';
import 'package:finance_app/core/design_system/app_text_styles.dart';
import 'package:finance_app/core/design_system/app_card.dart';
import 'package:finance_app/core/design_system/app_button.dart';
import 'package:finance_app/core/design_system/app_section_header.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final bool autoOpenOcr;
  const AddTransactionScreen({super.key, this.autoOpenOcr = false});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String? _selectedCategoryId;
  final DateTime _selectedDate = DateTime.now();
  String? _imagePath;
  String? _ocrText;
  bool _isIncome = false;
  bool _isOcrProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenOcr) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scanReceipt(true);
      });
    }
  }

  void _scanReceipt(bool fromCamera) async {
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _isOcrProcessing = true);
    
    try {
      final imagePath = await ImageService.pickAndSaveImage(fromCamera: fromCamera);
      if (imagePath != null) {
        setState(() => _imagePath = imagePath);
        
        // Procesar OCR
        final result = await OcrService.processImage(imagePath);
        _ocrText = result.tabulatedText; // Usamos el texto espacial nuevo
        
        // Asignar cálculos automáticos con altísima precisión
        if (result.probableAmount != null && _amountController.text.isEmpty) {
          final formatter = NumberFormat.currency(symbol: '', decimalDigits: 2);
          _amountController.text = formatter.format(result.probableAmount).trim();
        }
        
        final inferredDesc = CategorizationEngine.suggestDescription(result.rawText);
        if (inferredDesc != null && _descriptionController.text.isEmpty) {
          _descriptionController.text = inferredDesc;
        } else if (result.probableDescription != null && _descriptionController.text.isEmpty) {
          _descriptionController.text = result.probableDescription!;
        }
        
        // Sugerir categoría
        final history = ref.read(transactionsProvider).value ?? [];
        final suggestedCatId = CategorizationEngine.suggestCategory(result.rawText, _descriptionController.text, history: history);
        if (suggestedCatId != null && _selectedCategoryId == null) {
          setState(() {
            _selectedCategoryId = suggestedCatId;
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: AppSpacing.sm), Text('Recibo escaneado con éxito')]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 120, left: AppSpacing.md, right: AppSpacing.md),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al escanear: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isOcrProcessing = false);
      }
    }
  }

  void _saveTransaction() {
    ScaffoldMessenger.of(context).clearSnackBars();
    if (_amountController.text.isEmpty || _selectedCategoryId == null) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [Icon(Icons.warning, color: Colors.white), SizedBox(width: AppSpacing.sm), Text('Por favor, selecciona monto y categoría')]),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 120, left: AppSpacing.md, right: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
       ));
       return;
    }

    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

    if (!_isIncome) {
      final txs = ref.read(transactionsProvider).value ?? [];
      double balance = 0;
      for (var t in txs) {
        if (t.isIncome) balance += t.amount;
        else balance -= t.amount;
      }
      if (amount > balance) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [Icon(Icons.error, color: Colors.white), SizedBox(width: AppSpacing.sm), Expanded(child: Text('Saldo insuficiente. No puedes gastar más de lo disponible.'))]),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 120, left: AppSpacing.md, right: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
        ));
        return;
      }

      final budgets = ref.read(budgetsProvider).value ?? [];
      try {
        final budget = budgets.firstWhere((b) => b.categoryId == _selectedCategoryId);
        final now = DateTime.now();
        final spent = txs.where((t) => t.date.year == now.year && t.date.month == now.month && t.categoryId == _selectedCategoryId && !t.isIncome).fold(0.0, (s, t) => s + t.amount);
        
        if (spent + amount > budget.amountLimit) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.white), SizedBox(width: AppSpacing.sm), Expanded(child: Text('¡Alerta! Has excedido el presupuesto para esta categoría.'))]),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 120, left: AppSpacing.md, right: AppSpacing.md),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
          ));
        }
      } catch (_) {}
    }

    final tx = AppTransaction(
      id: const Uuid().v4(),
      amount: amount,
      categoryId: _selectedCategoryId!,
      date: _selectedDate,
      description: _descriptionController.text.isEmpty ? 'Sin descripción' : _descriptionController.text,
      receiptImagePath: _imagePath,
      ocrRawText: _ocrText,
      isIncome: _isIncome,
    );

    ref.read(transactionsProvider.notifier).addTransaction(tx);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: AppSpacing.sm), Text('Guardado Exitoso')]),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 120, left: AppSpacing.md, right: AppSpacing.md),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
      duration: const Duration(seconds: 1),
    ));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Registro', style: AppTextStyles.h2)),
      body: _isOcrProcessing 
        ? const Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.md),
              Text('Analizando recibo con IA...', style: AppTextStyles.bodyMedium)
            ],
          ))
        : ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tipo de Transacción', style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Gasto', style: TextStyle(fontWeight: FontWeight.bold))),
                        selected: !_isIncome,
                        onSelected: (val) {
                          setState(() {
                            _isIncome = false;
                            _selectedCategoryId = null; 
                          });
                        },
                        selectedColor: AppColors.danger.withValues(alpha: 0.2),
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Ingreso', style: TextStyle(fontWeight: FontWeight.bold))),
                        selected: _isIncome,
                        onSelected: (val) {
                          setState(() {
                            _isIncome = true;
                            _selectedCategoryId = null; 
                          });
                        },
                        selectedColor: AppColors.success.withValues(alpha: 0.2),
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                TextField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    CurrencyTextInputFormatter.currency(
                      symbol: '',
                      decimalDigits: 2,
                    )
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Monto (\$)',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  style: AppTextStyles.h1.copyWith(color: _isIncome ? AppColors.success : AppColors.danger),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción / Título',
                    prefixIcon: Icon(Icons.description),
                  ),
                  onChanged: (val) {
                     final history = ref.read(transactionsProvider).value ?? [];
                     final sug = CategorizationEngine.suggestCategory(_ocrText, val, history: history);
                     if (sug != null && _selectedCategoryId != sug) {
                       setState(() => _selectedCategoryId = sug);
                     }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                categoriesAsync.when(
                  data: (cats) {
                    final filteredCats = cats.where((c) => c.isIncome == _isIncome).toList();
                    
                    if (_selectedCategoryId == null && filteredCats.isNotEmpty) {
                       WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _selectedCategoryId == null) {
                             setState(() => _selectedCategoryId = filteredCats.first.id);
                          }
                       });
                    }

                    String? safeValue = _selectedCategoryId;
                    if (safeValue != null && !filteredCats.any((c) => c.id == safeValue)) {
                      safeValue = null;
                    }

                    return DropdownButtonFormField<String>(
                      initialValue: safeValue,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: filteredCats.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedCategoryId = val),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, s) => Text('Error al cargar categorías: $e'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const AppSectionHeader(title: 'Comprobante de Pago'),
          Column(
            children: [
              AppPrimaryButton(
                text: 'Escanear con cámara',
                icon: Icons.camera_alt,
                onPressed: () => _scanReceipt(true),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppSecondaryButton(
                text: 'Subir desde galería',
                icon: Icons.image,
                onPressed: () => _scanReceipt(false),
              ),
            ],
          ),
          if (_imagePath != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_ocrText != null && _ocrText!.isNotEmpty) ...[
                    Text('Análisis Inteligente (OCR)', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: AppRadius.borderSm),
                      child: Text('Extraído del recibo:\n\n$_ocrText', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Text('Recibo Físico', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: AppRadius.borderMd,
                      image: DecorationImage(
                        image: FileImage(File(_imagePath!)),
                        fit: BoxFit.cover,
                      )
                    ),
                  ),
                ],
              )
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          AppPrimaryButton(
            text: 'Guardar',
            icon: Icons.save,
            onPressed: _saveTransaction,
            backgroundColor: _isIncome ? AppColors.success : AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
