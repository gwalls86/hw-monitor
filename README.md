# 🚀 Hardware Monitor PRO

Una estación de monitoreo térmico y de rendimiento avanzada con estética **Cyberpunk**, diseñada para el seguimiento exhaustivo de CPU, GPU, RAM y múltiples unidades de almacenamiento de forma sencilla y elegante.

![Versión](https://img.shields.io/badge/version-2.6-cyan)
![Platform](https://img.shields.io/badge/platform-Windows-blue)
![Licencia](https://img.shields.io/badge/license-MIT-purple)

---

## 🎨 Icono del Proyecto

<p align="center">
  <img src="icon.png" width="200" alt="Hardware Monitor Icon">
</p>

---

## 🚀 Características Principales

*   **VISTA EN VIVO (Humanizada)**: Visualización en tiempo real con barras de progreso dinámicas y sensores de temperatura críticos.
*   **HISTORIAL DINÁMICO (Precision-Charts)**: Gráficos interactivos con escalado inteligente de **+/- 10 unidades** para una visualización máxima del detalle térmico.
*   **PALETA DE 6 COLORES PRO**: Identificación instantánea mediante colores de alto contraste (Cyan, Púrpura, Naranja, Esmeralda, Rosa y Ámbar).
*   **MEMORIA PERSISTENTE**: El sistema recuerda mediante `localStorage` tu última vista, el intervalo de tiempo (1m a 1h) y qué sensores has decidido ocultar en la gráfica.
*   **TELEMETRÍA MULTI-DISCO**: Los discos (C, D, E...) se detectan y ordenan alfabéticamente de forma automática.
*   **DISEÑO PREMIUM**: Tipografía **Inter** para UI y **JetBrains Mono** para datos técnicos, con efectos de "glassmorphism" y neón.

---

## 🛠️ Requisitos del Sistema

1.  **Windows 10/11** con PowerShell habilitado.
2.  **Python 3.x** instalado.
3.  **HWiNFO64** instalado y configurado (ver sección abajo).

---

## ⚙️ Configuración Obligatoria (HWiNFO64)

Para que el dashboard pueda leer los datos, es **imprescindible** configurar HWiNFO64 de la siguiente manera:

1.  **Modo de Inicio**: Al abrir HWiNFO, selecciona únicamente la casilla **"Sensors-only"**.
2.  **Memoria Compartida**:
    *   Ve a `Settings` -> `General`.
    *   Asegúrate de que la opción **"Shared Memory Support"** esté **activada** (marcada).
    *   *Nota: En la versión gratuita de HWiNFO, esta opción se desactiva tras 12 horas; simplemente reinicia la aplicación para reactivarla.*
3.  **Ventana**: Se recomienda marcar **"Minimize Main Window on Startup"** y **"Minimize Sensors on Startup"** para que no estorbe en el escritorio.

---

## 📦 Instalación y Arranque

1.  Configura HWiNFO64 según las instrucciones anteriores.
2.  Asegúrate de que todos los archivos estén en la carpeta raíz.
3.  Ejecuta el orquestador principal:
    ```bash
    start_monitor.bat
    ```
    *Este comando se encargará de limpiar procesos antiguos, iniciar el motor de telemetría y levantar el servidor web automáticamente.*

3.  Abre tu navegador en: `http://localhost:8000`.

---

## 🎮 Guía de Usuario


### Navegación
*   **Panel TIEMPO REAL**: Muestra el estado actual de los componentes con barras de progreso y colores de alerta dinámicos.
*   **Panel ESTADÍSTICAS**: Muestra la evolución térmica. Puedes alternar rangos desde **1 MIN** (análisis de picos) hasta **1 HORA** (tendencias).

### Control de Gráficos
*   **Ocultar Datos**: Haz clic en la leyenda superior para ocultar/mostrar sensores. Esta selección es persistente entre sesiones.
*   **Escalado Dinámico**: La gráfica se ajusta automáticamente al valor máximo y mínimo visible, añadiendo un margen de 10 unidades para mejorar la legibilidad.

---

## 🏗️ Arquitectura Técnica

1.  **`hwmonitor.ps1`**: Lee los sensores de hardware y genera el JSON de telemetría.
2.  **`server.py`**: Servidor ligero en Python que gestiona los datos y el buffer de historial.
3.  **`monitor.html`**: Interfaz visual avanzada desarrollada con Vanilla JS y Chart.js.

---

## ⚠️ Solución de Problemas

*   **¿No se ven las temperaturas?**: Ejecuta `start_monitor.bat` como Administrador la primera vez para asegurar el acceso a los contadores de hardware.
*   **Estado "SINCRONIZANDO" persistente**: Verifica que el servidor Python esté corriendo y que no haya firewalls bloqueando el puerto 8000.

---

> **Nota**: Este proyecto ha sido diseñado para ofrecer una experiencia visual premium, ideal para monitores secundarios pequeños o setups gaming de alto nivel.

---

## 📝 Notas de Versión
- **Versión**: 2.6
- **Autor**: gwalls86
- **Tecnologías**: Python, PowerShell, HTML/JS (Vanilla), HWiNFO64.

---
*Desarrollado por gwalls86*
