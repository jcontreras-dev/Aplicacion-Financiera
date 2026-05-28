import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:finance_app/core/design_system/app_colors.dart';
import 'package:finance_app/core/design_system/app_spacing.dart';
import 'package:finance_app/core/design_system/app_radius.dart';
import 'package:finance_app/core/design_system/app_text_styles.dart';
import 'package:finance_app/core/design_system/app_card.dart';
import 'package:finance_app/core/design_system/app_button.dart';
import 'package:finance_app/core/database/database_helper.dart';
import 'package:finance_app/core/providers/theme_provider.dart';
import 'package:finance_app/core/services/biometric_service.dart';
import 'package:finance_app/core/services/notification_service.dart';
import 'package:finance_app/features/export_import/domain/export_service.dart';
import 'package:finance_app/features/transactions/domain/transaction_provider.dart';
import 'package:finance_app/features/transactions/domain/transaction.dart';
import 'package:finance_app/features/categories/domain/category_provider.dart';
import 'package:finance_app/features/budgets/domain/budget_provider.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  Future<void> _showExportFilterDialog(BuildContext context, WidgetRef ref, bool isPdf) async {
    DateTime? selectedStartDate;
    DateTime? selectedEndDate;
    String selectedFilter = 'Todos';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceLight,
              title: Text('Exportar ${isPdf ? "PDF" : "CSV"}', style: AppTextStyles.h3),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedFilter,
                    decoration: const InputDecoration(labelText: 'Filtrar Periodo'),
                    items: ['Todos', 'Este Mes', 'Mes Pasado', 'Personalizado'].map((String val) {
                      return DropdownMenuItem(value: val, child: Text(val));
                    }).toList(),
                    onChanged: (val) async {
                      if (val == 'Personalizado') {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedFilter = val!;
                            selectedStartDate = picked.start;
                            selectedEndDate = picked.end;
                          });
                        }
                      } else {
                        setState(() {
                          selectedFilter = val!;
                        });
                      }
                    },
                  ),
                  if (selectedFilter == 'Personalizado' && selectedStartDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Text('Desde: ${DateFormat('yyyy-MM-dd').format(selectedStartDate!)}\nHasta: ${DateFormat('yyyy-MM-dd').format(selectedEndDate!)}', 
                        textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.secondary)),
                    ),
                ],
              ),
              actions: [
                AppSecondaryButton(
                  text: 'Cancelar',
                  isFullWidth: false,
                  onPressed: () => Navigator.pop(context),
                ),
                AppPrimaryButton(
                  text: 'Generar',
                  isFullWidth: false,
                  onPressed: () {
                    Navigator.pop(context);
                    _executeExport(context, ref, isPdf, selectedFilter, selectedStartDate, selectedEndDate);
                  },
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _executeExport(BuildContext context, WidgetRef ref, bool isPdf, String filter, DateTime? start, DateTime? end) async {
    final transactions = ref.read(transactionsProvider).value ?? [];
    final categories = ref.read(categoriesProvider).value ?? [];
    
    List<AppTransaction> filtered = transactions;
    final now = DateTime.now();
    String reportLabel = "Todo el Historial Histórico";

    if (filter == 'Este Mes') {
      filtered = transactions.where((t) => t.date.year == now.year && t.date.month == now.month).toList();
      reportLabel = "Mes: ${DateFormat('MM/yyyy').format(now)}";
    } else if (filter == 'Mes Pasado') {
      final prev = DateTime(now.year, now.month - 1);
      filtered = transactions.where((t) => t.date.year == prev.year && t.date.month == prev.month).toList();
      reportLabel = "Mes: ${DateFormat('MM/yyyy').format(prev)}";
    } else if (filter == 'Personalizado' && start != null && end != null) {
      final exactEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);
      filtered = transactions.where((t) => t.date.isAfter(start.subtract(const Duration(seconds: 1))) && t.date.isBefore(exactEnd)).toList();
      reportLabel = "Del ${DateFormat('dd/MM/yyyy').format(start)} al ${DateFormat('dd/MM/yyyy').format(end)}";
    }

    double tIncome = 0;
    double tExpense = 0;
    for (var t in filtered) {
      if (t.isIncome) tIncome += t.amount; else tExpense += t.amount;
    }
    final balance = tIncome - tExpense;

    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generando documento ${isPdf ? "PDF" : "CSV"}...')));
      String path;
      if (isPdf) {
        path = await ExportService.exportToPDF(filtered, categories, reportLabel, tIncome, tExpense, balance);
      } else {
        path = await ExportService.exportToCSV(filtered, categories, reportLabel, tIncome, tExpense, balance);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('Guardado exitosamente')]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'ABRIR',
            textColor: Colors.white,
            onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Mi Reporte Financiero: $reportLabel')),
          ),
        ));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de Seguridad', style: AppTextStyles.h2),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── CONFIGURACIÓN DE LA APP ────────────────────────────────
            Text('Configuración de la App', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.sm),
            const _AppSettingsCard(),
            const SizedBox(height: AppSpacing.xl),

            // ─── PROBAR NOTIFICACIONES ─────────────────────────────────
            Text('Notificaciones', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.sm),
            _ActionCard(
              title: 'Probar Notificación',
              subtitle: 'Envía una notificación de prueba ahora mismo a tu celular.',
              icon: Icons.notifications_active_outlined,
              color: AppColors.accent,
              isFullWidth: true,
              onTap: () async {
                await NotificationService.showInstantNotification(
                  '⚠️ Recordatorio de Gasto Fijo',
                  'Mañana vence tu pago de Arriendo - \$500,000',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Notificación enviada. Revisa la barra de notificaciones.'),
                      backgroundColor: AppColors.accent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            Text('Reportes y Exportación', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.sm),
            _ActionCard(
              title: 'Exportar PDF',
              subtitle: 'Reporte visual listo para imprimir o compartir',
              icon: Icons.picture_as_pdf,
              color: AppColors.danger,
              isFullWidth: true,
              onTap: () => _showExportFilterDialog(context, ref, true),
            ),
            const SizedBox(height: AppSpacing.md),
            _ActionCard(
              title: 'Exportar CSV',
              subtitle: 'Datos estructurados para Excel o Google Sheets',
              icon: Icons.table_chart,
              color: AppColors.success,
              isFullWidth: true,
              onTap: () => _showExportFilterDialog(context, ref, false),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Respaldo en la Nube', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.sm),
            _ActionCard(
              title: 'Respaldar en Google Drive',
              subtitle: 'Sube una copia cifrada de tu base de datos a la nube.',
              icon: Icons.cloud_upload,
              color: AppColors.secondary,
              isFullWidth: true,
              onTap: () async {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Respaldando en Google Drive...')));
                  await ExportService.exportToGoogleDrive();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('¡Respaldo exitoso!')]),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                } catch(e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _ActionCard(
              title: 'Restaurar desde Drive',
              subtitle: 'Selecciona una versión anterior para recuperar tus datos.',
              icon: Icons.cloud_download,
              color: AppColors.warning,
              isFullWidth: true,
              onTap: () async {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buscando versiones...')));
                  final files = await ExportService.listAvailableBackups();
                  
                  if (files.isEmpty) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay respaldos en la nube')));
                    return;
                  }

                  if (!context.mounted) return;
                  
                  final selectedFileId = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surfaceLight,
                      title: const Text('Elegir Versión a Restaurar', style: AppTextStyles.h3),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: files.length,
                          itemBuilder: (context, index) {
                            final file = files[index];
                            final isLatest = file.name == 'finance_app.db';
                            final dateStr = file.modifiedTime != null 
                              ? DateFormat('dd/MM/yyyy hh:mm a').format(file.modifiedTime!.toLocal()) 
                              : 'Fecha desconocida';
                            
                            return ListTile(
                              leading: Icon(isLatest ? Icons.star : Icons.history, color: isLatest ? AppColors.success : AppColors.textSecondaryLight),
                              title: Text(isLatest ? 'Último Respaldo' : 'Versión Anterior'),
                              subtitle: Text(dateStr),
                              onTap: () => Navigator.pop(ctx, file.id),
                            );
                          },
                        ),
                      ),
                      actions: [
                        AppSecondaryButton(
                          text: 'Cancelar',
                          isFullWidth: false,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  );

                  if (selectedFileId != null && context.mounted) {
                     final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surfaceLight,
                          title: const Text('¿Restaurar esta versión?', style: AppTextStyles.h3),
                          content: const Text('Esto reemplazará tus datos actuales con la versión seleccionada. Se creará un respaldo automático antes.'),
                          actions: [
                            AppSecondaryButton(text: 'Cancelar', isFullWidth: false, onPressed: () => Navigator.pop(ctx, false)),
                            AppPrimaryButton(text: 'Restaurar', isFullWidth: false, backgroundColor: AppColors.warning, onPressed: () => Navigator.pop(ctx, true)),
                          ]
                        )
                     );

                     if (confirm == true) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restaurando datos...')));
                        await DatabaseHelper.instance.close();
                        final success = await ExportService.importSpecificBackup(selectedFileId);
                        if (success) {
                          ref.invalidate(transactionsProvider);
                          ref.invalidate(categoriesProvider);
                          ref.invalidate(budgetsProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('¡Datos restaurados con éxito!')]),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        }
                     }
                  }
                } catch(e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                }
              },
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isFullWidth;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: isFullWidth 
        ? Row(
            children: [
              _IconBox(icon: icon, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.label.copyWith(color: AppColors.textSecondaryLight), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.borderLight),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBox(icon: icon, color: color),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTextStyles.label.copyWith(color: AppColors.textSecondaryLight), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.borderSm,
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }
}

class _AppSettingsCard extends ConsumerStatefulWidget {
  const _AppSettingsCard();

  @override
  ConsumerState<_AppSettingsCard> createState() => _AppSettingsCardState();
}

class _AppSettingsCardState extends ConsumerState<_AppSettingsCard> {
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) setState(() { _biometricAvailable = available; _biometricEnabled = enabled; });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          // Dark Mode toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.dark_mode_outlined, color: AppColors.accent, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Modo Oscuro', style: AppTextStyles.bodyMedium),
                      Text(isDark ? 'Activado' : 'Desactivado', style: AppTextStyles.label.copyWith(color: AppColors.textSecondaryLight)),
                    ],
                  ),
                ],
              ),
              Switch.adaptive(
                value: isDark,
                activeColor: AppColors.accent,
                onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
              ),
            ],
          ),

          if (_biometricAvailable) ...[
            const Divider(height: AppSpacing.lg, color: AppColors.borderLight),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fingerprint, color: AppColors.success, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bloqueo Biométrico', style: AppTextStyles.bodyMedium),
                        Text(_biometricEnabled ? 'Activo - Huella/Rostro' : 'Desactivado', style: AppTextStyles.label.copyWith(color: AppColors.textSecondaryLight)),
                      ],
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: _biometricEnabled,
                  activeColor: AppColors.success,
                  onChanged: (val) async {
                    if (val) {
                      // Verify first before enabling
                      final ok = await BiometricService.authenticate();
                      if (ok) {
                        await BiometricService.setEnabled(true);
                        setState(() => _biometricEnabled = true);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Bloqueo biométrico activado'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
                        );
                      }
                    } else {
                      await BiometricService.setEnabled(false);
                      setState(() => _biometricEnabled = false);
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
