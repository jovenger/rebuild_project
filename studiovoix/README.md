# StudioVoix

Logiciel d'enregistrement voix sur instru, inspiré de Samplitude, simplifié : on pose la voix principale,
le programme la recale, la traite selon le style, puis génère doublages, harmonies, backs, ad-libs et
ambiance sur des pistes séparées. Fonctionne entièrement en local ; l'IA (clé API) est facultative.

## Récupérer le programme (Windows)

Guide du matériel conseillé (micro, casque, branchements, illustrations) : à venir, voir `A_FAIRE.md`.

1. GitHub → dépôt `jovenger/rebuild_project` → onglet **Actions** → workflow **StudioVoix**.
2. Ouvrir la dernière exécution verte → section **Artifacts** → **StudioVoix-Windows** (zip).
3. Dézipper où on veut : `StudioVoix.exe` (application) + `studiovoix_cli.exe` (outil en ligne de commande).

Aucune installation. Les artefacts expirent au bout de 90 jours (relancer le workflow si besoin).

Export MP3 : poser `lame.exe` à côté de `StudioVoix.exe` (ou dans le PATH). Sans lui : WAV / FLAC.

## Premier lancement

- **Paramètres** → carte son : choisir l'entrée (ton micro ou ton interface) et la sortie (ton casque).
  Au premier lancement : entrée par défaut de Windows, et sortie sur le même appareil si elle existe
  (casque branché sur le micro USB ou sur l'interface). Mode **Windows Audio (Exclusive Mode)** en priorité,
  repli automatique « Low Latency Mode » puis « Windows Audio » si l'exclusif est refusé.
- Taille de tampon : la plus petite qui ne craque pas (128 ou 256 échantillons).
- Écoute : si le casque est branché sur le micro ou l'interface (retour direct), laisser l'écoute logicielle
  **désactivée** = zéro latence. Sinon, l'activer (latence = tampon de la carte son).
- **Calibrer la latence** : casque posé contre le micro, volume moyen ; 5 clics sont joués et mesurés.
  Sans calibrage, le recalage utilise la latence annoncée par le pilote.
  Décalage manuel ±200 ms si une prise sonne en avance / en retard.
- **Test du niveau du micro (5 s)** : chanter fort ; verdict trop fort / trop faible / correct.
  Réglage fin possible avec « Gain numérique d'entrée ».

## Utilisation

1. **Nouveau** → nom du projet.
2. **Instru...** → MP3/WAV. Analyse automatique : tempo, tonalité, structure (couplets / refrains).
3. **Style** (rap, trap, pop urbaine, R&B, drill, afro) dans la barre du haut.
4. **R** (ou REC) → compte à rebours → chanter → **R** pour arrêter.
   La prise est recalée de la latence puis traitée automatiquement (justesse, nettoyage, EQ, compression,
   de-esser, saturation, réverb, délai) selon le style.
5. Fenêtre de génération (après la prise) : cocher doublages (1-3), harmonies, backs mots clés, ad-libs,
   ambiance ; cases pré-cochées selon le style. Chaque élément sur sa piste.
6. Onglet **Voix IA** : curseurs (autotune, présence, espace, énergie, niveau…), assistant texte
   (« plus de reverb », « voix plus en avant »…), **Mon son** (mémorise tes réglages par style), référence.
7. Onglet **Mix & Master** : mix auto (voix calée sur l'instru + creux de l'instru sous la voix),
   cible de mastering : Spotify / YouTube (−14 LUFS), Apple (−16), TikTok (−14), Fort (−9), aucune ; crête −1 dBTP.
8. **Exporter** (Ctrl+E) : morceau complet, pistes séparées (stems) en option.

Autres fonctions : punch-in (zone sur la timeline), boucle, métronome, marqueurs, prises multiples avec
comping automatique (meilleure prise par phrase), copie d'un refrain sur les refrains identiques,
prompteur de paroles (onglet **Paroles**), sauvegarde auto toutes les 60 s, historique des versions,
récupération après plantage.

### Raccourcis

| Touche | Action |
|---|---|
| Espace | Lecture / pause |
| Début | Retour au début |
| R | Enregistrer / arrêter |
| M | Marqueur à la tête de lecture |
| Ctrl+S | Sauver |
| Ctrl+O | Ouvrir |
| Ctrl+Z / Ctrl+Y (ou Ctrl+Maj+Z) | Annuler / rétablir |
| Ctrl+E | Exporter |

## IA facultative

Sans clé, tout fonctionne (assistant texte local, diagnostic du mix par règles, recherche dans ta propre
bibliothèque de beats par tempo / tonalité / énergie).

Avec une clé (**Paramètres** → IA, clés masquées et stockées uniquement sur ce PC) :

- **Clé Claude (Anthropic)** : assistant avancé (demande libre → curseurs), diagnostic du mix détaillé,
  aide à l'écriture (→ onglet Paroles), styles sur mesure (rock, latino, etc.) enregistrés,
  description d'une instru d'après les paroles. Modèle par défaut : `claude-opus-5-5`.
- **Clé ElevenLabs Music** : création d'une instru d'après la description (style ou paroles), importée
  directement dans le projet.

Seul du texte est envoyé (paroles, réglages, mesures du mix). Aucun son n'est traité à distance.
Les appels sont facturés par le fournisseur sur ton compte.

## Fichiers

- Projet : `projet.svx` + `audio/` (prises, pistes générées) + `historique/` (versions) + `exports/`.
- Réglages : `%APPDATA%\StudioVoix\StudioVoix.settings`.
- Journaux : `%APPDATA%\StudioVoix\logs\studiovoix_AAAAMMJJ.log` (à joindre en cas de problème).

## Performances mesurées

Machine Linux 4 cœurs, voix de 119 s, outil en ligne de commande (traitement séquentiel) :

| Étape | Durée |
|---|---|
| Analyse de l'instru (tonalité + tempo + structure) | ~1,4 s |
| Traitement voix principale (après une prise) | ~4,2 s |
| Génération des 6 pistes (doublages, harmonie, backs, ad-libs, ambiance) | ~1,6 s |
| Traitement d'une piste générée | 2,2 à 3,1 s |
| Mix auto + mastering + export | ~3 s |
| Chaîne complète | ~35 s |

Dans l'application, les pistes sont traitées en parallèle (jusqu'à 3 en même temps) : temps réel
inférieur à la colonne « séquentiel ». Non mesuré sur Windows.

## Ligne de commande

```
studiovoix_cli test                                    tests automatiques
studiovoix_cli analyze <instru>                        tonalité, tempo, structure
studiovoix_cli remix <voix> [--instru f] [--style s] -o sortie.wav
studiovoix_cli song <instru> <voix> [--style s] [--target t] [--stems] -o dossier
studiovoix_cli master <mix> [--target t] -o sortie.wav
studiovoix_cli demo [--style s] [--bars N] -o dossier  chaîne complète sur signaux de synthèse
StudioVoix.exe --selftest <instru> <voix>              auto-test de l'application (code 0 = OK)
```

## Compiler soi-même

Prérequis : CMake ≥ 3.22, Visual Studio 2022 (C++20). JUCE 9.0.4 est téléchargé automatiquement.

```
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
ctest --test-dir build -C Release
```

## Licence

Basé sur JUCE 9 : usage personnel / open source sous AGPLv3. **Pour vendre le programme en code fermé,
une licence commerciale JUCE est nécessaire.**

## État

Vérifié automatiquement (CI Windows MSVC + Linux GCC) : compilation, 155 tests, auto-test de
l'application (import, analyse, rendu, génération, annuler/rétablir, export à −14,00 LUFS).

**Non vérifié** (pas de matériel ni de clé dans l'environnement de développement) :

- carte son réelle, latence réelle et recalage sur du vrai matériel ;
- qualité d'écoute des traitements et des pistes générées ;
- appels réels aux API Claude et ElevenLabs ;
- export MP3 avec `lame.exe` ;
- styles rock / latino : pas de profil intégré, seulement via les styles sur mesure (clé Claude).
