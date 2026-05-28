import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:finance_app/features/transactions/domain/transaction.dart';
import 'package:finance_app/features/categories/domain/category.dart';
import 'package:finance_app/features/export_import/domain/backup_safety_service.dart';
import 'package:intl/intl.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class ExportService {
  static Future<String> exportToCSV(List<AppTransaction> transactions, List<Category> categories, String reportLabel, double income, double expense, double balance) async {
    final Map<String, Category> categoryMap = {for (var c in categories) c.id: c};

    List<List<dynamic>> rows = [];
    rows.add(["Reporte Financiero: $reportLabel"]);
    rows.add(["Ingresos Totales", income]);
    rows.add(["Gastos Totales", expense]);
    rows.add(["Saldo Disponible", balance]);
    rows.add([]);
    rows.add(["Fecha", "Monto", "Categoría", "Descripción", "Tipo"]);

    for (var tx in transactions) {
      final categoryName = categoryMap[tx.categoryId]?.name ?? 'Desconocida';
      rows.add([
        DateFormat('yyyy-MM-dd hh:mm a').format(tx.date),
        tx.amount,
        categoryName,
        tx.description,
        tx.isIncome ? 'Ingreso' : 'Gasto'
      ]);
    }

    String csvData = ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/finanzas_export.csv';
    final file = File(path);
    await file.writeAsString(csvData);
    return path;
  }

  static pw.Widget _buildSummaryBox(String title, double amount, PdfColor color) {
    return pw.Container(
      width: 140,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: color.shade(.1),
        border: pw.Border.all(color: color, width: 2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(color: color, fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('\$${amount.toStringAsFixed(2)}', style: pw.TextStyle(color: color, fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ]
      )
    );
  }

  static Future<String> exportToPDF(List<AppTransaction> transactions, List<Category> categories, String reportLabel, double income, double expense, double balance) async {
    final pdf = pw.Document();
    final Map<String, Category> categoryMap = {for (var c in categories) c.id: c};
    
    final colorGreen = PdfColor.fromHex('#4CAF50');
    final colorRed = PdfColor.fromHex('#F44336');
    final colorBlue = PdfColor.fromHex('#2196F3');
    final colorDark = PdfColor.fromHex('#263238');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER BANNER
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: colorDark,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Reporte Financiero', style: pw.TextStyle(color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text(reportLabel, style: pw.TextStyle(color: PdfColors.white, fontSize: 14)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // SUMMARY BOXES
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryBox('Ingresos', income, colorGreen),
                  _buildSummaryBox('Gastos', expense, colorRed),
                  _buildSummaryBox('Saldo Disponible', balance, colorBlue),
                ]
              ),
              pw.SizedBox(height: 30),
              
              // TRANSACTIONS TITLE
              pw.Text('Detalle de Transacciones', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
              pw.SizedBox(height: 10),
              
              // TRANSACTIONS TABLE
              pw.TableHelper.fromTextArray(
                context: context,
                border: null,
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(color: colorDark),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.center,
                  4: pw.Alignment.centerLeft,
                },
                headers: ["Fecha", "Monto", "Categoría", "Tipo", "Descripción"],
                data: transactions.map((tx) {
                  final cat = categoryMap[tx.categoryId]?.name ?? '';
                  return [
                    DateFormat('yyyy-MM-dd').format(tx.date),
                    '\$ ${tx.amount.toStringAsFixed(2)}',
                    cat,
                    tx.isIncome ? 'Ingreso' : 'Gasto',
                    tx.description,
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/finanzas_reporte.pdf';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());
    return path;
  }

  static Future<void> createAutoJsonBackup(List<AppTransaction> transactions) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/finance_app_backup.json');
      final List<Map<String, dynamic>> jsonData = transactions.map((t) => t.toMap()).toList();
      await file.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      // Ignorar de forma transparente para no afectar UX
    }
  }

  static Future<void> exportDatabaseBackup() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'finance_app.db');
      final file = File(path);
      
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar/Sobreescribir tu respaldo',
          fileName: 'Respaldo_MisFinanzas.db',
          bytes: bytes,
        );

        if (outputFile != null) {
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
            await file.copy(outputFile);
          }
        }
      }
    } catch (e) {
      throw Exception('Error al exportar base de datos: $e');
    }
  }

  static Future<bool> importDatabaseBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        final importedFile = File(result.files.single.path!);
        final dbPath = await getDatabasesPath();
        final path = join(dbPath, 'finance_app.db');
        await importedFile.copy(path);
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Error al importar base de datos: $e');
    }
  }

  static Future<drive.DriveApi?> _getDriveApi() async {
    final googleSignIn = GoogleSignIn(
      scopes: [drive.DriveApi.driveAppdataScope, drive.DriveApi.driveFileScope],
    );
    final account = await googleSignIn.signIn();
    if (account == null) return null;

    final authHeaders = await account.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    return drive.DriveApi(authenticateClient);
  }

  static Future<void> exportToGoogleDrive() async {
    try {
      await BackupSafetyService.validateLocalDatabase();

      final driveApi = await _getDriveApi();
      if (driveApi == null) throw Exception('Autenticación cancelada');

      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'finance_app.db');
      final file = File(path);

      // Buscar si el archivo principal ya existe
      final query = "name = 'finance_app.db' and 'appDataFolder' in parents and trashed = false";
      final fileList = await driveApi.files.list(q: query, spaces: 'appDataFolder');
      
      final media = drive.Media(file.openRead(), file.lengthSync());

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // En lugar de borrar el archivo viejo, lo renombramos para mantenerlo como versión de respaldo
        final fileId = fileList.files!.first.id!;
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final backupName = 'finance_app_backup_$timestamp.db';
        
        final driveFileUpdate = drive.File()..name = backupName;
        await driveApi.files.update(driveFileUpdate, fileId);
      }
      
      // Subir archivo nuevo (ya sea porque no existía o porque el anterior fue renombrado)
      final driveFileCreate = drive.File()..name = 'finance_app.db'..parents = ['appDataFolder'];
      await driveApi.files.create(driveFileCreate, uploadMedia: media);

      // Limpiar versiones antiguas para mantener un máximo de 5
      final backupQuery = "name contains 'finance_app_backup_' and 'appDataFolder' in parents and trashed = false";
      final backupsList = await driveApi.files.list(q: backupQuery, spaces: 'appDataFolder', orderBy: 'createdTime');
      
      if (backupsList.files != null && backupsList.files!.length > 5) {
        final filesToDelete = backupsList.files!.length - 5;
        for (int i = 0; i < filesToDelete; i++) {
           await driveApi.files.delete(backupsList.files![i].id!);
        }
      }
    } catch (e) {
      throw Exception('Error subiendo a Google Drive: $e');
    }
  }

  static Future<bool> importFromGoogleDrive() async {
    try {
      await BackupSafetyService.createLocalBackup();

      final driveApi = await _getDriveApi();
      if (driveApi == null) throw Exception('Autenticación cancelada');

      final query = "name = 'finance_app.db' and 'appDataFolder' in parents and trashed = false";
      final fileList = await driveApi.files.list(q: query, spaces: 'appDataFolder');
      
      if (fileList.files == null || fileList.files!.isEmpty) {
        throw Exception('No existe ningún respaldo en Google Drive para esta cuenta');
      }

      final fileId = fileList.files!.first.id!;
      
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'finance_app.db');
      final targetFile = File(path);

      // Usando DownloadOptions.fullMedia para descargar el contenido
      final drive.Media fullMedia = await driveApi.files.get(
        fileId, 
        downloadOptions: drive.DownloadOptions.fullMedia
      ) as drive.Media;

      final fileStream = targetFile.openWrite();
      await fullMedia.stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();

      return true;
    } catch (e) {
      throw Exception('Error recuperando de Google Drive: $e');
    }
  }
}
