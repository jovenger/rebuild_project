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

**Deux programmes, un seul code** :
- **StudioVoix** (classique) : tout ce qui est décrit ici, sans rien à télécharger. Installateur
  `StudioVoix-Setup-…exe`, releases `studiovoix-build<N>`.
- **StudioVoix IA** : le même studio plus des briques d'intelligence artificielle **gratuites et locales**
  (nettoyage de voix DeepFilterNet, paroles reconnues et calées par whisper.cpp, séparation d'instru Demucs,
  mastering par référence), téléchargées à la demande dans le programme (modèles de 2 Mo à quelques centaines de Mo,
  calculs plus longs). Installateur `StudioVoixIA-Setup-…exe`, releases `studiovoix-ia-build<N>`, dossier et
  réglages séparés (`StudioVoix IA`) : les deux programmes s'installent côte à côte et ouvrent les mêmes projets.
  Chaque programme ne se met à jour que vers les versions de son édition.

  Dans StudioVoix IA, l'onglet **IA locale** liste les briques (DeepFilterNet, modèle Whisper « base »…) avec leur
  état et leur poids ; **Installer** les télécharge dans `%APPDATA%\StudioVoix IA\outils` (fichier temporaire,
  taille et empreinte SHA-256 vérifiées quand elle est connue, journal détaillé), **Supprimer** les retire. Les
  empreintes sont relevées par la CI (`studiovoix_cli outils-empreintes`) puis épinglées dans le programme.

  **Nettoyage IA** (StudioVoix IA, onglet Voix IA) : une fois DeepFilterNet installé, chaque piste voix traitée par un
  style passe d'abord dans le réseau (souffle, bruit de pièce, ronflement), puis dans la chaîne du style ; résultat mis
  en cache dans `audio/cache_ia` du projet (empreinte du contenu), ligne « Nettoyage IA : … » dans le rapport de la
  piste ; case à décocher par piste. Exige 48 kHz (fréquence du projet).

Export MP3 : poser `lame.exe` à côté de `StudioVoix.exe` (ou dans le PATH). Sans lui : WAV / FLAC.

## Premier lancement

**Écran d'accueil** : à l'ouverture, de grandes cartes — « Nouveau projet », « Ouvrir un projet… », « Reprendre
« dernier projet » » — puis les projets récents du dossier Projets (date, nombre de pistes, style). Échap ou
« Reprendre » ramène au studio ; le bouton **Accueil** (en bas à gauche) le rouvre. L'habillage (fond sombre,
accent violet → rose, cartes arrondies) est purement visuel : aucun calcul audio ne passe par lui.

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
3. **Style** (33 styles rangés par famille, liste ci-dessous) : changeable à tout moment dans la barre du haut, toutes les pistes
   sont alors retraitées avec le nouveau pré-réglage.
4. **Rond rouge** à gauche d'une piste = piste **armée** : le micro enregistre sur elle et sur rien d'autre.
   Cliquer sur une piste l'arme ; le rond permet aussi d'armer / désarmer à la main.
   **R** (ou REC) → compte à rebours → chanter → **R** pour arrêter.
   La prise est recalée de la latence puis traitée automatiquement (justesse, nettoyage, EQ, compression,
   de-esser, saturation, réverb, délai) selon le style.
5. Fenêtre de génération (après la prise) : cocher doublages (1-3), harmonies, backs mots clés, ad-libs,
   ambiance ; cases pré-cochées selon le style. Chaque élément sur sa piste.
6. Onglet **Voix IA** : curseurs (autotune, présence, espace, énergie, niveau…), assistant texte
   (« plus de reverb », « voix plus en avant »…), **Mon son** (mémorise tes réglages par style), référence.
7. Onglet **Mix & Master** : mix auto (voix calée sur l'instru + creux de l'instru sous la voix),
   cible de mastering : Spotify / YouTube (−14 LUFS), Apple (−16), TikTok (−14), Fort (−9), aucune ; crête −1 dBTP.
8. **Exporter** (Ctrl+E) : morceau complet, pistes séparées (stems) en option.

**Ajouter une piste soi-même** : clic droit sur la timeline (sur une piste ou dans la zone vide) →
**Nouvelle piste...** → type : voix principale, back, doublage, harmonie, ad-libs, ambiance / chœurs ou
instrument (guitare, clavier, basse…). Nom proposé automatiquement (« Back 1 », « Back 2 »…). Les effets se
règlent selon le type et le style du projet (un back est plus bas et plus serré que la voix principale, une
harmonie plus large avec plus de réverb, un instrument sans autotune ni de-esser…). La nouvelle piste est
sélectionnée, armée et **brute** (aucun effet, curseurs à 0) : il n'y a plus qu'à appuyer sur R. Le type se change
ensuite dans l'onglet **Voix IA**. Choisir un style dans la barre du haut traite toutes les voix encore brutes ;
« Effets » dans l'onglet Voix IA règle chaque piste à part (brut, style du projet ou un autre style).

**Glisser-déposer** : faire glisser un ou plusieurs fichiers audio (MP3, WAV, FLAC, AIFF, OGG) dans la fenêtre
crée une nouvelle piste par fichier, calée au début du morceau (le bloc se déplace ensuite en le glissant sur la
timeline, Ctrl+Z pour annuler). Le programme
**reconnaît le contenu** (voix seule ou musique : hauteur de voix, largeur stéréo, poids des graves) et le nom du
fichier (« instru », « beat », « voix », « guitare »…) pour proposer le type ; il se change dans la fenêtre d'import.

**Aucun effet par défaut** : toute piste (nouvelle, enregistrée au micro, importée ou glissée) reste telle quelle :
aucun effet, ni réverb, ni compression, ni mix auto. Clic sur la piste → le panneau **Voix IA** s'ouvre à droite sur
« Style : Aucun », tous les curseurs à 0. Choisir un style dans cette liste applique à **cette piste** tous les
réglages du style (autotune, EQ, compresseurs, de-esser, saturation, réverb, délai) ; chaque piste a son propre
style. Pour l'instru : « Brute » ou « Creux sous la voix (mix auto) ». Le style de la barre du haut sert aux pistes
générées, au mastering et aux propositions, pas aux pistes brutes.

**Ingénieur du son automatique** (son propre, sans effet de style) : bouton **Ingénieur du son** dans la barre du
haut (toutes les pistes, instru comprise), ou « Style : Correction automatique » sur une piste. Le programme mesure les défauts de chaque piste enregistrée ou
importée (niveau trop bas ou trop fort, saturation, composante continue, bruit de fond, boue dans le bas-médium,
dureté, sifflantes, justesse approximative) et les corrige : niveau remis à −14 dB, bruit réduit dans les silences,
EQ corrective dosée sur la mesure, de-esser dosé, justesse ramenée doucement vers la gamme (voix seule uniquement),
puis mix auto. Le panneau Voix IA affiche les défauts constatés et les corrections. Annulable (Ctrl+Z).

**Niveau régulier et passages qui montent** : un **niveleur** (fader suivi, comme un « vocal rider ») mesure le niveau
toutes les 100 ms (fenêtre 400 ms) et remonte les passages trop bas, baisse les trop forts (±4 dB dans les styles,
jusqu'à ±8 dB en correction) ; un passage qui **monte en flèche** (plus de 9 dB au-dessus du niveau médian) est
horodaté dans le rapport (« à 1:32, +14 dB ») et rabaissé jusqu'à 12–18 dB. Un **suppresseur de résonances**
rabaisse une bande (tiers d'octave) seulement quand elle dépasse à la fois ses voisines et son propre niveau habituel
(dureté par moments), graves protégés ; les harmoniques fixes d'une voix tenue ne sont pas touchées.

**Correction de l'instru** : « Style : Correction automatique » sur la piste instru (ou le bouton Ingénieur du son) :
analyse sur la somme mono, réparation **stéréo liée** (image inchangée) : dé-écrêtage, coupe-bas, débruitage, niveleur,
EQ corrective, résonances, compression liée, niveau −14 dB, limiteur −1 dBTP ; puis creux sous la voix (mix auto).

**Orchestre** (équilibre automatique de toutes les pistes) : après chaque rendu, la sonie de chaque piste est mesurée
et ramenée à sa place par rapport à la voix principale selon son rôle (doublage −9 LU, backs −7, harmonies −9,
ad-libs −9, ambiance −14, instrument enregistré −4), bornée à −8 / +6 dB. Une piste brute garde son son (aucun effet)
mais son niveau est géré aussi, comme l'équilibre voix / instru : le niveau n'est pas un effet.
Le panneau Voix IA affiche « Orchestre : gain auto ± x dB », la barre du haut la sonie du mixage (« Mix −14,0 LUFS »).

**Bus voix** (panneau Mix, activé par défaut) : toutes les voix (principale, doublages, backs, ad-libs, harmonies,
ambiance) sont additionnées à part puis passent **ensemble** dans un même compresseur « colle » (RMS lié, seuil −20 dB,
2:1, genou 6 dB, attaque 30 ms, relâche 200 ms, 1 à 4 dB de réduction), comme sur une console : les voix sonnent comme un
seul ensemble au lieu de pistes posées côte à côte. Le rattrapage de gain égale la réduction moyenne mesurée par le mix
auto, donc l'équilibre voix / instru ne bouge pas. Le même compresseur sert à la lecture (bloc par bloc, état conservé) et
à l'export ; les pistes séparées (stems) n'y passent pas.

**Alertes** : après chaque rendu, chaque piste **écrêtée à la source** (crête au-dessus de −0,2 dBFS avant traitement),
qui **sature après traitement** (au-delà de +1 dBFS), **monte en flèche** ou est **plus forte que la voix
principale** est signalée en orange dans son en-tête et dans la barre d'état (« Ingénieur du son : 2 alertes — … »),
avec les horodatages. Si plus d'un quart des **notes chantées sont hors de la gamme du projet** (mesuré avant
l'autotune), l'autotune **suit la gamme de la voix** (celle qui contient le plus de notes chantées, affichée dans le
panneau : « Gamme adaptée à la voix : Sol mineur ») ; si aucune gamme ne convient, correction note par note et alerte. Chaque piste traitée finit sous
−1 dBTP (limiteur de sécurité, transparent tant que rien ne dépasse).

**Pas de décalage** : après chaque rendu, le décalage temporel entre le son brut et le son traité est mesuré (corrélation
des enveloppes) ; au-delà de 15 ms, alerte sur la piste. Les doublages générés sont des doublages serrés (6–16 ms de
retard variable, −9 LU) : ils épaississent la voix sans s'entendre comme une seconde voix décalée.

**Vumètres** : crête jouée par piste (barre dans l'en-tête, retombée douce) ; crête de sortie et sonie du mixage dans
la barre du haut.

**Pas de trou en pleine note** : la porte ne se ferme jamais tant que la voix est voisée (maintien 250 ms, expandeur 2:1,
fermeture lente) et le débruitage est limité à 6 dB sans sur-soustraction sur les trames chantées. Vérifié par la
commande `studiovoix_cli artefacts` (voir plus bas) : 0 trou sur les 34 chaînes des deux voix de démonstration, contre 7 à
27 trous de −8 à −10 dB auparavant (les compresseurs les masquaient en partie).

**Son polyphonique** (chœurs à plusieurs voix, piano, morceau entier) : la correction de justesse est coupée
automatiquement, qu'on choisisse un style ou la correction — elle ferait des « vagues » sur ce type de son.

**Chaîne visible de la piste** (onglet Voix IA, piste voix traitée par un style) : onze cases dans l'ordre de la
chaîne — Nettoyage, Niveleur, Autotune, EQ, Résonances, Compresseur, De-esser, Compresseur 2, Saturation, Réverb,
Délai — choisies et réglées **automatiquement par le style** (vert = active avec son réglage en clair, gris = éteinte
par le style, orange = contournée, bleu = réglée à la main). Clic sur une case → la fenêtre de curseurs de l'effet,
pré-remplie avec les valeurs du style (la piste est recalculée à la fermeture) ; clic droit → « Contourner cette
étape », « Revenir au réglage du style ». Ces réglages s'appliquent par-dessus le style, sont sauvegardés dans le
projet et annulables ; « Réglages du style » les efface tous. Les inserts (ci-dessous) viennent après la chaîne.

**Effets en plus sur une piste** : onglet Voix IA → « + Effet / plugin… ». Le menu propose d'abord les
**effets intégrés** (rien à installer) : égaliseur (coupe-bas, graves, bas-médium, présence, air, coupe-haut),
compresseur (seuil, ratio, attaque, relâche, gain, mélange parallèle), de-esser, saturation, réverb, délai calé
au tempo (noire, croche, croche pointée, ping-pong), porte / débruiteur, limiteur (plafond en dBTP) et largeur
stéréo ; clic sur le nom → une fenêtre de curseurs, la piste est recalculée à la fermeture. Puis les **plugins
VST3** connus (Paramètres → « Rechercher les plugins VST3 » : dossiers standard de Windows + un dossier au choix).
Les effets s'appliquent après les effets du style (ou sur le son brut), dans l'ordre de la liste ; B = contourner,
X = retirer ; réglages sauvegardés dans le projet. La latence déclarée par un VST3 est compensée ; les plugins
qui plantent à la recherche sont mis de côté au lancement suivant.

**Son propre** : le nettoyage comprend un débruitage spectral (profil de bruit appris sur les silences : souffle,
ronflement, bruit de pièce) et un dé-écrêtage (passages saturés reconstruits).

**Nettoyage piste par piste, chaque piste étant un instrument différent** : la correction automatique reconnaît
le type de la piste et adapte ses réglages. Voix : coupe-bas 80 Hz, anti-plosives, respirations, de-esser dosé,
justesse douce (voix seule). Basse / 808 : coupe-bas 35 Hz, compression 3:1 lente, pas de porte (les tenues
restent), débruitage léger. Batterie / percussions : coupe-bas 40 Hz, compression 2:1 avec attaque lente (les
coups restent nets), pas de porte. Clavier / guitare / synthé : coupe-bas 60 Hz, compression 3:1 (5 ms / 50 ms).
Dans tous les cas : niveau remis à −14 dB, composante continue retirée, écrêtage réparé, boue (250–450 Hz) et
dureté (2–5 kHz) coupées seulement si elles sont mesurées, jamais d'autotune sur un son polyphonique.
Le panneau Voix IA indique l'instrument reconnu et les corrections faites.

**Plusieurs pistes à la fois** : Ctrl enfoncé + clic sur chaque piste (elles restent sélectionnées), puis clic droit →
« Supprimer les N pistes » (ou touche Suppr). Ctrl+Z revient en arrière.

**Déplacer un bloc audio** : glisser la prise ou le fichier sur sa piste ; il suit la souris et se place au
relâchement. Il ne peut jamais dépasser le début (0 s) et s'aimante au début et aux temps de la grille quand il
en est proche ; clic droit → « Caler au début du morceau » le remet exactement à 0 s.

**Sélectionner une zone** : glisser la souris dans le vide d'une piste (ou Ctrl+glisser, même sur un bloc) ; la zone
s'aimante aux bords des blocs. Puis **S** la coupe aux deux bords, **Suppr** l'efface (les blocs voisins ne bougent
pas), **Ctrl+C / Ctrl+X** la copient / coupent, **Ctrl+V** la colle à la tête de lecture sur la piste sélectionnée (ce
qui se trouvait sous la zone collée est remplacé ; les fichiers audio ne sont jamais modifiés). Un clic sur un bloc le
sélectionne (cadre blanc) : Suppr, Ctrl+C / X agissent alors sur ce bloc. Un clic sans glisser place la tête de lecture.

**Ordre des pistes** : glisser l'en-tête d'une piste vers le haut ou le bas (ou clic droit → « Monter / Descendre la
piste »). Ctrl+Z revient en arrière.

**Éditer un bloc** (prise enregistrée ou fichier importé sur une piste voix) : tirer un **bord** du bloc le rogne
(jamais au-delà du fichier, 50 ms au minimum) ; les deux **carrés blancs** en haut du bloc (piste sélectionnée) sont
les poignées de **fondu d'entrée / de sortie** (courbe en cosinus, dessinées en triangle) ; clic droit sur le bloc →
« Couper le bloc ici », « Couper à la tête de lecture », « Fondus de 10 ms », « Retirer les fondus », « Supprimer le
bloc ». Couper donne deux blocs indépendants (même fichier) qu'on déplace, rogne ou supprime séparément. Toutes ces
actions s'annulent (Ctrl+Z) et la piste est rendue à nouveau.

Autres fonctions : punch-in (zone sur la timeline), boucle, métronome, marqueurs, prises multiples avec
comping automatique (meilleure prise par phrase), copie d'un refrain sur les refrains identiques,
prompteur de paroles (onglet **Paroles**), sauvegarde auto toutes les 60 s, historique des versions,
récupération après plantage.

**Taille des pistes** : tirer le bord droit de la colonne des en-têtes (largeur, 150–600 px) ou le bord bas d'une
piste dans cette colonne (hauteur de toutes les pistes, 40–260 px) ; mémorisé d'une session à l'autre.

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
| S | Couper le(s) bloc(s) à la tête de lecture (ou aux deux bords de la zone sélectionnée) |
| Suppr | Effacer la zone ou le bloc sélectionné (sinon : supprimer la piste) |
| Ctrl+C / Ctrl+X / Ctrl+V | Copier / couper la zone ou le bloc sélectionné ; coller à la tête de lecture sur la piste sélectionnée |
| Échap | Annuler la sélection |

## Pré-réglages par style

Choisir le style suffit : la voix principale est traitée avec la chaîne ci-dessous, sans rien régler.

Styles retenus = ceux qui dominent les classements actuels (pas de statistique publique des sessions
studio : les ventes et écoutes servent d'indicateur) : rap français (9 des 10 albums diamant de 2025 en
France, SNEP), pop, afro, latino et rock (plus forte progression aux États-Unis en 2025 avec le gospel,
Luminate), plus les sous-genres de rap et les musiques très enregistrés en ce moment dans les
home-studios francophones.

- **Rap** : Rap / Hip-hop, Rap conscient, Rap hardcore, Boom bap / Old school, Trap, Drill, Rap mélodique,
  Cloud rap, Rage, Plugg / Pluggnb, Emo rap, Afro trap, Rap lo-fi / Chill, Phonk, Jersey club
- **Chant / Pop / R&B** : Pop urbaine, Pop, R&B, Gospel / Soul, Variété / Chanson, Raï / Raï'n'B, Rock,
  Acoustique / Folk, Country
- **Afro / Caraïbes / Latino** : Afro, Amapiano, Dancehall / Shatta, Bouyon, Zouk / Kompa,
  Latino / Reggaeton, Funk brésilien
- **Électro** : Électro / House, Afro house
Les pistes générées reçoivent une variante adaptée du même pré-réglage : plus basses que la voix
principale, coupe-bas plus haut, compression plus forte ; doublages plus secs, harmonies et ad-libs avec
plus d'espace, ambiance presque entièrement en réverb. Les curseurs de l'onglet **Voix IA** affichent les
**positions réelles du style** (autotune = quantité de correction, présence = EQ, espace = réverb + délai, énergie =
compression + saturation) : Rap conscient ≈ autotune 0,10, Trap ≈ 0,80, R&B plus d'espace… Déplacer un curseur
s'écarte d'autant du style ; double-clic = position du style ; **Mon son** mémorise tes positions pour ce style.
L'onglet **Voix IA** affiche les effets réellement appliqués à la piste sélectionnée.

Ordre de la chaîne : nettoyage → justesse (autotune) → EQ → compresseur (rapide, 4–7 dB) → de-esser →
compresseur 2 (nivellement doux) → saturation → niveau → réverb + délai. Valeurs générées depuis le code
(`studiovoix_cli presets`).

Les réglages suivent les pratiques publiées des studios (vérifiées en octobre 2026) : gain → EQ soustractive
(coupe-bas 80–100 Hz, −2 à −4 dB vers 250–450 Hz) → compresseur rapide 4:1 qui prend 4 à 7 dB → de-esser
7–10 kHz (2 à 6 dB max) → second compresseur doux (2 à 3 dB) → EQ de tonalité (+2 à +3 dB vers 3–5 kHz, air
au-dessus de 10 kHz) → envois ; retour de réverb filtré 200–250 Hz / 8–10 kHz ; délai à la croche ou à la noire.
Instruments : basse coupe-bas ~40 Hz et bas-médium nettoyé si boueux ; kick 60–100 Hz gardé, 200 Hz coupé,
attaque 3–5 kHz ; piano 3:1, attaque 5 ms, relâche 50 ms ; guitares coupées sous 100 Hz, présence 1–3 kHz,
dureté 3–6 kHz réduite. Autotune par style (Ghostnote, Antares) : hard-tune 0–5 ms / 100 % (trap, ad-libs), mélodique
10–20 ms, pop serré 20–50 ms, nettoyage transparent 40–80 ms / 70–90 % (rap parlé, rap conscient), afrobeats 10–30 ms
avec humanize bas ; R&B (Rys Up) : coupe-bas 60–80 Hz, 2–3:1, de-esser 3–5 dB, réverb 1,8–3 s, délai filtré 4–6 kHz.
Sources : Ghostnote (chaîne rap et autotune par style), Antares (afrobeats), Rys Up Audio (R&B, hip-hop), Baywood Audio
(réglages par genre), 20dollarbeats (chaîne rap), Violet Recording (compression voix), MixingGPT
(ordre des traitements), Music Guy Mixing (de-esser et EQ voix), Universal Audio (réverb et délai sur la voix).

**Famille Rap**

### Rap / Hip-hop

- Autotune : moyen (75 %, vitesse 60 ms)
- Nettoyage : coupe-bas 90 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 90 Hz, bas-médium -2 dB à 300 Hz, présence +3 dB à 4 kHz, air +2 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 4:1 au seuil -20 dB, attaque 5 ms, relâche 80 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -26 dB, attaque 20 ms, relâche 200 ms, détection RMS
- De-esser : 6 kHz, force 60 %, max -6 dB
- Saturation : +3 dB de chauffe, mélange 30 %
- Réverb : 8 %, taille 35 %, pré-délai 25 ms
- Délai : 10 %, 1/8 (croche), répétitions 20 %, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, backs sur les mots clés, ad-libs, ambiance

### Rap conscient

- Autotune : moyen (70 %, vitesse 80 ms)
- Nettoyage : coupe-bas 85 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 85 Hz, graves +0.5 dB sous 200 Hz, bas-médium -2 dB à 300 Hz, présence +3.5 dB à 3 kHz, air +1.5 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 4:1 au seuil -20 dB, attaque 8 ms, relâche 100 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -26 dB, attaque 20 ms, relâche 200 ms, détection RMS
- De-esser : 7 kHz, force 60 %, max -6 dB
- Saturation : +2 dB de chauffe, mélange 20 %
- Réverb : 7 %, taille 35 %, pré-délai 20 ms
- Délai : 6 %, 1/8 (croche), répétitions 15 %, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, backs sur les mots clés

### Rap hardcore

- Autotune : moyen (60 %, vitesse 70 ms)
- Nettoyage : coupe-bas 110 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 110 Hz, bas-médium -3.5 dB à 300 Hz, présence +4.5 dB à 2.5 kHz, air +2 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 8:1 au seuil -16 dB, attaque 1 ms, relâche 40 ms
- Compresseur 2 (nivellement) : 3:1 au seuil -24 dB, attaque 10 ms, relâche 120 ms, détection RMS
- De-esser : 7 kHz, force 60 %, max -6 dB
- Saturation : +9 dB de chauffe, mélange 50 %
- Réverb : 5 %, taille 25 %, pré-délai 10 ms
- Délai : 8 %, 1/8 (croche), répétitions 15 %, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, backs sur les mots clés, ad-libs

### Boom bap / Old school

- Autotune : moyen (50 %, vitesse 100 ms)
- Nettoyage : coupe-bas 80 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 80 Hz, graves +1 dB sous 200 Hz, bas-médium -2 dB à 350 Hz, présence +3.5 dB à 3 kHz, air +1 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 4:1 au seuil -18 dB, attaque 10 ms, relâche 100 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -24 dB, attaque 20 ms, relâche 200 ms, détection RMS
- De-esser : 7 kHz, force 60 %, max -6 dB
- Saturation : +4 dB de chauffe, mélange 35 %
- Réverb : 6 %, taille 30 %, pré-délai 15 ms
- Délai : 8 %, 1/8 (croche), répétitions 15 %, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, backs sur les mots clés, ad-libs

### Trap

- Autotune : effet marqué (100 %, vitesse 2 ms)
- Nettoyage : coupe-bas 100 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 100 Hz, bas-médium -3 dB à 300 Hz, présence +3 dB à 3.5 kHz, air +4 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 6:1 au seuil -22 dB, attaque 3 ms, relâche 60 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 20 ms, relâche 150 ms, détection RMS
- De-esser : 7 kHz, force 70 %, max -6 dB
- Saturation : +6 dB de chauffe, mélange 40 %
- Réverb : 15 %, taille 50 %, pré-délai 25 ms
- Délai : 20 %, 1/4 (noire), répétitions 30 %, ping-pong, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, 1 harmonie, backs sur les mots clés, ad-libs, ambiance

### Drill

- Autotune : effet marqué (85 %, vitesse 12 ms)
- Nettoyage : coupe-bas 110 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 110 Hz, bas-médium -3 dB à 300 Hz, présence +4 dB à 2.5 kHz, air +2 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 6:1 au seuil -20 dB, attaque 2 ms, relâche 50 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -26 dB, attaque 15 ms, relâche 150 ms, détection RMS
- De-esser : 7 kHz, force 60 %, max -6 dB
- Saturation : +7 dB de chauffe, mélange 45 %
- Réverb : 8 %, taille 30 %, pré-délai 15 ms
- Délai : 10 %, 1/8 (croche), répétitions 25 %, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, backs sur les mots clés, ad-libs

### Rap mélodique

- Autotune : effet marqué (95 %, vitesse 8 ms)
- Nettoyage : coupe-bas 100 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 100 Hz, bas-médium -2.5 dB à 300 Hz, présence +3 dB à 3.5 kHz, air +4 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 5:1 au seuil -22 dB, attaque 4 ms, relâche 70 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 20 ms, relâche 150 ms, détection RMS
- De-esser : 7 kHz, force 70 %, max -6 dB
- Saturation : +4 dB de chauffe, mélange 30 %
- Réverb : 18 %, taille 55 %, pré-délai 25 ms
- Délai : 18 %, 1/4 (noire), répétitions 30 %, ping-pong, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, 1 harmonie, backs sur les mots clés, ad-libs, ambiance

### Cloud rap

- Autotune : effet marqué (85 %, vitesse 15 ms)
- Nettoyage : coupe-bas 110 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 110 Hz, bas-médium -2.5 dB à 300 Hz, présence +2 dB à 3.5 kHz, air +5 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 4:1 au seuil -22 dB, attaque 6 ms, relâche 100 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 25 ms, relâche 200 ms, détection RMS
- De-esser : 7 kHz, force 75 %, max -6 dB
- Saturation : +2 dB de chauffe, mélange 20 %
- Réverb : 38 %, taille 85 %, pré-délai 50 ms
- Délai : 25 %, 1/8 pointée, répétitions 45 %, ping-pong
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 1 harmonie, ad-libs, ambiance

### Rage

- Autotune : effet marqué (100 %, vitesse 3 ms)
- Nettoyage : coupe-bas 120 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 120 Hz, bas-médium -3 dB à 300 Hz, présence +3 dB à 3 kHz, air +4 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 8:1 au seuil -24 dB, attaque 1 ms, relâche 40 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 15 ms, relâche 150 ms, détection RMS
- De-esser : 7 kHz, force 70 %, max -6 dB
- Saturation : +10 dB de chauffe, mélange 55 %
- Réverb : 12 %, taille 50 %, pré-délai 20 ms
- Délai : 18 %, 1/8 (croche), répétitions 30 %, ping-pong, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, backs sur les mots clés, ad-libs

### Plugg / Pluggnb

- Autotune : effet marqué (90 %, vitesse 10 ms)
- Nettoyage : coupe-bas 100 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 100 Hz, bas-médium -2 dB à 300 Hz, présence +2.5 dB à 3.5 kHz, air +4 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 4:1 au seuil -22 dB, attaque 5 ms, relâche 80 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 20 ms, relâche 150 ms, détection RMS
- De-esser : 7 kHz, force 70 %, max -6 dB
- Saturation : +2.5 dB de chauffe, mélange 20 %
- Réverb : 25 %, taille 65 %, pré-délai 30 ms
- Délai : 18 %, 1/4 (noire), répétitions 30 %, ping-pong
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 1 harmonie, backs sur les mots clés, ad-libs, ambiance

### Emo rap

- Autotune : effet marqué (85 %, vitesse 12 ms)
- Nettoyage : coupe-bas 100 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 100 Hz, bas-médium -2.5 dB à 300 Hz, présence +3 dB à 3.5 kHz, air +3 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 5:1 au seuil -22 dB, attaque 5 ms, relâche 80 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 20 ms, relâche 150 ms, détection RMS
- De-esser : 7 kHz, force 70 %, max -6 dB
- Saturation : +4 dB de chauffe, mélange 30 %
- Réverb : 28 %, taille 70 %, pré-délai 35 ms
- Délai : 20 %, 1/4 (noire), répétitions 35 %, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, 1 harmonie, backs sur les mots clés, ad-libs, ambiance

### Afro trap

- Autotune : effet marqué (85 %, vitesse 12 ms)
- Nettoyage : coupe-bas 100 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 100 Hz, bas-médium -2.5 dB à 300 Hz, présence +3 dB à 3.5 kHz, air +3.5 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 5:1 au seuil -21 dB, attaque 4 ms, relâche 70 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -27 dB, attaque 20 ms, relâche 150 ms, détection RMS
- De-esser : 7 kHz, force 70 %, max -6 dB
- Saturation : +4.5 dB de chauffe, mélange 30 %
- Réverb : 16 %, taille 50 %, pré-délai 25 ms
- Délai : 16 %, 1/8 (croche), répétitions 30 %, ping-pong, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, 1 harmonie, backs sur les mots clés, ad-libs

### Rap lo-fi / Chill

- Autotune : léger, naturel (30 %, vitesse 50 ms)
- Nettoyage : coupe-bas 100 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 100 Hz, graves +1 dB sous 200 Hz, bas-médium -1.5 dB à 300 Hz, présence +1 dB à 3 kHz, air -1 dB au-dessus de 10 kHz, coupe-haut 11 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 3:1 au seuil -22 dB, attaque 12 ms, relâche 140 ms, détection RMS
- Compresseur 2 (nivellement) : 1.8:1 au seuil -28 dB, attaque 30 ms, relâche 250 ms, détection RMS
- De-esser : 7 kHz, force 60 %, max -6 dB
- Saturation : +3 dB de chauffe, mélange 30 %
- Réverb : 20 %, taille 55 %, pré-délai 25 ms
- Délai : 10 %, 1/4 (noire), répétitions 25 %
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, ambiance

### Phonk

- Autotune : désactivé
- Nettoyage : coupe-bas 150 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 150 Hz, bas-médium -3 dB à 300 Hz, présence +4 dB à 2.5 kHz, air -2 dB au-dessus de 10 kHz, coupe-haut 9 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 8:1 au seuil -18 dB, attaque 2 ms, relâche 50 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -26 dB, attaque 15 ms, relâche 150 ms, détection RMS
- De-esser : 7 kHz, force 50 %, max -6 dB
- Saturation : +10 dB de chauffe, mélange 50 %
- Réverb : 12 %, taille 45 %, pré-délai 15 ms
- Délai : 15 %, 1/8 (croche), répétitions 30 %, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, backs sur les mots clés, ad-libs

### Jersey club

- Autotune : moyen (80 %, vitesse 10 ms)
- Nettoyage : coupe-bas 110 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 110 Hz, bas-médium -2.5 dB à 300 Hz, présence +3 dB à 3.5 kHz, air +4.5 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 5:1 au seuil -22 dB, attaque 3 ms, relâche 60 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 20 ms, relâche 150 ms, détection RMS
- De-esser : 7 kHz, force 75 %, max -6 dB
- Saturation : +3.5 dB de chauffe, mélange 25 %
- Réverb : 14 %, taille 50 %, pré-délai 20 ms
- Délai : 15 %, 1/8 (croche), répétitions 25 %, ping-pong, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, 1 harmonie, backs sur les mots clés, ad-libs

**Famille Chant / Pop / R&B**

### Pop urbaine

- Autotune : moyen (70 %, vitesse 20 ms)
- Nettoyage : coupe-bas 90 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 90 Hz, bas-médium -2 dB à 300 Hz, présence +2.5 dB à 3 kHz, air +4 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 4:1 au seuil -20 dB, attaque 8 ms, relâche 100 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -26 dB, attaque 25 ms, relâche 200 ms, détection RMS
- De-esser : 7 kHz, force 70 %, max -6 dB
- Saturation : +3 dB de chauffe, mélange 25 %
- Réverb : 20 %, taille 55 %, pré-délai 30 ms
- Délai : 12 %, 1/4 (noire), répétitions 25 %
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 1 harmonie, backs sur les mots clés, ambiance

### Pop

- Autotune : moyen (60 %, vitesse 25 ms)
- Nettoyage : coupe-bas 90 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 90 Hz, bas-médium -2 dB à 300 Hz, présence +2.5 dB à 3.5 kHz, air +4.5 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 4:1 au seuil -20 dB, attaque 6 ms, relâche 90 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -26 dB, attaque 25 ms, relâche 200 ms, détection RMS
- De-esser : 7 kHz, force 75 %, max -6 dB
- Saturation : +2.5 dB de chauffe, mélange 20 %
- Réverb : 22 %, taille 60 %, pré-délai 35 ms
- Délai : 15 %, 1/4 (noire), répétitions 25 %
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, 2 harmonies, backs sur les mots clés, ambiance

### R&B

- Autotune : moyen (60 %, vitesse 40 ms)
- Nettoyage : coupe-bas 70 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 80 Hz, graves +1.5 dB sous 200 Hz, bas-médium -1.5 dB à 350 Hz, présence +1.5 dB à 3 kHz, air +3 dB au-dessus de 11 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 3:1 au seuil -22 dB, attaque 15 ms, relâche 150 ms, parallèle 85 %, détection RMS
- Compresseur 2 (nivellement) : 1.8:1 au seuil -28 dB, attaque 30 ms, relâche 250 ms, détection RMS
- De-esser : 7 kHz, force 60 %, max -4 dB
- Saturation : +2 dB de chauffe, mélange 15 %
- Réverb : 30 %, taille 75 %, pré-délai 45 ms
- Délai : 15 %, 1/8 pointée, répétitions 30 %
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 2 harmonies, ad-libs, ambiance

### Gospel / Soul

- Autotune : léger, naturel (20 %, vitesse 60 ms)
- Nettoyage : coupe-bas 80 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 80 Hz, graves +1.5 dB sous 200 Hz, bas-médium -1.5 dB à 350 Hz, présence +2 dB à 3 kHz, air +3 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 3:1 au seuil -22 dB, attaque 15 ms, relâche 160 ms, parallèle 85 %, détection RMS
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 30 ms, relâche 250 ms, détection RMS
- De-esser : 7 kHz, force 70 %, max -6 dB
- Saturation : +2 dB de chauffe, mélange 20 %
- Réverb : 32 %, taille 80 %, pré-délai 45 ms
- Délai : 8 %, 1/8 pointée, répétitions 20 %
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 2 harmonies, ad-libs, ambiance

### Variété / Chanson

- Autotune : léger, naturel (30 %, vitesse 50 ms)
- Nettoyage : coupe-bas 80 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 80 Hz, graves +1 dB sous 200 Hz, bas-médium -1.5 dB à 300 Hz, présence +2 dB à 3 kHz, air +2.5 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 3:1 au seuil -20 dB, attaque 12 ms, relâche 140 ms, détection RMS
- Compresseur 2 (nivellement) : 1.8:1 au seuil -26 dB, attaque 30 ms, relâche 250 ms, détection RMS
- De-esser : 7 kHz, force 60 %, max -6 dB
- Saturation : +1.5 dB de chauffe, mélange 15 %
- Réverb : 25 %, taille 65 %, pré-délai 35 ms
- Délai : 8 %, 1/4 (noire), répétitions 20 %
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 1 harmonie, ambiance

### Raï / Raï'n'B

- Autotune : effet marqué (95 %, vitesse 5 ms)
- Nettoyage : coupe-bas 100 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 100 Hz, bas-médium -2.5 dB à 300 Hz, présence +3 dB à 3 kHz, air +3.5 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 5:1 au seuil -22 dB, attaque 4 ms, relâche 70 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 20 ms, relâche 150 ms, détection RMS
- De-esser : 7 kHz, force 70 %, max -6 dB
- Saturation : +3 dB de chauffe, mélange 25 %
- Réverb : 30 %, taille 70 %, pré-délai 30 ms
- Délai : 22 %, 1/8 pointée, répétitions 35 %, ping-pong
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 2 harmonies, ad-libs, ambiance

### Rock

- Autotune : léger, naturel (10 %, vitesse 100 ms)
- Nettoyage : coupe-bas 90 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 90 Hz, bas-médium -2.5 dB à 350 Hz, présence +3 dB à 3 kHz, air +2 dB au-dessus de 10 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 5:1 au seuil -18 dB, attaque 10 ms, relâche 120 ms
- Compresseur 2 (nivellement) : 2.5:1 au seuil -26 dB, attaque 20 ms, relâche 200 ms, détection RMS
- De-esser : 7 kHz, force 60 %, max -6 dB
- Saturation : +8 dB de chauffe, mélange 35 %
- Réverb : 15 %, taille 50 %, pré-délai 30 ms
- Délai : 12 %, 1/16, répétitions 10 %
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, 1 harmonie, backs sur les mots clés

### Acoustique / Folk

- Autotune : léger, naturel (15 %, vitesse 80 ms)
- Nettoyage : coupe-bas 75 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 75 Hz, graves +1 dB sous 200 Hz, bas-médium -2 dB à 300 Hz, présence +1.5 dB à 3 kHz, air +3 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 2.5:1 au seuil -20 dB, attaque 15 ms, relâche 150 ms, détection RMS
- Compresseur 2 (nivellement) : 1.6:1 au seuil -26 dB, attaque 30 ms, relâche 250 ms, détection RMS
- De-esser : 7 kHz, force 60 %, max -6 dB
- Saturation : +1 dB de chauffe, mélange 10 %
- Réverb : 20 %, taille 55 %, pré-délai 30 ms
- Délai : 6 %, 1/16, répétitions 10 %
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 1 harmonie

### Country

- Autotune : léger, naturel (30 %, vitesse 50 ms)
- Nettoyage : coupe-bas 80 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 80 Hz, graves +1 dB sous 200 Hz, bas-médium -2 dB à 300 Hz, présence +2.5 dB à 3 kHz, air +2.5 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 4:1 au seuil -20 dB, attaque 10 ms, relâche 120 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -26 dB, attaque 25 ms, relâche 200 ms, détection RMS
- De-esser : 7 kHz, force 60 %, max -6 dB
- Saturation : +2 dB de chauffe, mélange 20 %
- Réverb : 18 %, taille 50 %, pré-délai 30 ms
- Délai : 12 %, 1/16, répétitions 10 %
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, 1 harmonie

**Famille Afro / Caraïbes / Latino**

### Afro

- Autotune : moyen (90 %, vitesse 20 ms)
- Nettoyage : coupe-bas 90 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 90 Hz, bas-médium -2 dB à 300 Hz, présence +2.5 dB à 3 kHz, air +3.5 dB au-dessus de 10 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 3:1 au seuil -20 dB, attaque 8 ms, relâche 100 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -26 dB, attaque 25 ms, relâche 200 ms, détection RMS
- De-esser : 7 kHz, force 70 %, max -6 dB
- Saturation : +3 dB de chauffe, mélange 25 %
- Réverb : 22 %, taille 50 %, pré-délai 30 ms
- Délai : 22 %, 1/4 (noire), répétitions 30 %, ping-pong, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 2 harmonies, ad-libs, ambiance

### Amapiano

- Autotune : moyen (60 %, vitesse 20 ms)
- Nettoyage : coupe-bas 100 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 100 Hz, bas-médium -2 dB à 300 Hz, présence +2.5 dB à 3.5 kHz, air +3.5 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 4:1 au seuil -20 dB, attaque 8 ms, relâche 110 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -26 dB, attaque 25 ms, relâche 200 ms, détection RMS
- De-esser : 7 kHz, force 70 %, max -6 dB
- Saturation : +2.5 dB de chauffe, mélange 20 %
- Réverb : 30 %, taille 75 %, pré-délai 40 ms
- Délai : 22 %, 1/8 pointée, répétitions 40 %, ping-pong
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 2 harmonies, ad-libs, ambiance

### Dancehall / Shatta

- Autotune : effet marqué (90 %, vitesse 8 ms)
- Nettoyage : coupe-bas 110 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 110 Hz, bas-médium -3 dB à 300 Hz, présence +4 dB à 3 kHz, air +3 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 6:1 au seuil -22 dB, attaque 3 ms, relâche 60 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 15 ms, relâche 150 ms, détection RMS
- De-esser : 7 kHz, force 65 %, max -6 dB
- Saturation : +6 dB de chauffe, mélange 40 %
- Réverb : 12 %, taille 45 %, pré-délai 20 ms
- Délai : 22 %, 1/8 (croche), répétitions 35 %, ping-pong, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 1 harmonie, backs sur les mots clés, ad-libs

### Bouyon

- Autotune : moyen (80 %, vitesse 10 ms)
- Nettoyage : coupe-bas 110 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 110 Hz, bas-médium -3 dB à 300 Hz, présence +4 dB à 3 kHz, air +3 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 6:1 au seuil -21 dB, attaque 3 ms, relâche 60 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -27 dB, attaque 15 ms, relâche 150 ms, détection RMS
- De-esser : 7 kHz, force 65 %, max -6 dB
- Saturation : +6 dB de chauffe, mélange 40 %
- Réverb : 10 %, taille 40 %, pré-délai 15 ms
- Délai : 15 %, 1/8 (croche), répétitions 25 %, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, backs sur les mots clés, ad-libs

### Zouk / Kompa

- Autotune : moyen (75 %, vitesse 20 ms)
- Nettoyage : coupe-bas 90 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 90 Hz, graves +1 dB sous 200 Hz, bas-médium -1.5 dB à 300 Hz, présence +2 dB à 3 kHz, air +3.5 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 3.5:1 au seuil -22 dB, attaque 10 ms, relâche 120 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 25 ms, relâche 200 ms, détection RMS
- De-esser : 7 kHz, force 75 %, max -6 dB
- Saturation : +2 dB de chauffe, mélange 20 %
- Réverb : 28 %, taille 70 %, pré-délai 35 ms
- Délai : 15 %, 1/8 pointée, répétitions 30 %
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 2 harmonies, ad-libs, ambiance

### Latino / Reggaeton

- Autotune : effet marqué (85 %, vitesse 10 ms)
- Nettoyage : coupe-bas 100 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 100 Hz, bas-médium -2.5 dB à 300 Hz, présence +3 dB à 3.5 kHz, air +4 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 5:1 au seuil -22 dB, attaque 4 ms, relâche 70 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 20 ms, relâche 150 ms, détection RMS
- De-esser : 7 kHz, force 70 %, max -6 dB
- Saturation : +4 dB de chauffe, mélange 25 %
- Réverb : 18 %, taille 55 %, pré-délai 25 ms
- Délai : 18 %, 1/8 pointée, répétitions 30 %, ping-pong, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 2 harmonies, backs sur les mots clés, ad-libs, ambiance

### Funk brésilien

- Autotune : moyen (50 %, vitesse 20 ms)
- Nettoyage : coupe-bas 120 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 120 Hz, bas-médium -3 dB à 300 Hz, présence +4 dB à 3 kHz, air +2 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 8:1 au seuil -18 dB, attaque 2 ms, relâche 50 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -26 dB, attaque 15 ms, relâche 150 ms, détection RMS
- De-esser : 7 kHz, force 60 %, max -6 dB
- Saturation : +8 dB de chauffe, mélange 45 %
- Réverb : 6 %, taille 30 %, pré-délai 10 ms
- Délai : 10 %, 1/8 (croche), répétitions 20 %, seulement en fin de phrase
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, backs sur les mots clés, ad-libs

**Famille Électro**

### Électro / House

- Autotune : moyen (80 %, vitesse 12 ms)
- Nettoyage : coupe-bas 120 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 120 Hz, bas-médium -3 dB à 300 Hz, présence +3 dB à 3.5 kHz, air +5 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 5:1 au seuil -22 dB, attaque 3 ms, relâche 60 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -28 dB, attaque 20 ms, relâche 150 ms, détection RMS
- De-esser : 7 kHz, force 75 %, max -6 dB
- Saturation : +3 dB de chauffe, mélange 25 %
- Réverb : 25 %, taille 70 %, pré-délai 40 ms
- Délai : 22 %, 1/8 pointée, répétitions 40 %, ping-pong
- Sortie : -14 dB
- Pistes générées cochées par défaut : 2 doublages, 1 harmonie, backs sur les mots clés, ambiance

### Afro house

- Autotune : moyen (50 %, vitesse 25 ms)
- Nettoyage : coupe-bas 110 Hz, débruitage -12 dB, silences -12 dB, respirations -8 dB, plosives (p, b), dé-écrêtage
- Niveleur : niveau tenu autour de -20 dB (+4 / -4 dB max, fenêtre 400 ms)
- EQ : coupe-bas 110 Hz, bas-médium -2 dB à 300 Hz, présence +2.5 dB à 3.5 kHz, air +4 dB au-dessus de 12 kHz
- Résonances : rabaissées au-delà de 6.0 dB au-dessus du voisinage, max -3 dB, graves protégés sous 600 Hz
- Compresseur : 4:1 au seuil -21 dB, attaque 6 ms, relâche 100 ms
- Compresseur 2 (nivellement) : 2:1 au seuil -27 dB, attaque 25 ms, relâche 200 ms, détection RMS
- De-esser : 7 kHz, force 70 %, max -6 dB
- Saturation : +2 dB de chauffe, mélange 20 %
- Réverb : 32 %, taille 80 %, pré-délai 45 ms
- Délai : 25 %, 1/8 pointée, répétitions 45 %, ping-pong
- Sortie : -14 dB
- Pistes générées cochées par défaut : 1 doublage, 2 harmonies, ad-libs, ambiance

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

## Mises à jour (bouton en haut à droite)

Plus besoin de désinstaller / réinstaller : chaque compilation de la CI publie une nouvelle version
(« release » GitHub `studiovoix-build<N>` avec l'installateur).

- Le programme vérifie au démarrage puis toutes les 30 min ; le bouton **Mise à jour** passe au vert
  (« Mise à jour dispo ! ») quand une version plus récente existe.
- Clic → confirmation → téléchargement en arrière-plan (on peut continuer à travailler) → vérification
  (taille, empreinte SHA-256 publiée par GitHub, en-tête d'exécutable Windows) → le projet est enregistré,
  StudioVoix se ferme, l'installateur attend sa fermeture, installe par-dessus puis **relance le programme**.
- Jamais pendant un enregistrement : le bouton « Installer maintenant » attend que la prise soit finie.
- Projets, réglages, « Mon son » et journaux sont conservés.
- Journal de l'installation : `%APPDATA%\StudioVoix\logs\installation_build<N>.log`.

**Dépôt privé** : GitHub n'autorise le téléchargement qu'avec un jeton. Une seule fois :
1. github.com → Settings → Developer settings → Personal access tokens → **Fine-grained tokens** → Generate new token.
2. Repository access : *Only select repositories* → `rebuild_project` ; Permissions → **Contents : Read-only** (rien d'autre).
3. Copier le jeton dans StudioVoix → **Paramètres** → « Jeton GitHub (mises à jour) ».

Sans jeton et dépôt privé, le bouton affiche « Mise à jour (!) » avec l'explication. Si le dépôt devient public,
aucun jeton n'est nécessaire.

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
studiovoix_cli artefacts <voix> [--instru f] [--style s|all] [--sanscomp] [--attribuer]
                                                       détecteur d'artefacts : trous en pleine note, oscillations 3-12 Hz,
                                                       sauts de gain, par style ; --attribuer coupe chaque étage à son tour
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

- compilation, 892 vérifications de tests ;
- auto-test de l'application : import, analyse, rendu, génération, annuler/rétablir, export à −14,00 LUFS,
  prise annulée pendant son traitement, réouverture du projet pendant des calculs ;
- installateur Windows : installation silencieuse, tests lancés depuis le dossier installé, désinstallation.

**Non vérifié** (pas de matériel ni de clé dans l'environnement de développement) :

- carte son réelle, latence réelle et recalage sur du vrai matériel ;
- carte débranchée pendant une prise, changement de fréquence, récupération après un vrai plantage ;
- qualité d'écoute des traitements et des pistes générées ;
- appels réels aux API Claude et ElevenLabs ;
- export MP3 avec `lame.exe`.
