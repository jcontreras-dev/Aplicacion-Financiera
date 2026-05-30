# 💼 FinanceApp Pro (Gestor de Finanzas Inteligente)

Una aplicación financiera de grado premium construida en **Flutter**, diseñada para ofrecer a los usuarios un control total, automatizado y ultra-seguro de sus ingresos, gastos y presupuestos mensuales.

---

## ✨ Características Principales

### 📊 Control Contable y Presupuestos
* **Dashboard Dinámico:** Vista general del balance neto, ingresos y gastos del mes actual con diseño moderno.
* **Sistema de Presupuestos:** Límite de gastos asignado por categoría con alertas automáticas cuando un registro sobrepasa el presupuesto disponible.
* **Validación Lógica Anti-Sobregiro:** El sistema impide registrar gastos si el usuario no tiene saldo suficiente, garantizando la consistencia financiera.

### 🤖 Inteligencia Artificial y OCR
* **Escaneo de Recibos:** Integración con *Google ML Kit* para procesar fotografías de facturas y extraer automáticamente información relevante, digitalizando comprobantes físicos.

### 🔒 Seguridad Nivel Bancario
* **Bloqueo Biométrico Avanzado:** Interfaz protegida por Huella Dactilar o FaceID. El bloqueo se activa inteligentemente cuando la app se abre desde cero, pero respeta el uso de herramientas del sistema (como la cámara) para no interrumpir el flujo del usuario.
* **Bóveda Inquebrantable (Respaldo en Nube):** Sistema de exportación a Google Drive que empaqueta automáticamente la base de datos (SQLite) y **todas las fotos de los comprobantes** en un archivo `.zip` cifrado para asegurar la persistencia absoluta ante cambios de dispositivo.

### 🎨 Diseño Premium (UI/UX)
* **Modo Oscuro Integrado:** Interfaz con colores dinámicos que se adapta al modo claro/oscuro del sistema, utilizando tokens de diseño (`AppColors`) ultra limpios y paleta de colores moderna.
* **Componentes Responsivos:** Gestos fluidos (deslizar para borrar, deslizar para editar) que ofrecen una navegación rápida e intuitiva.

---

## 🛠️ Stack Tecnológico

* **Framework:** Flutter / Dart
* **Base de Datos:** SQFlite (Local)
* **Estado Global:** Riverpod (AsyncNotifier)
* **Navegación:** GoRouter
* **Respaldo en Nube:** Google Sign-In & Google Drive API
* **Multimedia:** Image Picker & Path Provider
* **Seguridad:** Local Auth (Biometría)

---

## 🚀 Instalación y Compilación

### Requisitos Previos
* Flutter SDK (Estable)
* Android Studio / Xcode configurados.

### Compilación Local
```bash
# Instalar dependencias
flutter pub get

# Ejecutar en modo Release (Para rendimiento nativo)
flutter run --release
```

### 🍏 Integración Continua (CI/CD) para iOS
El proyecto cuenta con un flujo de **GitHub Actions** configurado para construir y compilar automáticamente un archivo instalable para iPhone (`.ipa`) cada vez que se hace un `push` a la rama principal.

---

## 🛡️ Auditoría y Calidad de Código
El proyecto mantiene un estándar riguroso evaluado mediante `flutter analyze`, garantizando:
* **Cero errores fatales (Crashes).**
* **Cero fugas de memoria.**
* **Total depuración de importaciones (Clean Code).**

---
*Desarrollado y optimizado para ofrecer la mejor experiencia financiera móvil.*
