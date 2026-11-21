# OpenNodeDesk for macOS

**Un centro de conexiones remotas local-first para macOS.** Mantén cada servidor, cuenta y
parámetro de conexión en una única lista buscable, reutilizable y portátil — y pasa de "necesito esa
máquina" a una sesión en vivo en tres pasos.

[English](../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · **[Español]** · [Português](README.pt.md) · [Русский](README.ru.md) · [ไทย](README.th.md) · [Bahasa Indonesia](README.id.md) · [Tiếng Việt](README.vi.md)

Versión actual: **v2.3.5**

---

## Qué es

OpenNodeDesk no es otro cliente de escritorio remoto. La representación de la pantalla remota, la
redirección de periféricos y el audio/vídeo delegan en el cliente más maduro de la plataforma:
Microsoft Windows App para RDP, el uso compartido de pantalla integrado para VNC y un terminal
integrado para SSH. OpenNodeDesk se ocupa de **el otro 90 %**: el inventario, los parámetros, las
credenciales, los recordatorios de caducidad y el historial de conexiones.

Principios de diseño:

- **Conexión en tres segundos** — busca, pulsa Return y la sesión se abre.
- **Local first, funciona sin conexión, sin cuenta** — abre, busca, edita y conéctate sin red.
- **No reinventes la rueda** — la representación remota corresponde al mejor cliente de la plataforma.
- **Parámetros explicables** — cada valor efectivo se etiqueta como *personalizado / plantilla / predeterminado*.
- **Fallos explicables** — los errores incluyen una causa y sugerencias prácticas, nunca un código sin más.
- **Datos portátiles** — exportar e importar con un clic; migra de máquina con un solo archivo.
- **Teclado primero** — cada acción principal tiene un atajo.

## Características

### Centro de activos
- Diseños de tabla y cuadrícula; búsqueda por nombre, host, grupo, propietario y notas.
- Favoritos, conexiones recientes y grupos plegables en la barra lateral.
- Mostrar/ocultar y reordenar por columna, además de un tamaño de fuente global para la lista.
- Recordatorios de caducidad: los activos que caducan en un plazo de 30 días (o que ya han caducado) se señalan en su sitio.
- Detección de duplicados por **host + puerto** al importar.

### RDP / SSH / VNC
- Puertos predeterminados por protocolo (3389 / 22 / 5900) con anulación libre.
- **RDP** — genera un archivo `.rdp` temporal para Microsoft Windows App; el modo de ventana, la
  profundidad de color, la redirección de unidad/audio/portapapeles y la resolución son
  configurables. Los binarios FreeRDP se detectan y se lanzan directamente con la contraseña
  almacenada, omitiendo el aviso de credenciales. El autorrelleno de contraseña para el diálogo de
  credenciales de Windows App usa la API de Accessibility de macOS.
- **VNC** — usa el uso compartido de pantalla integrado de forma predeterminada; los visores
  externos (RealVNC, TigerVNC…) pueden configurarse con una plantilla de argumentos de lanzamiento
  que admite `{host} {port} {display} {user} {password}`.
- **SSH** — un terminal real integrado en la app (SwiftTerm), con host de salto (`-J`),
  autenticación por clave privada, compatibilidad con la frase de contraseña de la clave y
  argumentos `ssh` adicionales configurables.

### Plantillas de conexión
Conjuntos de parámetros reutilizables (protocolo, puerto, nombre de usuario, redirección, modo de
ventana, profundidad de color, tamaño de ventana de SSH). Cada parámetro resuelto muestra su valor
actual **y de dónde proviene**.

### Espacio de trabajo de sesiones
- Varias sesiones en paralelo con diseños divididos intercambiables y maximización por sesión.
- Un cuadro "abrir activo" en la barra de herramientas: escribe un nombre o host y pulsa Return, o
  elige de la lista.
- Se admiten ventanas SSH independientes cuando las prefieras fuera del espacio de trabajo.

### Transferencia de archivos SFTP
- Explorador de archivos remotos completo por activo: directorios, tamaños, permisos y horas de modificación.
- Sube y descarga archivos o carpetas enteras, con reanudación (`reput` / `reget`).
- Crea carpetas, elimina archivos o carpetas vacías y arrastra y suelta archivos en la carpeta actual.
- Disponible desde la barra de herramientas de la sesión y desde el menú contextual del terminal SSH.

### Menú contextual del terminal SSH
Copiar, pegar, seleccionar todo y "transferencia de archivos" justo donde escribes. Cuando un
programa remoto captura el ratón (vim, tmux), el clic derecho se transmite al programa remoto como
es de esperar.

### Credenciales
- Las contraseñas y las frases de contraseña de las claves se guardan **solo** en el Keychain de macOS, nunca en los archivos de datos.
- Eliminar un activo o desmarcar "recordar contraseña" elimina la entrada del Keychain.

### Importar, exportar y sincronizar
- Importa desde CSV o Excel (`.xlsx`) con asignación automática de columnas y una vista previa de validación.
- Exporta a CSV o JSON, con selección por campo; los campos sensibles se desmarcan de forma predeterminada.
- La sincronización en la nube obtiene primero una vista previa y fusiona solo lo que selecciones — únicamente activos y plantillas, nunca contraseñas.

### Sondeo de accesibilidad
Sondeo TCP de activos individuales, de la selección o de todo el inventario, bajo demanda o con temporizador.

### Bloqueo de la app (frase de contraseña de protección)
- Bloqueo opcional con frase de contraseña y autobloqueo por inactividad (1–60 minutos).
- Hash de la frase de contraseña con **PBKDF2-SHA256**, 100 000 iteraciones y una sal aleatoria de 128 bits.
- Se emite un código de recuperación una sola vez durante la configuración (Crockford Base32, tolerante con `O/0`, `I/L/1`).
- Configurable: tras 5 fallos consecutivos, borrar los datos locales automáticamente, o permanecer bloqueado y requerir un borrado manual.

### Apariencia y ayuda
- Tema Seguir sistema / Claro / Oscuro; interfaz en chino simplificado e inglés.
- Un manual de ayuda dentro de la app que cubre el uso de VNC, la resolución de problemas por
  protocolo, las ubicaciones de los datos y la privacidad de las credenciales.

## Requisitos

| Elemento | Requisito |
| --- | --- |
| macOS | 14.0 (Sonoma) o posterior |
| Transporte RDP | Microsoft Windows App (desde la App Store) |
| Transporte VNC | Uso compartido de pantalla integrado, o RealVNC / TigerVNC y similares |
| Autorrelleno de contraseña RDP | Permiso de Accessibility para OpenNodeDesk |
| Compilación desde el código fuente | Xcode 16 o posterior (toolchain de Swift 6) |

## Instalación

1. Descarga `OpenNodeDesk-<version>-macos.zip` desde la página de
   [Releases](https://github.com/OpenNodeSaas/OpenNodeDesk-macos/releases).
2. Descomprime y arrastra `OpenNodeDesk.app` a `/Applications`.
3. La compilación no está notarizada por Apple, por lo que Gatekeeper puede avisar en el primer
   inicio — haz clic derecho en la app y elige **Abrir**, o permítela en *Ajustes del Sistema →
   Privacidad y seguridad*.

## Compilar desde el código fuente

```bash
git clone https://github.com/OpenNodeSaas/OpenNodeDesk-macos.git
cd OpenNodeDesk-macos
make bundle   # release build + dist/OpenNodeDesk.app
make run      # build, bundle and launch
```

Objetivos útiles: `make check` (compila y muestra diagnósticos), `make clean` (descarta `.build` y
`dist`), `make reset` (elimina los datos locales de `~/Library/Application Support/RemotePilot`).

## Estructura del proyecto

```
Sources/RemotePilot/
├── App/            App entry point, global model, commands and menus
├── Core/           SSH/SFTP, Keychain, probing, import/export, sync, carrier detection, RDP auto-fill
├── Design/         Design tokens and shared components
├── Localization/   Chinese source strings + English string table
├── Models/         Asset, template, settings and runtime models
├── Views/          Sidebar, asset center, workspace, sessions, settings, help, dialogs
└── main.swift      Entry point (also serves as the SSH_ASKPASS helper)
Resources/          Info.plist and app icon
docs/              Design documents and translated READMEs
```

## Datos y privacidad

- Los activos, las plantillas y la configuración residen en `~/Library/Application Support/RemotePilot`
  (`assets.json`, `settings.json`).
- Las contraseñas y las frases de contraseña de las claves se escriben solo en el Keychain de macOS;
  nunca forman parte de una exportación ni de una carga de sincronización. Por tanto, moverte a
  otra máquina requiere volver a introducirlas.
- La app funciona totalmente sin conexión; el endpoint de sincronización en la nube es opcional y lo
  proporciona el usuario.

## Notas y limitaciones

- Windows App de macOS no puede alojar varias sesiones como pestañas en una sola ventana; elegir el
  modo de ventana con pestañas abre una ventana normal en su lugar. Usa el espacio de trabajo de
  sesiones para varias sesiones.
- Si no hay ningún transporte RDP instalado, los intentos de conexión explican qué instalar y dónde.
- El identificador de paquete interno `com.remotepilot.macos` y el directorio de datos
  `RemotePilot` se han mantenido intencionadamente sin cambios desde el renombrado, de modo que los
  activos, la configuración y las entradas del Keychain existentes siguen funcionando tras la
  actualización.

## Documentación

- [Diseño de producto y UX](PRODUCT_UX_DESIGN.md)
- [Delta de diseño](PRODUCT_UX_DESIGN_DELTA.md)
- [Bloqueo con frase de contraseña y autobloqueo por inactividad](../.trae/documents/保护口令与空闲自动锁定-macOS.md)
