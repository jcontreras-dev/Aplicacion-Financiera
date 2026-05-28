# Capa de Seguridad de Respaldo (Backup Safety Layer)

Este documento describe la capa de seguridad implementada en la aplicación para proteger la base de datos de sobreescrituras accidentales durante los procesos de importación y exportación, tanto locales como hacia Google Drive.

## 1. Servicio de Seguridad (`BackupSafetyService`)

Se creó el servicio `lib/features/export_import/domain/backup_safety_service.dart` que expone los siguientes mecanismos de protección:

- **Creación de Respaldo Local Preventivo (`createLocalBackup`)**: Antes de cualquier importación que destruya la base de datos local actual, este método copia `finance_app.db` a `finance_app_local_backup_YYYYMMDD_HHMMSS.db`. Si la copia falla, el proceso entero de importación se aborta, garantizando que el usuario nunca pierda sus datos locales si hay un error al descargar de Google Drive.
- **Validación Estricta de Base de Datos (`validateLocalDatabase`)**: Antes de subir la base de datos local a Google Drive, este método verifica que la base de datos:
  1. Exista localmente.
  2. No esté vacía (tamaño > 0).
  3. Pueda ser abierta y leída sin errores de corrupción.
  4. Contenga todas las tablas requeridas por el esquema (`categories`, `transactions`, `budgets`, `fixed_expenses`, `fixed_expense_payments`).

## 2. Protección en la Exportación a Google Drive

Anteriormente, al exportar a Drive, el archivo viejo era borrado. El nuevo flujo en `ExportService.exportToGoogleDrive` funciona así:
1. Valida la base de datos local.
2. Descarga la lista de archivos remotos (`appDataFolder`).
3. Si ya existe un respaldo, lo **renombra** agregándole un timestamp (`finance_app_backup_YYYYMMDD_HHMMSS.db`), convirtiéndolo en un archivo versionado.
4. Sube la base local como el nuevo `finance_app.db` (copia más reciente).
5. Borra los backups más antiguos si el total de versiones excede el límite de 5 copias.

## 3. Protección en la Importación desde Google Drive

El flujo de importación (`ExportService.importFromGoogleDrive`) fue protegido así:
1. Se invoca obligatoriamente `BackupSafetyService.createLocalBackup()` primero.
2. Si se crea con éxito, se descarga el archivo `finance_app.db` de Drive.
3. El usuario recibe un mensaje de confirmación claro en la interfaz (`dashboard_screen.dart`) informando que se reemplazará la información de la pantalla pero se guardará un respaldo previo.

## 4. Beneficios Alcanzados
- **Cero pérdida de datos accidental**: Incluso si el usuario importa una base de datos vacía por error, el sistema retiene copias físicas que se pueden renombrar de vuelta a `finance_app.db`.
- **Cero subida de base corrupta**: La validación previa asegura que Google Drive siempre contendrá una copia íntegra de los datos del usuario.
- **Transparente para la UX**: Si bien hay comprobaciones adicionales de seguridad, se añadieron mensajes asíncronos (Snackbars) y diálogos informativos, logrando que el comportamiento general mantenga su fluidez.
