# OpenNodeDesk für macOS

**Ein Local-First-Hub für Remote-Verbindungen unter macOS.** Behalten Sie jeden Server, jedes Konto und jeden
Verbindungsparameter in einer einzigen durchsuchbaren, wiederverwendbaren, portablen Liste — und gelangen Sie von
„Ich brauche diese Maschine“ in drei Schritten zu einer laufenden Sitzung.

[English](../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · **[Deutsch]** · [Français](README.fr.md) · [Español](README.es.md) · [Português](README.pt.md) · [Русский](README.ru.md) · [ไทย](README.th.md) · [Bahasa Indonesia](README.id.md) · [Tiếng Việt](README.vi.md)

Aktuelle Version: **v2.3.5**

---

## Was es ist

OpenNodeDesk ist kein weiterer Remote-Desktop-Client. Das Rendern des entfernten Bildschirms, die
Peripherie-Weiterleitung sowie Audio/Video folgen dem ausgereiftesten Client der Plattform — Microsoft Windows App
für RDP, der integrierten Bildschirmfreigabe für VNC und einem integrierten Terminal für SSH. OpenNodeDesk besitzt
**die anderen 90 %**: das Inventar, die Parameter, die Anmeldedaten, die Ablauf-Erinnerungen und die
Verbindungshistorie.

Designprinzipien:

- **Verbindung in drei Sekunden** — suchen, Return drücken, die Sitzung öffnet sich.
- **Local First, offlinefähig, kein Konto** — öffnen, suchen, bearbeiten und verbinden ohne Netzwerk.
- **Das Rad nicht neu erfinden** — das Remote-Rendering gehört zum besten Client der Plattform.
- **Erklärbare Parameter** — jeder wirksame Wert wird als *benutzerdefiniert / Vorlage / Standard* gekennzeichnet.
- **Erklärbare Fehler** — Fehler enthalten eine Ursache und umsetzbare Hinweise, niemals nur einen rohen Code.
- **Portable Daten** — Export und Import mit einem Klick; Umzug auf eine andere Maschine mit einer einzigen Datei.
- **Tastatur zuerst** — jede Kernaktion hat eine Tastenkombination.

## Funktionen

### Asset-Center
- Tabellen- und Rasterlayout; Suche über Name, Host, Gruppe, Besitzer und Notizen.
- Favoriten, letzte Verbindungen und einklappbare Gruppen in der Seitenleiste.
- Ein-/Ausblenden und Neuordnen einzelner Spalten sowie eine globale Listenschriftgröße.
- Ablauf-Erinnerungen: Assets, die innerhalb von 30 Tagen ablaufen (oder bereits abgelaufen sind), werden direkt gekennzeichnet.
- Duplikaterkennung nach **Host + Port** beim Import.

### RDP / SSH / VNC
- Standardports je Protokoll (3389 / 22 / 5900) mit freier Überschreibung.
- **RDP** — erzeugt eine temporäre `.rdp`-Datei für Microsoft Windows App; Fenstermodus, Farbtiefe,
  Laufwerk-/Audio-/Zwischenablage-Weiterleitung und Auflösung sind alle konfigurierbar. FreeRDP-Binaries
  werden erkannt und direkt mit dem gespeicherten Passwort gestartet, wobei die Anmeldedaten-Abfrage übersprungen wird.
  Die automatische Passworteingabe für den Anmeldedaten-Dialog von Windows App verwendet die macOS Accessibility API.
- **VNC** — verwendet standardmäßig die integrierte Bildschirmfreigabe; externe Viewer (RealVNC, TigerVNC…)
  können mit einer Startargument-Vorlage konfiguriert werden, die
  `{host} {port} {display} {user} {password}` unterstützt.
- **SSH** — ein echtes Terminal, eingebettet in die App (SwiftTerm), mit Jump-Host (`-J`), Authentifizierung
  über privaten Schlüssel, Unterstützung für Schlüssel-Passphrasen und konfigurierbaren zusätzlichen `ssh`-Argumenten.

### Verbindungsvorlagen
Wiederverwendbare Parametersätze (Protokoll, Port, Benutzername, Weiterleitung, Fenstermodus, Farbtiefe, SSH-
Fenstergröße). Jeder aufgelöste Parameter zeigt seinen aktuellen Wert **und woher er stammt**.

### Sitzungs-Arbeitsbereich
- Mehrere Sitzungen nebeneinander mit umschaltbaren geteilten Layouts, Maximierung pro Sitzung.
- Ein Feld „Asset öffnen“ in der Symbolleiste: Name oder Host eingeben und Return drücken oder aus der Liste auswählen.
- Separate SSH-Fenster werden unterstützt, wenn Sie sie außerhalb des Arbeitsbereichs bevorzugen.

### SFTP-Dateiübertragung
- Vollständiger Remote-Dateibrowser pro Asset: Verzeichnisse, Größen, Berechtigungen, Änderungszeiten.
- Hoch- und Herunterladen von Dateien oder ganzen Ordnern mit Fortsetzung (`reput` / `reget`).
- Ordner erstellen, Dateien oder leere Ordner löschen sowie Dateien per Drag-and-drop in den aktuellen Ordner ziehen.
- Verfügbar über die Symbolleiste der Sitzung und über das Kontextmenü des SSH-Terminals.

### Kontextmenü des SSH-Terminals
Kopieren, Einfügen, Alles auswählen und „Dateiübertragung“ direkt dort, wo Sie gerade tippen. Wenn ein Remote-Programm
die Maus erfasst (vim, tmux), wird der Rechtsklick wie erwartet an das Remote-Programm weitergegeben.

### Anmeldedaten
- Passwörter und Schlüssel-Passphrasen werden **nur** im macOS Keychain gespeichert, niemals in den Datendateien.
- Beim Löschen eines Assets oder Deaktivieren von „Passwort merken“ wird der Keychain-Eintrag entfernt.

### Import, Export und Synchronisierung
- Import aus CSV oder Excel (`.xlsx`) mit automatischer Spaltenzuordnung und Validierungsvorschau.
- Export nach CSV oder JSON mit Auswahl pro Feld; sensible Felder sind standardmäßig deaktiviert.
- Die Cloud-Synchronisierung lädt zuerst eine Vorschau und führt nur zusammen, was Sie auswählen — ausschließlich
  Assets und Vorlagen, niemals Passwörter.

### Erreichbarkeitsprüfung
TCP-Prüfung einzelner Assets, der Auswahl oder des gesamten Bestands, auf Anfrage oder per Timer.

### App-Sperre (Schutz-Passphrase)
- Optionale Passphrase-Sperre mit automatischer Sperre bei Inaktivität (1–60 Minuten).
- Passphrase-Hashing mit **PBKDF2-SHA256**, 100 000 Iterationen und einem zufälligen 128-Bit-Salt.
- Ein Wiederherstellungscode wird einmalig bei der Einrichtung ausgegeben (Crockford Base32, tolerant gegenüber `O/0`, `I/L/1`).
- Konfigurierbar: Nach 5 aufeinanderfolgenden Fehlversuchen die lokalen Daten automatisch löschen oder gesperrt
  bleiben und ein manuelles Löschen verlangen.

### Erscheinungsbild und Hilfe
- Design „System folgen“ / „Hell“ / „Dunkel“; Oberfläche auf Vereinfachtem Chinesisch und Englisch.
- Ein integriertes Handbuch zu VNC-Nutzung, Fehlerbehebung je Protokoll, Speicherorten der Daten und
  Datenschutz für Anmeldedaten.

## Systemanforderungen

| Element | Anforderung |
| --- | --- |
| macOS | 14.0 (Sonoma) oder neuer |
| RDP-Träger | Microsoft Windows App (aus dem App Store) |
| VNC-Träger | Integrierte Bildschirmfreigabe oder RealVNC / TigerVNC und ähnliche |
| Automatische RDP-Passworteingabe | Accessibility-Berechtigung für OpenNodeDesk |
| Selbst kompilieren | Xcode 16 oder neuer (Swift-6-Toolchain) |

## Installation

1. Laden Sie `OpenNodeDesk-<version>-macos.zip` von der Seite
   [Releases](https://github.com/OpenNodeSaas/OpenNodeDesk-macos/releases) herunter.
2. Entpacken Sie das Archiv und ziehen Sie `OpenNodeDesk.app` in den Ordner `/Applications`.
3. Der Build ist nicht von Apple notarisiert, daher kann Gatekeeper beim ersten Start warnen — klicken Sie mit der
   rechten Maustaste auf die App und wählen Sie **Öffnen**, oder erlauben Sie sie unter *Systemeinstellungen → Datenschutz & Sicherheit*.

## Selbst kompilieren

```bash
git clone https://github.com/OpenNodeSaas/OpenNodeDesk-macos.git
cd OpenNodeDesk-macos
make bundle   # release build + dist/OpenNodeDesk.app
make run      # build, bundle and launch
```

Nützliche Ziele: `make check` (kompilieren und Diagnosen anzeigen), `make clean` (`.build` und
`dist` verwerfen), `make reset` (lokale Daten aus `~/Library/Application Support/RemotePilot` entfernen).

## Projektstruktur

```
Sources/RemotePilot/
├── App/            Einstiegspunkt der App, globales Modell, Befehle und Menüs
├── Core/           SSH/SFTP, Keychain, Prüfung, Import/Export, Synchronisierung, Trägererkennung, RDP-Autofill
├── Design/         Design-Tokens und gemeinsame Komponenten
├── Localization/   Chinesische Quellstrings + englische String-Tabelle
├── Models/         Asset-, Vorlagen-, Einstellungs- und Laufzeitmodelle
├── Views/          Seitenleiste, Asset-Center, Arbeitsbereich, Sitzungen, Einstellungen, Hilfe, Dialoge
└── main.swift      Einstiegspunkt (dient zugleich als SSH_ASKPASS-Helfer)
Resources/          Info.plist und App-Symbol
docs/               Designdokumente und übersetzte READMEs
```

## Daten und Datenschutz

- Assets, Vorlagen und Einstellungen liegen in `~/Library/Application Support/RemotePilot`
  (`assets.json`, `settings.json`).
- Passwörter und Schlüssel-Passphrasen werden ausschließlich in den macOS Keychain geschrieben; sie sind niemals Teil eines
  Exports oder einer Synchronisierungsnutzlast. Ein Wechsel auf eine andere Maschine erfordert daher ihre erneute Eingabe.
- Die App funktioniert vollständig offline; der Cloud-Synchronisierungs-Endpunkt ist optional und wird vom Benutzer bereitgestellt.

## Hinweise und Einschränkungen

- Die Windows App von macOS kann nicht mehrere Sitzungen als Tabs in einem Fenster hosten; die Auswahl des
  Tab-Fenstermodus öffnet stattdessen ein normales Fenster. Verwenden Sie für mehrere Sitzungen den Sitzungs-Arbeitsbereich.
- Wenn kein RDP-Träger installiert ist, erklären Verbindungsversuche, was und wo installiert werden muss.
- Der interne Bundle-Identifier `com.remotepilot.macos` und das Datenverzeichnis
  `RemotePilot` bleiben seit der Umbenennung absichtlich unverändert, damit vorhandene Assets, Einstellungen und
  Keychain-Einträge nach einem Upgrade weiterhin funktionieren.

## Dokumentation

- [Produkt- & UX-Design](PRODUCT_UX_DESIGN.md)
- [Design-Delta](PRODUCT_UX_DESIGN_DELTA.md)
- [Passphrase-Sperre und automatische Sperre bei Inaktivität](../.trae/documents/保护口令与空闲自动锁定-macOS.md)
