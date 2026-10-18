# StudioVoix

Logiciel d'enregistrement voix sur instru, inspiré de Samplitude, simplifié : on pose la voix principale,
le programme la recale, la traite selon le style, puis génère doublages, harmonies, backs, ad-libs et
ambiance sur des pistes séparées. Fonctionne entièrement en local ; l'IA (clé API) est facultative.

## Récupérer le programme (Windows)

**Avant le premier enregistrement : [guide du matériel](docs/GUIDE_MATERIEL.md)** (micro, casque,
branchements pour zéro retard, placement, réglages Windows, dépannage).

1. GitHub → dépôt `jovenger/rebuild_project` → onglet **Actions** → workflow **StudioVoix**.
2. Ouvrir la dernière exécution verte → section **Artifacts** :
   - **StudioVoix-Setup** (conseillé) : installateur `StudioVoix-Setup-….exe`. Pas besoin des droits
     administrateur ; il crée les raccourcis (StudioVoix, guide du matériel, lisez-moi) et propose
     d'ouvrir le guide à la fin. Désinstallation par Windows (Applications) : projets, réglages et
     journaux sont conservés.
   - **StudioVoix-Windows** : version sans installation (`StudioVoix.exe` + `studiovoix_cli.exe` à dézipper).

Les artefacts expirent au bout de 90 jours (relancer le workflow si besoin).

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

1. **Nouveau** → nom du projet + **style** : tous les effets se règlent automatiquement (voir plus bas).
2. **Instru...** → MP3/WAV. Analyse automatique : tempo, tonalité, structure (couplets / refrains).
3. **Style** (18 styles, liste ci-dessous) : changeable à tout moment dans la barre du haut, toutes les pistes
   sont alors retraitées avec le nouveau pré-réglage.
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

## Pré-réglages par style

Choisir le style suffit : la voix principale est traitée avec la chaîne ci-dessous, sans rien régler.

Styles retenus = ceux qui dominent les classements actuels (pas de statistique publique des sessions
studio : les ventes et écoutes servent d'indicateur) : rap français (9 des 10 albums diamant de 2025 en
France, SNEP), pop, afro, latino et rock (plus forte progression aux États-Unis en 2025 avec le gospel,
Luminate), plus les musiques très enregistrées dans les home-studios francophones (dancehall / shatta,
zouk / kompa, amapiano, variété).

Rap / Hip-hop, Trap, Pop urbaine, R&B, Drill, Afro, Rock, Latino / Reggaeton, Rap mélodique,
Boom bap / Old school, Pop, Variété / Chanson, Dancehall / Shatta, Zouk / Kompa, Amapiano, Gospel / Soul,
Électro / House, Acoustique / Folk.
Les pistes générées reçoivent une variante adaptée du même pré-réglage : plus basses que la voix
principale, coupe-bas plus haut, compression plus forte ; doublages plus secs, harmonies et ad-libs avec
plus d'espace, ambiance presque entièrement en réverb. Les curseurs de l'onglet **Voix IA** partent de
ce réglage (milieu = réglage du style) ; **Mon son** le remplace par tes propres réglages pour ce style.
L'onglet **Voix IA** affiche les effets réellement appliqués à la piste sélectionnée.

Ordre de la chaîne : nettoyage → justesse (autotune) → EQ → compresseur → compresseur 2 → de-esser →
saturation → niveau → réverb + délai. Valeurs générées depuis le code (`studiovoix_cli presets`).

### Rap / Hip-hop

- Autotune : léger, naturel (15 %, vitesse 80 ms)
- Nettoyage : coupe-bas 90 Hz, bruit de fond -12 dB, respirations -8 dB, plosives (p, b)
- EQ : coupe-bas 90 Hz, bas-médium -2 dB à 300 Hz, présence +3 dB à 4 kHz, air +2 dB au-dessus de 12 kHz
- Compresseur : 4:1 au seuil -20 dB, attaque 5 ms, relâche 80 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -26 dB, attaque 20 ms, relâche 200 ms, détection RMS
- De-esser : 6.5 kHz, force 60 %, max -10 dB
- Saturation : +3 dB de chauffe, mélange 30 %
- Réverb : 8 %, taille 35 %, pré-délai 20 ms
- Délai : 10 %, 1/8 (croche), répétitions 20 %, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, backs sur les mots clés, ad-libs, ambiance

### Trap

- Autotune : effet marqué (100 %, vitesse 5 ms)
- Nettoyage : coupe-bas 100 Hz, bruit de fond -12 dB, respirations -8 dB, plosives (p, b)
- EQ : coupe-bas 100 Hz, bas-médium -3 dB à 300 Hz, présence +3 dB à 3.5 kHz, air +4 dB au-dessus de 12 kHz
- Compresseur : 6:1 au seuil -22 dB, attaque 3 ms, relâche 60 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 20 ms, relâche 150 ms, détection RMS
- De-esser : 6.5 kHz, force 70 %, max -10 dB
- Saturation : +6 dB de chauffe, mélange 40 %
- Réverb : 15 %, taille 50 %, pré-délai 25 ms
- Délai : 20 %, 1/4 (noire), répétitions 30 %, ping-pong, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, 1 harmonie, backs sur les mots clés, ad-libs, ambiance

### Pop urbaine

- Autotune : moyen (70 %, vitesse 20 ms)
- Nettoyage : coupe-bas 90 Hz, bruit de fond -12 dB, respirations -8 dB, plosives (p, b)
- EQ : coupe-bas 90 Hz, bas-médium -2 dB à 300 Hz, présence +2.5 dB à 3 kHz, air +4 dB au-dessus de 12 kHz
- Compresseur : 4:1 au seuil -20 dB, attaque 8 ms, relâche 100 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -26 dB, attaque 25 ms, relâche 200 ms, détection RMS
- De-esser : 6.5 kHz, force 70 %, max -10 dB
- Saturation : +3 dB de chauffe, mélange 25 %
- Réverb : 20 %, taille 55 %, pré-délai 30 ms
- Délai : 12 %, 1/4 (noire), répétitions 25 %
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 1 harmonie, backs sur les mots clés, ambiance

### R&B

- Autotune : moyen (50 %, vitesse 40 ms)
- Nettoyage : coupe-bas 80 Hz, bruit de fond -12 dB, respirations -8 dB, plosives (p, b)
- EQ : coupe-bas 80 Hz, graves +1.5 dB sous 200 Hz, bas-médium -1.5 dB à 350 Hz, présence +1.5 dB à 3 kHz, air +3 dB au-dessus de 11 kHz
- Compresseur : 3:1 au seuil -22 dB, attaque 15 ms, relâche 150 ms, parallèle 85 %, détection RMS
- Compresseur 2 (nivellement) : 1.8:1 au seuil -28 dB, attaque 30 ms, relâche 250 ms, détection RMS
- De-esser : 6 kHz, force 80 %, max -10 dB
- Saturation : +2 dB de chauffe, mélange 20 %
- Réverb : 30 %, taille 75 %, pré-délai 40 ms
- Délai : 15 %, 1/8 pointée, répétitions 30 %
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 2 harmonies, ad-libs, ambiance

### Drill

- Autotune : moyen (60 %, vitesse 15 ms)
- Nettoyage : coupe-bas 110 Hz, bruit de fond -12 dB, respirations -8 dB, plosives (p, b)
- EQ : coupe-bas 110 Hz, bas-médium -3 dB à 300 Hz, présence +4 dB à 2.5 kHz, air +2 dB au-dessus de 12 kHz
- Compresseur : 6:1 au seuil -20 dB, attaque 2 ms, relâche 50 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -26 dB, attaque 15 ms, relâche 150 ms, détection RMS
- De-esser : 6.5 kHz, force 60 %, max -10 dB
- Saturation : +7 dB de chauffe, mélange 45 %
- Réverb : 8 %, taille 30 %, pré-délai 15 ms
- Délai : 10 %, 1/8 (croche), répétitions 25 %, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, backs sur les mots clés, ad-libs

### Afro

- Autotune : moyen (80 %, vitesse 15 ms)
- Nettoyage : coupe-bas 90 Hz, bruit de fond -12 dB, respirations -8 dB, plosives (p, b)
- EQ : coupe-bas 90 Hz, bas-médium -2 dB à 300 Hz, présence +2.5 dB à 3.5 kHz, air +4 dB au-dessus de 12 kHz
- Compresseur : 4:1 au seuil -20 dB, attaque 8 ms, relâche 100 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -26 dB, attaque 25 ms, relâche 200 ms, détection RMS
- De-esser : 6.5 kHz, force 70 %, max -10 dB
- Saturation : +3 dB de chauffe, mélange 25 %
- Réverb : 25 %, taille 65 %, pré-délai 30 ms
- Délai : 20 %, 1/8 pointée, répétitions 35 %, ping-pong
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 2 harmonies, ad-libs, ambiance

### Rock

- Autotune : léger, naturel (10 %, vitesse 100 ms)
- Nettoyage : coupe-bas 90 Hz, bruit de fond -12 dB, respirations -8 dB, plosives (p, b)
- EQ : coupe-bas 90 Hz, bas-médium -2.5 dB à 350 Hz, présence +3 dB à 3 kHz, air +2 dB au-dessus de 10 kHz
- Compresseur : 5:1 au seuil -18 dB, attaque 10 ms, relâche 120 ms
- Compresseur 2 (nivellement) : 2.5:1 au seuil -26 dB, attaque 20 ms, relâche 200 ms, détection RMS
- De-esser : 6.5 kHz, force 60 %, max -10 dB
- Saturation : +8 dB de chauffe, mélange 35 %
- Réverb : 15 %, taille 50 %, pré-délai 30 ms
- Délai : 12 %, 1/16, répétitions 10 %
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, 1 harmonie, backs sur les mots clés

### Latino / Reggaeton

- Autotune : effet marqué (85 %, vitesse 10 ms)
- Nettoyage : coupe-bas 100 Hz, bruit de fond -12 dB, respirations -8 dB, plosives (p, b)
- EQ : coupe-bas 100 Hz, bas-médium -2.5 dB à 300 Hz, présence +3 dB à 3.5 kHz, air +4 dB au-dessus de 12 kHz
- Compresseur : 5:1 au seuil -22 dB, attaque 4 ms, relâche 70 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 20 ms, relâche 150 ms, détection RMS
- De-esser : 6.5 kHz, force 70 %, max -10 dB
- Saturation : +4 dB de chauffe, mélange 25 %
- Réverb : 18 %, taille 55 %, pré-délai 25 ms
- Délai : 18 %, 1/8 pointée, répétitions 30 %, ping-pong, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 2 harmonies, backs sur les mots clés, ad-libs, ambiance

### Rap mélodique

- Autotune : effet marqué (95 %, vitesse 8 ms)
- Nettoyage : coupe-bas 100 Hz, bruit de fond -12 dB, respirations -8 dB, plosives (p, b)
- EQ : coupe-bas 100 Hz, bas-médium -2.5 dB à 300 Hz, présence +3 dB à 3.5 kHz, air +4 dB au-dessus de 12 kHz
- Compresseur : 5:1 au seuil -22 dB, attaque 4 ms, relâche 70 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 20 ms, relâche 150 ms, détection RMS
- De-esser : 6.5 kHz, force 70 %, max -10 dB
- Saturation : +4 dB de chauffe, mélange 30 %
- Réverb : 18 %, taille 55 %, pré-délai 25 ms
- Délai : 18 %, 1/4 (noire), répétitions 30 %, ping-pong, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, 1 harmonie, backs sur les mots clés, ad-libs, ambiance

### Boom bap / Old school

- Autotune : désactivé
- Nettoyage : coupe-bas 80 Hz, bruit de fond -12 dB, respirations -8 dB, plosives (p, b)
- EQ : coupe-bas 80 Hz, graves +1 dB sous 200 Hz, bas-médium -2 dB à 350 Hz, présence +3.5 dB à 3 kHz, air +1 dB au-dessus de 12 kHz
- Compresseur : 4:1 au seuil -18 dB, attaque 10 ms, relâche 100 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -24 dB, attaque 20 ms, relâche 200 ms, détection RMS
- De-esser : 6.5 kHz, force 60 %, max -10 dB
- Saturation : +4 dB de chauffe, mélange 35 %
- Réverb : 6 %, taille 30 %, pré-délai 15 ms
- Délai : 8 %, 1/8 (croche), répétitions 15 %, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, backs sur les mots clés, ad-libs

### Pop

- Autotune : moyen (60 %, vitesse 25 ms)
- Nettoyage : coupe-bas 90 Hz, bruit de fond -12 dB, respirations -8 dB, plosives (p, b)
- EQ : coupe-bas 90 Hz, bas-médium -2 dB à 300 Hz, présence +2.5 dB à 3.5 kHz, air +4.5 dB au-dessus de 12 kHz
- Compresseur : 4:1 au seuil -20 dB, attaque 6 ms, relâche 90 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -26 dB, attaque 25 ms, relâche 200 ms, détection RMS
- De-esser : 7 kHz, force 75 %, max -10 dB
- Saturation : +2.5 dB de chauffe, mélange 20 %
- Réverb : 22 %, taille 60 %, pré-délai 35 ms
- Délai : 15 %, 1/4 (noire), répétitions 25 %
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, 2 harmonies, backs sur les mots clés, ambiance

### Variété / Chanson

- Autotune : léger, naturel (30 %, vitesse 50 ms)
- Nettoyage : coupe-bas 80 Hz, bruit de fond -12 dB, respirations -8 dB, plosives (p, b)
- EQ : coupe-bas 80 Hz, graves +1 dB sous 200 Hz, bas-médium -1.5 dB à 300 Hz, présence +2 dB à 3 kHz, air +2.5 dB au-dessus de 12 kHz
- Compresseur : 3:1 au seuil -20 dB, attaque 12 ms, relâche 140 ms, détection RMS
- Compresseur 2 (nivellement) : 1.8:1 au seuil -26 dB, attaque 30 ms, relâche 250 ms, détection RMS
- De-esser : 6.5 kHz, force 60 %, max -10 dB
- Saturation : +1.5 dB de chauffe, mélange 15 %
- Réverb : 25 %, taille 65 %, pré-délai 35 ms
- Délai : 8 %, 1/4 (noire), répétitions 20 %
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 1 harmonie, ambiance

### Dancehall / Shatta

- Autotune : effet marqué (90 %, vitesse 8 ms)
- Nettoyage : coupe-bas 110 Hz, bruit de fond -12 dB, respirations -8 dB, plosives (p, b)
- EQ : coupe-bas 110 Hz, bas-médium -3 dB à 300 Hz, présence +4 dB à 3 kHz, air +3 dB au-dessus de 12 kHz
- Compresseur : 6:1 au seuil -22 dB, attaque 3 ms, relâche 60 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 15 ms, relâche 150 ms, détection RMS
- De-esser : 6.5 kHz, force 65 %, max -10 dB
- Saturation : +6 dB de chauffe, mélange 40 %
- Réverb : 12 %, taille 45 %, pré-délai 20 ms
- Délai : 22 %, 1/8 (croche), répétitions 35 %, ping-pong, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 1 harmonie, backs sur les mots clés, ad-libs

### Zouk / Kompa

- Autotune : moyen (75 %, vitesse 20 ms)
- Nettoyage : coupe-bas 90 Hz, bruit de fond -12 dB, respirations -8 dB, plosives (p, b)
- EQ : coupe-bas 90 Hz, graves +1 dB sous 200 Hz, bas-médium -1.5 dB à 300 Hz, présence +2 dB à 3 kHz, air +3.5 dB au-dessus de 12 kHz
- Compresseur : 3.5:1 au seuil -22 dB, attaque 10 ms, relâche 120 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 25 ms, relâche 200 ms, détection RMS
- De-esser : 6.2 kHz, force 75 %, max -10 dB
- Saturation : +2 dB de chauffe, mélange 20 %
- Réverb : 28 %, taille 70 %, pré-délai 35 ms
- Délai : 15 %, 1/8 pointée, répétitions 30 %
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 2 harmonies, ad-libs, ambiance

### Amapiano

- Autotune : moyen (60 %, vitesse 20 ms)
- Nettoyage : coupe-bas 100 Hz, bruit de fond -12 dB, respirations -8 dB, plosives (p, b)
- EQ : coupe-bas 100 Hz, bas-médium -2 dB à 300 Hz, présence +2.5 dB à 3.5 kHz, air +3.5 dB au-dessus de 12 kHz
- Compresseur : 4:1 au seuil -20 dB, attaque 8 ms, relâche 110 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -26 dB, attaque 25 ms, relâche 200 ms, détection RMS
- De-esser : 6.5 kHz, force 70 %, max -10 dB
- Saturation : +2.5 dB de chauffe, mélange 20 %
- Réverb : 30 %, taille 75 %, pré-délai 40 ms
- Délai : 22 %, 1/8 pointée, répétitions 40 %, ping-pong
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 2 harmonies, ad-libs, ambiance

### Gospel / Soul

- Autotune : léger, naturel (20 %, vitesse 60 ms)
- Nettoyage : coupe-bas 80 Hz, bruit de fond -12 dB, respirations -8 dB, plosives (p, b)
- EQ : coupe-bas 80 Hz, graves +1.5 dB sous 200 Hz, bas-médium -1.5 dB à 350 Hz, présence +2 dB à 3 kHz, air +3 dB au-dessus de 12 kHz
- Compresseur : 3:1 au seuil -22 dB, attaque 15 ms, relâche 160 ms, parallèle 85 %, détection RMS
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 30 ms, relâche 250 ms, détection RMS
- De-esser : 6 kHz, force 70 %, max -10 dB
- Saturation : +2 dB de chauffe, mélange 20 %
- Réverb : 32 %, taille 80 %, pré-délai 45 ms
- Délai : 8 %, 1/8 pointée, répétitions 20 %
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 2 harmonies, ad-libs, ambiance

### Électro / House

- Autotune : moyen (80 %, vitesse 12 ms)
- Nettoyage : coupe-bas 120 Hz, bruit de fond -12 dB, respirations -8 dB, plosives (p, b)
- EQ : coupe-bas 120 Hz, bas-médium -3 dB à 300 Hz, présence +3 dB à 3.5 kHz, air +5 dB au-dessus de 12 kHz
- Compresseur : 5:1 au seuil -22 dB, attaque 3 ms, relâche 60 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 20 ms, relâche 150 ms, détection RMS
- De-esser : 7 kHz, force 75 %, max -10 dB
- Saturation : +3 dB de chauffe, mélange 25 %
- Réverb : 25 %, taille 70 %, pré-délai 40 ms
- Délai : 22 %, 1/8 pointée, répétitions 40 %, ping-pong
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, 1 harmonie, backs sur les mots clés, ambiance

### Acoustique / Folk

- Autotune : léger, naturel (15 %, vitesse 80 ms)
- Nettoyage : coupe-bas 75 Hz, bruit de fond -12 dB, respirations -8 dB, plosives (p, b)
- EQ : coupe-bas 75 Hz, graves +1 dB sous 200 Hz, bas-médium -2 dB à 300 Hz, présence +1.5 dB à 3 kHz, air +3 dB au-dessus de 12 kHz
- Compresseur : 2.5:1 au seuil -20 dB, attaque 15 ms, relâche 150 ms, détection RMS
- Compresseur 2 (nivellement) : 1.6:1 au seuil -26 dB, attaque 30 ms, relâche 250 ms, détection RMS
- De-esser : 6.5 kHz, force 60 %, max -10 dB
- Saturation : +1 dB de chauffe, mélange 10 %
- Réverb : 20 %, taille 55 %, pré-délai 30 ms
- Délai : 6 %, 1/16, répétitions 10 %
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 1 harmonie

## IA facultative

Sans clé, tout fonctionne (assistant texte local, diagnostic du mix par règles, recherche dans ta propre
bibliothèque de beats par tempo / tonalité / énergie).

Avec une clé (**Paramètres** → IA, clés masquées et stockées uniquement sur ce PC) :

- **Clé Claude (Anthropic)** : assistant avancé (demande libre → curseurs), diagnostic du mix détaillé,
  aide à l'écriture (→ onglet Paroles), styles sur mesure enregistrés (n'importe quel style décrit en texte),
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
| Chargement d'une instru de 3 min à 44,1 kHz (MP3/WAV) | ~0,45 s |
| Analyse de l'instru (tonalité + tempo + structure) | ~0,6 s |
| Traitement voix principale (après une prise) | ~2,8 s |
| Génération des 6 pistes (doublages, harmonie, backs, ad-libs, ambiance) | ~1,5 s |
| Traitement d'une piste générée | 1,8 à 2,4 s |
| Mix auto + mastering + export | ~2,7 s |
| Chaîne complète | ~27 s (46,5 s avant les optimisations) |

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
studiovoix_cli presets                                 pré-réglages de chaque style (Markdown)
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

Vérifié automatiquement (CI Windows MSVC + Linux GCC) :

- compilation, 558 vérifications de tests ;
- auto-test de l'application : import, analyse, rendu, génération, annuler/rétablir, export à −14,00 LUFS,
  prise annulée pendant son traitement, réouverture du projet pendant des calculs ;
- installateur Windows : installation silencieuse, tests lancés depuis le dossier installé, désinstallation.

**Non vérifié** (pas de matériel ni de clé dans l'environnement de développement) :

- carte son réelle, latence réelle et recalage sur du vrai matériel ;
- carte débranchée pendant une prise, changement de fréquence, récupération après un vrai plantage ;
- qualité d'écoute des traitements et des pistes générées ;
- appels réels aux API Claude et ElevenLabs ;
- export MP3 avec `lame.exe`.
