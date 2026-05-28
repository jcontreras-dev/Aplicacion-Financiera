import 'dart:math';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String rawText;
  final String tabulatedText;
  final double? probableAmount;
  final String? probableDescription;
  final DateTime? probableDate;

  OcrResult({required this.rawText, required this.tabulatedText, this.probableAmount, this.probableDescription, this.probableDate});
}

class OcrService {
  static final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static Future<OcrResult> processImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    List<TextElement> elements = [];
    for (var block in recognizedText.blocks) {
      for (var line in block.lines) {
        elements.addAll(line.elements);
      }
    }

    elements.sort((a, b) => a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy));

    List<List<TextElement>> rows = [];
    if (elements.isNotEmpty) {
      List<TextElement> currentRow = [elements.first];
      for (int i = 1; i < elements.length; i++) {
        final el = elements[i];
        final prev = currentRow.last;
        if ((el.boundingBox.center.dy - prev.boundingBox.center.dy).abs() < 18) {
          currentRow.add(el);
        } else {
          rows.add(currentRow);
          currentRow = [el];
        }
      }
      rows.add(currentRow);
    }

    StringBuffer tabulatedBuffer = StringBuffer();
    StringBuffer rawBuffer = StringBuffer();
    
    double? detectedAmount;
    List<double> allAmounts = [];
    final amountRegex = RegExp(r'(?:\d+[.,\s]*)+\d+');
    
    String? storeName;

    for (int i = 0; i < rows.length; i++) {
      var row = rows[i];
      row.sort((a, b) => a.boundingBox.center.dx.compareTo(b.boundingBox.center.dx));
      
      String rowText = "";
      double lastX = 0;
      for (var el in row) {
        double currentX = el.boundingBox.left;
        if (lastX > 0 && (currentX - lastX) > 15) {
           int spaces = ((currentX - lastX) / 8).round();
           rowText += " " * min(15, spaces); 
        } else if (lastX > 0) {
           rowText += " ";
        }
        rowText += el.text;
        lastX = el.boundingBox.right;
      }
      
      String rawRowStr = row.map((e) => e.text).join(' ');
      rawBuffer.writeln(rawRowStr);
      tabulatedBuffer.writeln(rowText);
      
      if (storeName == null && rawRowStr.trim().length >= 4) {
         if (!RegExp(r'\d').hasMatch(rawRowStr)) {
            storeName = rawRowStr.trim();
         }
      }

      final textUpper = rawRowStr.toUpperCase();
      final matches = amountRegex.allMatches(textUpper);

      bool isTotalLine = textUpper.contains('TOTAL') && !textUpper.contains('IMPUESTO') && !textUpper.contains('IVA');

      for (var match in matches) {
        String amountStr = match.group(0)!;
        double val = _parseAmount(amountStr);
        if (val > 0) allAmounts.add(val);

        if (isTotalLine) {
           if (detectedAmount == null || val > detectedAmount) {
             detectedAmount = val;
           }
        }
      }
    }

    if (detectedAmount == null && allAmounts.isNotEmpty) {
      allAmounts.sort();
      final validAmounts = allAmounts.where((a) => a < 50000000).toList();
      if (validAmounts.isNotEmpty) {
        detectedAmount = validAmounts.last;
      }
    }
    
    if (storeName == null || storeName.isEmpty) {
       storeName = "Factura ${DateTime.now().day}/${DateTime.now().month}";
    }

    return OcrResult(
      rawText: rawBuffer.toString(),
      tabulatedText: tabulatedBuffer.toString(),
      probableAmount: detectedAmount,
      probableDescription: storeName,
      probableDate: DateTime.now(),
    );
  }

  static double _parseAmount(String amountStr) {
    String clean = amountStr.replaceAll(RegExp(r'[^\d.,]'), '');
    if (clean.isEmpty) return 0.0;
    
    int lastDot = clean.lastIndexOf('.');
    int lastComma = clean.lastIndexOf(',');
    int lastSeparator = max(lastDot, lastComma);
    
    if (lastSeparator != -1 && (clean.length - lastSeparator <= 3)) {
      String integers = clean.substring(0, lastSeparator).replaceAll(RegExp(r'[.,]'), '');
      String decimals = clean.substring(lastSeparator + 1);
      return double.tryParse(integers + "." + decimals) ?? 0.0;
    } else {
      String integers = clean.replaceAll(RegExp(r'[.,]'), '');
      return double.tryParse(integers) ?? 0.0;
    }
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
