# OpenNodeDesk pour macOS

**Un hub de connexion à distance local-first pour macOS.** Conservez chaque serveur, compte et
paramètre de connexion dans une liste unique, recherchable, réutilisable et portable — et passez de
« j'ai besoin de cette machine » à une session active en trois étapes.

[English](../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Deutsch](README.de.md) · **[Français]** · [Español](README.es.md) · [Português](README.pt.md) · [Русский](README.ru.md) · [ไทย](README.th.md) · [Bahasa Indonesia](README.id.md) · [Tiếng Việt](README.vi.md)

Version actuelle : **v2.3.5**

---

## Présentation

OpenNodeDesk n'est pas un énième client de bureau à distance. L'affichage de l'écran distant, la
redirection des périphériques et l'audio/vidéo sont confiés au client le plus mature de la
plateforme — Microsoft Windows App pour RDP, le partage d'écran intégré pour VNC, et un terminal
intégré pour SSH. OpenNodeDesk se charge **des 90 % restants** : l'inventaire, les paramètres, les
identifiants, les rappels d'expiration et l'historique des connexions.

Principes de conception :

- **Connexion en trois secondes** — recherchez, appuyez sur Return, la session s'ouvre.
- **Local-first, fonctionne hors ligne, sans compte** — ouvrez, recherchez, modifiez et connectez-vous sans réseau.
- **Ne pas réinventer la roue** — l'affichage distant revient au meilleur client de la plateforme.
- **Paramètres explicables** — chaque valeur effective est étiquetée *personnalisé / modèle / défaut*.
- **Échecs explicables** — les erreurs s'accompagnent d'une cause et de suggestions concrètes, jamais d'un code brut.
- **Données portables** — exportation et importation en un clic ; migrez d'une machine à l'autre avec un seul fichier.
- **Priorité au clavier** — chaque action essentielle dispose d'un raccourci.

## Fonctionnalités

### Centre des actifs
- Dispositions en tableau et en grille ; recherche sur le nom, l'hôte, le groupe, le propriétaire et les notes.
- Favoris, connexions récentes et groupes repliables dans la barre latérale.
- Affichage/masquage par colonne et réorganisation, plus une taille de police globale pour la liste.
- Rappels d'expiration : les actifs expirant sous 30 jours (ou déjà expirés) sont signalés sur place.
- Détection des doublons par **hôte + port** à l'importation.

### RDP / SSH / VNC
- Ports par défaut par protocole (3389 / 22 / 5900), librement modifiables.
- **RDP** — génère un fichier `.rdp` temporaire pour Microsoft Windows App ; le mode fenêtre, la
  profondeur de couleur, la redirection de lecteur/audio/presse-papiers et la résolution sont
  entièrement configurables. Les binaires FreeRDP sont détectés et lancés directement avec le mot de
  passe enregistré, sans passer par l'invite d'identification.
  Le remplissage automatique du mot de passe dans la boîte de dialogue d'identification de
  Windows App utilise l'API Accessibility de macOS.
- **VNC** — utilise le partage d'écran intégré par défaut ; les visionneuses externes (RealVNC, TigerVNC…)
  peuvent être configurées avec un modèle d'arguments de lancement prenant en charge
  `{host} {port} {display} {user} {password}`.
- **SSH** — un véritable terminal intégré à l'application (SwiftTerm), avec hôte de rebond (`-J`),
  authentification par clé privée, prise en charge de la phrase secrète de la clé et arguments
  `ssh` supplémentaires configurables.

### Modèles de connexion
Ensembles de paramètres réutilisables (protocole, port, nom d'utilisateur, redirection, mode
fenêtre, profondeur de couleur, taille de fenêtre SSH). Chaque paramètre résolu affiche sa valeur
actuelle **et son origine**.

### Espace de travail des sessions
- Plusieurs sessions côte à côte avec dispositions fractionnées interchangeables, agrandissement par session.
- Une zone « ouvrir un actif » dans la barre d'outils : saisissez un nom ou un hôte et appuyez sur
  Return, ou choisissez dans la liste.
- Des fenêtres SSH séparées sont prises en charge lorsque vous les préférez hors de l'espace de travail.

### Transfert de fichiers SFTP
- Navigateur de fichiers distants complet par actif : répertoires, tailles, permissions, dates de modification.
- Envoi et téléchargement de fichiers ou de dossiers entiers, avec reprise (`reput` / `reget`).
- Créer des dossiers, supprimer des fichiers ou des dossiers vides, glisser-déposer des fichiers dans le dossier courant.
- Accessible depuis la barre d'outils de session et le menu contextuel du terminal SSH.

### Menu contextuel du terminal SSH
Copier, coller, tout sélectionner et « transfert de fichiers » directement là où vous tapez.
Lorsqu'un programme distant capture la souris (vim, tmux), le clic droit est transmis au programme
distant comme prévu.

### Identifiants
- Les mots de passe et les phrases secrètes des clés sont stockés **uniquement** dans le Keychain
  macOS, jamais dans les fichiers de données.
- Supprimer un actif ou décocher « se souvenir du mot de passe » supprime l'entrée du Keychain.

### Importation, exportation et synchronisation
- Importation depuis CSV ou Excel (`.xlsx`) avec mappage automatique des colonnes et aperçu de validation.
- Exportation en CSV ou JSON, avec sélection champ par champ ; les champs sensibles sont décochés par défaut.
- La synchronisation cloud récupère d'abord un aperçu et ne fusionne que ce que vous sélectionnez —
  uniquement les actifs et les modèles, jamais les mots de passe.

### Test de joignabilité
Sondage TCP d'un seul actif, de la sélection ou de tout l'inventaire, à la demande ou selon un minuteur.

### Verrouillage de l'application (phrase secrète de protection)
- Verrouillage facultatif par phrase secrète avec verrouillage automatique en cas d'inactivité (1 à 60 minutes).
- Hachage de la phrase secrète avec **PBKDF2-SHA256**, 100 000 itérations et un sel aléatoire de 128 bits.
- Un code de récupération est généré une seule fois à la configuration (Crockford Base32, tolérant `O/0`, `I/L/1`).
- Configurable : après 5 échecs consécutifs, effacer automatiquement les données locales, ou rester
  verrouillé et exiger un effacement manuel.

### Apparence et aide
- Thème Suivre le système / Clair / Sombre ; interface en chinois simplifié et en anglais.
- Un manuel d'aide intégré à l'application couvrant l'utilisation de VNC, le dépannage par
  protocole, les emplacements des données et la confidentialité des identifiants.

## Prérequis

| Élément | Exigence |
| --- | --- |
| macOS | 14.0 (Sonoma) ou version ultérieure |
| Client RDP | Microsoft Windows App (depuis l'App Store) |
| Client VNC | Partage d'écran intégré, ou RealVNC / TigerVNC et similaires |
| Remplissage automatique du mot de passe RDP | Autorisation Accessibility pour OpenNodeDesk |
| Compilation depuis les sources | Xcode 16 ou version ultérieure (chaîne d'outils Swift 6) |

## Installation

1. Téléchargez `OpenNodeDesk-<version>-macos.zip` depuis la page
   [Releases](https://github.com/OpenNodeSaas/OpenNodeDesk-macos/releases).
2. Décompressez l'archive et faites glisser `OpenNodeDesk.app` dans `/Applications`.
3. La version n'est pas notarisée par Apple, Gatekeeper peut donc afficher un avertissement au
   premier lancement — faites un clic droit sur l'application et choisissez **Ouvrir**, ou
   autorisez-la dans *Réglages Système → Confidentialité et sécurité*.

## Compilation depuis les sources

```bash
git clone https://github.com/OpenNodeSaas/OpenNodeDesk-macos.git
cd OpenNodeDesk-macos
make bundle   # release build + dist/OpenNodeDesk.app
make run      # build, bundle and launch
```

Cibles utiles : `make check` (compiler et afficher les diagnostics), `make clean` (supprimer `.build`
et `dist`), `make reset` (supprimer les données locales de `~/Library/Application Support/RemotePilot`).

## Arborescence du projet

```
Sources/RemotePilot/
├── App/            Point d'entrée de l'application, modèle global, commandes et menus
├── Core/           SSH/SFTP, Keychain, sondage, import/export, synchronisation, détection du client, remplissage automatique RDP
├── Design/         Jetons de design et composants partagés
├── Localization/   Chaînes sources en chinois + table de chaînes en anglais
├── Models/         Modèles d'actif, de modèle, de réglages et d'exécution
├── Views/          Barre latérale, centre des actifs, espace de travail, sessions, réglages, aide, boîtes de dialogue
└── main.swift      Point d'entrée (sert aussi d'assistant SSH_ASKPASS)
Resources/          Info.plist et icône de l'application
docs/              Documents de conception et README traduits
```

## Données et confidentialité

- Les actifs, les modèles et les réglages résident dans `~/Library/Application Support/RemotePilot`
  (`assets.json`, `settings.json`).
- Les mots de passe et les phrases secrètes des clés sont écrits uniquement dans le Keychain macOS ;
  ils ne font jamais partie d'une exportation ni d'une charge utile de synchronisation. Migrer vers
  une autre machine nécessite donc de les saisir à nouveau.
- L'application fonctionne entièrement hors ligne ; le point de terminaison de synchronisation cloud
  est facultatif et fourni par l'utilisateur.

## Remarques et limitations

- Le Windows App de macOS ne peut pas héberger plusieurs sessions sous forme d'onglets dans une même
  fenêtre ; choisir le mode fenêtre à onglets ouvre une fenêtre normale à la place. Utilisez l'espace
  de travail des sessions pour plusieurs sessions.
- Si aucun client RDP n'est installé, les tentatives de connexion indiquent quoi installer et où.
- L'identifiant de bundle interne `com.remotepilot.macos` et le répertoire de données
  `RemotePilot` restent volontairement inchangés depuis le renommage, afin que les actifs, les
  réglages et les entrées du Keychain existants continuent de fonctionner après la mise à niveau.

## Documentation

- [Conception produit et UX](PRODUCT_UX_DESIGN.md)
- [Delta de conception](PRODUCT_UX_DESIGN_DELTA.md)
- [Verrouillage par phrase secrète et verrouillage automatique en cas d'inactivité](../.trae/documents/保护口令与空闲自动锁定-macOS.md)
