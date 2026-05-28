import 'package:finance_app/features/transactions/domain/transaction.dart';

class CategorizationEngine {
  // Reglas de categoría -> categoryId
  static final Map<String, String> _categoryRules = {
    'walmart': 'cat_1', // Alimentación
    'supermercado': 'cat_1',
    'restaurante': 'cat_1',
    'mcdonalds': 'cat_1',
    'burger': 'cat_1',
    'arroz': 'cat_1',
    'pollo': 'cat_1',
    'luz': 'cat_2', // Servicios
    'agua': 'cat_2',
    'internet': 'cat_2',
    'movistar': 'cat_2',
    'claro': 'cat_2',
    'energia': 'cat_2',
    'cemento': 'cat_3', // Otros
    'tubo': 'cat_3',
    'pvc': 'cat_3',
    'ferreteria': 'cat_3',
    'soldadura': 'cat_3',
  };

  // Reglas analíticas de descripción (De qué trata la factura realmente)
  static final Map<String, String> _descriptionRules = {
    'cemento': 'Materiales de Construcción',
    'soldadura': 'Materiales de Construcción',
    'pvc': 'Materiales de Construcción',
    'tubo': 'Materiales de Construcción',
    'ferreteria': 'Herramientas y Construcción',
    'arroz': 'Despensa / Alimentos',
    'carne': 'Despensa / Alimentos',
    'pizza': 'Comida Rápida',
    'restaurante': 'Comida en Restaurante',
    'luz': 'Pago de Servicio Eléctrico',
    'agua': 'Pago de Servicio de Agua',
    'internet': 'Pago de Servicio de Internet',
  };

  static String? suggestCategory(String? ocrText, String? description, {List<AppTransaction> history = const []}) {
    // 1. Machine Learning Local: Buscar patrones en el historial de gastos pasados
    if (description != null && description.trim().isNotEmpty) {
      final descLower = description.trim().toLowerCase();
      
      final matches = history.where((tx) {
        final txDesc = tx.description.toLowerCase();
        return txDesc == descLower || (txDesc.length > 4 && descLower.contains(txDesc));
      }).toList();

      if (matches.isNotEmpty) {
        // Encontrar la categoría históricamente más usada para esta palabra
        final Map<String, int> frequencies = {};
        for (var tx in matches) {
          frequencies[tx.categoryId] = (frequencies[tx.categoryId] ?? 0) + 1;
        }
        final mostFrequentCat = frequencies.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        return mostFrequentCat;
      }
    }

    // 2. Fallbacks de reglas heurísticas por defecto
    if (ocrText == null && description == null) return null;
    final combinedText = '${ocrText ?? ''} ${description ?? ''}'.toLowerCase();
    
    for (final entry in _categoryRules.entries) {
      if (combinedText.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  static String? suggestDescription(String? ocrText) {
    if (ocrText == null) return null;
    final text = ocrText.toLowerCase();
    
    for (final entry in _descriptionRules.entries) {
      if (text.contains(entry.key)) {
        return entry.value; 
      }
    }
    return null;
  }
}
