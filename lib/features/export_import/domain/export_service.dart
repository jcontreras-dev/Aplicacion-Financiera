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
import 'package:archive/archive_io.dart';

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
      width: 150,
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey200, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title.toUpperCase(), style: pw.TextStyle(color: PdfColors.grey600, fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount), 
            style: pw.TextStyle(color: color, fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ]
      )
    );
  }

  static Future<String> exportToPDF(List<AppTransaction> transactions, List<Category> categories, String reportLabel, double income, double expense, double balance) async {
    final pdf = pw.Document();
    final Map<String, Category> categoryMap = {for (var c in categories) c.id: c};
    
    final colorGreen = PdfColor.fromHex('#059669'); // Emerald 600
    final colorRed = PdfColor.fromHex('#DC2626');   // Red 600
    final colorBlue = PdfColor.fromHex('#0F172A');  // Slate 900 (Corporate)
    final colorDark = PdfColor.fromHex('#0F172A');

    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('INFORME EJECUTIVO', style: pw.TextStyle(color: colorDark, fontSize: 22, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2)),
                      pw.SizedBox(height: 4),
                      pw.Text('Resumen de Movimientos Financieros', style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('PERIODO', style: pw.TextStyle(color: PdfColors.grey500, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text(reportLabel, style: pw.TextStyle(color: colorDark, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ]
                  )
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Divider(color: PdfColors.grey300, thickness: 1),
              pw.SizedBox(height: 20),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            padding: const pw.EdgeInsets.only(top: 10),
            decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey200))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generado por Sistema Contable Enterprise', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
              ]
            )
          );
        },
        build: (pw.Context context) {
          return [
            // SUMMARY BOXES
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryBox('Total Ingresos', income, colorGreen),
                _buildSummaryBox('Total Gastos', expense, colorRed),
                _buildSummaryBox('Balance Neto', balance, colorBlue),
              ]
            ),
            pw.SizedBox(height: 40),
            
            // TRANSACTIONS TITLE
            pw.Text('REGISTRO DE OPERACIONES', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600, letterSpacing: 1)),
            pw.SizedBox(height: 10),
            
            if (transactions.isEmpty)
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(40),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Text('No se encontraron operaciones en el periodo seleccionado.', 
                  style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 12)),
              )
            else
              // TRANSACTIONS TABLE
              pw.TableHelper.fromTextArray(
                context: context,
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                ),
                headerStyle: pw.TextStyle(color: PdfColors.grey800, fontWeight: pw.FontWeight.bold, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                cellPadding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
                },
                headers: ["Fecha", "Categoría", "Descripción", "Monto"],
                data: transactions.map((tx) {
                  final cat = categoryMap[tx.categoryId]?.name ?? '';
                  final amountStr = currencyFormat.format(tx.amount);
                  return [
                    DateFormat('dd/MM/yyyy').format(tx.date),
                    cat,
                    tx.description,
                    '${tx.isIncome ? "" : "-"}$amountStr',
                  ];
                }).toList(),
              ),
          ];
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

  static Future<void> signOutGoogleDrive() async {
    final googleSignIn = GoogleSignIn(
      scopes: [drive.DriveApi.driveAppdataScope, drive.DriveApi.driveFileScope],
    );
    await googleSignIn.signOut();
  }

  static Future<void> exportToGoogleDrive() async {
    try {
      await BackupSafetyService.validateLocalDatabase();

      final driveApi = await _getDriveApi();
      if (driveApi == null) throw Exception('Autenticación cancelada');

      final dbPath = await getDatabasesPath();
      final dbFilePath = join(dbPath, 'finance_app.db');
      final dbFile = File(dbFilePath);

      // Crear archivo ZIP temporal
      final tempDir = await getTemporaryDirectory();
      final zipFilePath = '${tempDir.path}/finance_app_backup.zip';
      final encoder = ZipFileEncoder();
      encoder.create(zipFilePath);
      
      // Añadir base de datos al ZIP
      if (await dbFile.exists()) {
        encoder.addFile(dbFile);
      }

      // Añadir carpeta de imágenes (app_flutter) al ZIP si existe
      final appDocsDir = await getApplicationDocumentsDirectory();
      if (await appDocsDir.exists()) {
        final List<FileSystemEntity> files = appDocsDir.listSync();
        for (var f in files) {
          if (f is File && (f.path.endsWith('.jpg') || f.path.endsWith('.png'))) {
            encoder.addFile(f);
          }
        }
      }
      encoder.close();

      final zipFile = File(zipFilePath);

      // Buscar si el archivo principal ya existe
      final query = "(name = 'finance_app_backup.zip' or name = 'finance_app.db') and 'appDataFolder' in parents and trashed = false";
      final fileList = await driveApi.files.list(q: query, spaces: 'appDataFolder');
      
      final media = drive.Media(zipFile.openRead(), zipFile.lengthSync());

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // Renombrar el archivo viejo
        final fileId = fileList.files!.first.id!;
        final oldName = fileList.files!.first.name!;
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final isZip = oldName.endsWith('.zip');
        final backupName = 'finance_app_backup_$timestamp.${isZip ? "zip" : "db"}';
        
        final driveFileUpdate = drive.File()..name = backupName;
        await driveApi.files.update(driveFileUpdate, fileId);
      }
      
      // Subir archivo ZIP nuevo
      final driveFileCreate = drive.File()..name = 'finance_app_backup.zip'..parents = ['appDataFolder'];
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

      final query = "(name = 'finance_app_backup.zip' or name = 'finance_app.db') and 'appDataFolder' in parents and trashed = false";
      final fileList = await driveApi.files.list(q: query, spaces: 'appDataFolder');
      
      if (fileList.files == null || fileList.files!.isEmpty) {
        throw Exception('No existe ningún respaldo en Google Drive para esta cuenta');
      }

      // Dar prioridad al .zip sobre el .db viejo
      fileList.files!.sort((a, b) => (b.name?.endsWith('.zip') ?? false) ? 1 : -1);
      final fileId = fileList.files!.first.id!;
      final isZip = fileList.files!.first.name!.endsWith('.zip');
      
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = '${tempDir.path}/downloaded_backup.${isZip ? "zip" : "db"}';
      final targetFile = File(tempFilePath);

      // Usando DownloadOptions.fullMedia para descargar el contenido
      final drive.Media fullMedia = await driveApi.files.get(
        fileId, 
        downloadOptions: drive.DownloadOptions.fullMedia
      ) as drive.Media;

      final fileStream = targetFile.openWrite();
      await fullMedia.stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();

      final dbPath = await getDatabasesPath();
      final appDocsDir = await getApplicationDocumentsDirectory();

      if (isZip) {
        // Extraer ZIP
        final bytes = targetFile.readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);
        
        for (final file in archive) {
          final filename = basename(file.name);
          if (file.isFile) {
            final data = file.content as List<int>;
            if (filename == 'finance_app.db') {
              File(join(dbPath, 'finance_app.db'))
                ..createSync(recursive: true)
                ..writeAsBytesSync(data);
            } else if (filename.endsWith('.jpg') || filename.endsWith('.png')) {
              File(join(appDocsDir.path, filename))
                ..createSync(recursive: true)
                ..writeAsBytesSync(data);
            }
          }
        }
      } else {
        // Respaldo antiguo (.db directo)
        await targetFile.copy(join(dbPath, 'finance_app.db'));
      }

      return true;
    } catch (e) {
      throw Exception('Error recuperando de Google Drive: $e');
    }
  }

  static Future<List<drive.File>> listAvailableBackups() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) throw Exception('Autenticación cancelada');

      final query = "(name = 'finance_app_backup.zip' or name = 'finance_app.db' or name contains 'finance_app_backup_') and 'appDataFolder' in parents and trashed = false";
      final fileList = await driveApi.files.list(q: query, spaces: 'appDataFolder', orderBy: 'modifiedTime desc');
      
      return fileList.files ?? [];
    } catch (e) {
      throw Exception('Error obteniendo lista de respaldos: $e');
    }
  }

  static Future<bool> importSpecificBackup(String fileId) async {
    try {
      await BackupSafetyService.createLocalBackup();

      final driveApi = await _getDriveApi();
      if (driveApi == null) throw Exception('Autenticación cancelada');

      final fileList = await driveApi.files.get(fileId) as drive.File;
      final isZip = fileList.name != null && fileList.name!.endsWith('.zip');

      final tempDir = await getTemporaryDirectory();
      final tempFilePath = '${tempDir.path}/downloaded_specific_backup.${isZip ? "zip" : "db"}';
      final targetFile = File(tempFilePath);

      final drive.Media fullMedia = await driveApi.files.get(
        fileId, 
        downloadOptions: drive.DownloadOptions.fullMedia
      ) as drive.Media;

      final fileStream = targetFile.openWrite();
      await fullMedia.stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();

      final dbPath = await getDatabasesPath();
      final appDocsDir = await getApplicationDocumentsDirectory();

      if (isZip) {
        final bytes = targetFile.readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);
        
        for (final file in archive) {
          final filename = basename(file.name);
          if (file.isFile) {
            final data = file.content as List<int>;
            if (filename == 'finance_app.db') {
              File(join(dbPath, 'finance_app.db'))
                ..createSync(recursive: true)
                ..writeAsBytesSync(data);
            } else if (filename.endsWith('.jpg') || filename.endsWith('.png')) {
              File(join(appDocsDir.path, filename))
                ..createSync(recursive: true)
                ..writeAsBytesSync(data);
            }
          }
        }
      } else {
        await targetFile.copy(join(dbPath, 'finance_app.db'));
      }

      return true;
    } catch (e) {
      throw Exception('Error recuperando respaldo específico: $e');
    }
  }
}
