# À faire

## Guide d'installation du matériel

Fait : [docs/GUIDE_MATERIEL.md](docs/GUIDE_MATERIEL.md) avec 4 schémas (micro USB, interface + XLR,
montages à éviter, placement et niveau). À relire par Yann ; les modèles cités en exemple sont à
revérifier au moment de l'achat. StudioVoix utilise WASAPI (pas d'ASIO dans cette version).

## Audit studio

Voir [docs/AUDIT_STUDIO.md](docs/AUDIT_STUDIO.md) : ce qui manque par rapport à un vrai programme de studio,
comment les automatismes doivent être faits, ordre proposé.

## Praticité (retour de Yann après essai du build 74 : « rien de pratique, il faut que ce qui concerne un truc soit dessus »)

- Fait (build 75) : menu « ⋯ » / clic droit sur chaque piste regroupant toutes ses actions (import, remplacer l'instru,
  style et effets, paroles IA, nettoyage IA, séparation IA, blocs, armer, ordre, renommer, supprimer) ; téléchargement
  des outils IA à la demande depuis l'action (boîte « Télécharger et continuer », progression en bas, action enchaînée) ;
  onglets renommés (Piste, Paroles, Mix & Master, Assistant, Outils IA) ; aide d'étapes dans la timeline vide.
- Fait (build 76), retour « rien ne fonctionne » : cause = toute piste voix naissait « brute » (effets, curseurs et
  cases grisés tant qu'un style n'était pas choisi dans la liste « Type ») et les réglages d'une case ne s'appliquaient
  qu'à la fermeture de la fenêtre. Désormais : pistes traitées par le style du projet dès le départ (« Brut » = écoute
  sans effet), réglages de case appliqués en direct (250 ms après le dernier mouvement, une seule étape d'annulation).
- Fait (build 77), retour « plein d'avertissements, blindé d'écriture, le fa majeur c'est une option, instru avec des
  trous » : les en-têtes n'affichent plus la liste des alertes — ce qui est corrigé automatiquement (écrêtage, montées,
  niveau vs voix principale, gamme) n'est plus affiché comme alerte mais listé dans le panneau « Piste » (« Corrigé
  automatiquement : … ») ; seule une ligne courte « ⚠ … » reste pour ce qui demande une action (texte complet au survol,
  « À faire : … » dans le panneau). Case « Gamme » à côté de la tonalité (barre du haut) : décochée = correction note par
  note sans analyse de gamme (réglage sauvegardé dans le projet). Instru importée en mode « Correction » par défaut
  (dé-écrêtage, débruitage, niveleur, résonances, limiteur) ; rendus de fond en priorité basse (moins de risque de
  décrochage à la lecture).
- Fait (build 78), retour « du moment qu'on insère une piste, elle ne doit pas être modifiée » : retour au brut
  par défaut pour tout ce qui est inséré (voix importée / déposée / nouvelle, instru, prises d'instruments, parties
  Demucs) ; seul l'équilibrage des niveaux est automatique. Pour ne pas retomber sur « rien ne fonctionne » : les
  curseurs, cases et la chaîne d'une piste brute restent actifs et le premier geste passe la piste en traité par son
  style (RemixPanel::ensureTreated), les curseurs montrent les positions du style au lieu de zéros.
- Fait (build 79) : le bouton « Ingénieur du son » ne touche plus qu'aux pistes voix (jamais les prises d'instruments
  ni l'instru) ; leur correction reste possible à la main, piste par piste.
- Fait (build 80), retour « tu imposes autotune / présence / espace / énergie / volume, ce n'est pas ça » : curseurs
  abstraits et « Mon son » retirés du panneau Piste (plus de preset de curseurs réappliqué aux nouvelles pistes ni au
  changement de style) ; la chaîne réelle du style (niveleur, résonances, compresseur, de-esser, saturation, réverb,
  délai…) passe en premier, une ligne par effet avec ses réglages, clic = régler, clic droit = désactiver.
- Fait (build 81), demande « est-ce que le programme étudie le son à la fin d'un enregistrement ? » : oui désormais —
  dsp::fitStyleToMeasurement : la prise est mesurée (analyzeTrackProblems) et les valeurs du style en découlent
  (compresseur, second compresseur, niveleur, résonances, EQ, saturation, de-esser, débruitage, pré-délai) ; valeurs
  réellement utilisées affichées dans la chaîne (TrackRender::paramsUsed) + ligne « Réglé d'après la mesure » ; instru
  brute analysée et rapport affiché, sans modification. Test unitaire ajouté.
- Fait (build 82), demande « une bande par piste où on voit le volume et le plafond avant que ça sature » : vumètres
  d'en-tête rehaussés (11 px) et lisibles : zones vert / orange (−12) / rouge (0 dB, plafond en trait blanc),
  graduations, crête tenue 1,5 s, témoin de saturation 2 s ; même dessin pour les vumètres micro / sortie du haut.
- Fait (build 83), retour « pas de phrases dans les cases ; un petit panneau attention orange, clic = bulle, et une case
  Corriger si le programme sait corriger » : en-tête sur une ligne courte ; bouton « ⚠ » seulement s'il y a un
  problème ; bulle (CallOutBox) avec texte + « Corriger : … » (Session::trackIssues : correction automatique, nettoyage,
  fader) ; pistes brutes analysées au rendu (défauts listés).
- À vérifier avec Yann : quels styles « défaussent » la voix (trop compressé ? saturé ? trop de réverb ?) pour ajuster
  le preset de ce style (valeurs dans StyleProfiles.cpp, cases du panneau Piste).
- Si les « trous » dans l'instru persistent : passer le ducking par défaut à 0 dB (actuellement 2,5 dB, réglable dans
  Mix & Master) et demander le fichier `%APPDATA%\StudioVoix IA\logs\app.log` pour voir les décrochages du moteur
  temps réel (lignes `[Moteur]` / `xrun`).
- À faire selon le prochain retour : panneau « Piste » adapté à l'instru (remplacer, séparer, caler) ; bouton
  « Séparer » visible sur l'en-tête de l'instru ; sélection du style directement dans l'en-tête de piste ; réduire la
  barre du haut (Nouveau / Ouvrir / Sauver dans l'accueil) ; glisser-déposer d'un fichier sur une piste existante.

## Prise sans casque (retour de Yann : « il enregistre la musique avec la voix, ça fait un décalage, 0 latence »)

- Fait (build 90) : causes = le micro capte l'instru des haut-parleurs (prise = voix + musique, doublée et décalée dans
  le mix) ; calage de la prise faux dans la page web (enregistreur MediaRecorder démarré ~100 ms avant l'instru, ignoré,
  + 40 ms fixes). Désormais : `dsp::removeBleed` (BleedRemover.cpp) : instru retrouvée dans la prise (GCC-PHAT +
  affinage à l'échantillon), fonction de transfert pièce + micro par tranches de 3 s (suit une dérive d'horloge),
  soustraction + suppression résiduelle douce (plancher -14 dB) ; le décalage mesuré sert à recaler la voix. Page :
  capture AudioWorklet (recorder-worklet.js, horodatée à l'échantillon), compte à rebours avant l'instru, latence
  annoncée par le navigateur seulement au casque, ajustement fin manuel à 0. Tests : unitaire (décalage 187,0 ms
  retrouvé, reste -25,6 dB, voix corrélée 0,998 ; dérive 50 ppm : -24 dB ; voix seule intacte) ; Chromium avec faux
  micro (voix + instru captée) : musique -3 → -39 dB, décalage mesuré ; CI : web/test/make_fake_mic.py + essai REC.
- À faire : même retrait dans le logiciel Windows (prise du moteur temps réel, référence = instru jouée) si Yann
  enregistre sans casque là aussi ; essai réel sur son PC (micro + haut-parleurs).

## Studio multipiste web (demande de Yann : « comme le mode studio, plusieurs pistes, chaque prise séparée »)

- Fait (build 92) : page `web/index.html` + `app.js` réécrites en studio : piste Instru en haut, pistes voix sans
  limite (nom libre), en-tête à gauche avec vumètre, type (voix principale / back / ambiance / doublage / harmonie /
  ad-libs / instrument), style, M / S, volume, ● armer, import ; ligne de temps commune, tête de lecture, clic = position ;
  traitement par piste en file d'attente (type + style → `makeParams(style, rôle)` + mesure) ; moteur :
  `sv_process_voice(…, roleId, …)`, `sv_balance_begin/add/end` (orchestre par type comme `render::roleOffsetLu`, puis
  voix / instru), `sv_limit`, `sv_roles` ; lecture en direct par piste (gain + vumètre, limiteur de sécurité) ; REC
  sur la piste armée avec référence de retrait = tout ce qui est joué (instru + autres pistes) ; téléphone : en-tête
  au-dessus de la forme d'onde. Essais : node (back −7,0 LU, ambiance −14,0 LU après équilibre) ; Chromium PC et
  téléphone (Pixel 7) : démo deux pistes, changement de style, rapport, lecture, export ; faux micro deux prises
  successives (principale puis back).
- Écart voulu avec le logiciel PC : back enregistré placé à −7 LU dans la page (0 dans `roleOffsetLu`, réglé par le
  style côté PC). Table dupliquée dans `web/api.cpp` (Renderer.cpp non compilé en WebAssembly) : à garder alignée.
- Fait ensuite (retour de Yann : « couper le son de chaque piste, écouter le tout ou n'en laisser qu'une », s'inspirer du
  fonctionnement d'un studio en ligne, sans le copier) : muet / solo en pleine lecture, pistes coupées grisées, « Écoute :
  n piste(s) sur N », « Tout écouter », barre d'espace ; transport fixé en bas (au pouce sur téléphone) ; plusieurs
  prises par piste (chaque REC ajoute une prise, choix dans l'en-tête) ; REC à partir de la tête de lecture ; glisser
  une prise pour la déplacer (`sv_process_voice(…, startSec)` : grille rythmique décalée comme `Renderer` côté PC) ;
  sauvegarde automatique IndexedDB (sons écrits une fois, réglages à chaque changement, sons orphelins effacés) et
  reprise au chargement ; « Nouveau projet » ; export des pistes séparées. Essais : e2e démo PC + Pixel 7 avec
  rechargement (projet identique), faux micro deux prises (piste 1 en muet pendant la 2e, solo, « Tout écouter »).
- Constaté en essai : faux micro = même fichier de voix que la piste 1 ; piste 1 jouée pendant la 2e prise → la voix se
  retire elle-même (SDR 6,4 dB). Artefact du test (un vrai back n'est pas identique à l'échantillon près), mais à
  vérifier en vrai : doublage chanté très serré sur la voix principale jouée aux haut-parleurs → écouter si la voix
  s'amincit ; sinon, casque conseillé pour les doublages.
- À faire : comping (morceaux de plusieurs prises), zoom, rognage / fondus des prises, bus voix (colle) comme le
  logiciel PC, versions du projet.

## Instru étouffée au mix, forme d'onde en direct (retours de Yann)

- Fait (build 95) : cause de l'instru « étouffée » = compresseur de sécurité sur la sortie à l'écoute (seuil -1 dBFS,
  ratio 20) et limiteur -1 dBTP sur tout le mix à l'export : sur une instru déjà forte, ils l'écrasaient en continu.
  Retirés ; si la somme dépasse -0,3 dBFS, gain pur sur le volume général (affiché dans le statut et le journal).
  Essai : voix coupées, export = instru d'origine à 1 pas de quantification 16 bits près (3,1e-5). Forme d'onde en direct
  pendant le REC : le worklet envoie une crête toutes les 256 échantillons, dessinée aussitôt sur la piste armée ;
  essai : plus de 20 000 pixels dessinés après 4 s de prise.
- À vérifier avec Yann : son instru réelle (la sienne peut dépasser 0 dBFS avec la voix : volume général baissé de
  quelques dB, son intact) ; si la voix couvre trop la musique, c'est le réglage voix / instru du style (à baisser).

## Export MP3, page rangée en 5 étapes, « Sans effet » dans les effets de la piste (demandes de Yann)

- Demande : « il faut que j'arrive à le sortir au format MP3 » ; « l'organisation des boutons… c'est le fouillis, il y
  en a en haut, en bas, à gauche, à droite, au milieu » ; « dans les effets de piste, savoir marquer sans effet ».
- Fait — MP3 : liste « Format » (WAV / MP3 320 kbit/s) commune aux quatre exports. **Nouvelle dépendance** : lamejs
  1.2.1 (LGPL-3.0, npm, 156 Ko), version épinglée et SHA-256 vérifié dans `web/fetch-ia.sh`, chargée seulement au
  premier export MP3 (aucun coût au démarrage). Encodage par blocs de 64 trames MP3 (73 728 échantillons) en rendant la main (page
  vivante), journalisé (durée, taille).
- Fait — page : en-tête (titre, sauvegarde, Nouveau projet) ; barre fixe en bas (REC, Stop, ▶ Brut, ▶ Mix, ■, temps,
  vumètre, écoute) ; étapes 1 Pistes, 2 Séparer une chanson, 3 Effets de la piste, 4 Volumes et mixage (⚖ Égaliser,
  Mixer la chanson), 5 Exporter ; réglages de prise, rapport et journal dans un bloc replié. Aucun identifiant
  changé : le code de la page n'a pas bougé. Règle globale `[hidden]` : les boutons « Chanson mixée / Avant mixage »
  n'apparaissent plus avant un mixage final ; « Chanson mixée (master) » grisé tant qu'il n'y a pas de mixage final.
- Fait — effets : trois boutons « Sans effet / Lissé / Style » en tête du tableau des effets de la piste.
- Essais : e2e démo PC et Pixel 7 (export MP3 : 1 577 796 octets pour 39,4 s, relu par ffprobe : MP3 stéréo
  44,1 kHz 320 kbit/s 39,44 s, crête -0,5 dB ; les trois boutons d'effets changent bien le son), balance, resample,
  split.
- Non vérifié : téléchargement du MP3 sur un vrai téléphone (iOS surtout) ; lisibilité de la page à l'œil de Yann.

## « Quand je mixe, les voix sont dans un sale état, pas lissées » : effets non imposés, mode « Lissé » (Yann)

- Constat de Yann, répété : propre en brut, sale une fois mixé ; « il ne faut pas que les effets soient imposés,
  c'est à nous de choisir les effets sur chaque piste ».
- Mesuré sur une vraie voix (style Trap) : le pré-réglage du style est très appuyé — compresseur 4,8 à 6:1 (4 à 5 dB
  de réduction moyenne), niveleur ±7 à ±10 dB, résonances rabaissées jusqu'à 6 dB sur 96 % des trames, débruitage
  -8 à -14 dB, autotune 70 à 100 % (vitesse 2 ms en Trap), saturation, écho. Variations rapides de gain par rapport à
  la voix brute : 2,1 dB efficaces (p95 4,2 dB) ; aucun effet seul ne les explique (1,9 à 2,2 dB en éteignant chacun).
- Fait : trois états par piste, sur le bouton qui s'appelait FX — « Brut » (aucun effet) → « Lissé » (voix seulement
  polie) → « Style » (tous les effets du style). Une piste enregistrée ou importée démarre « Lissé » ; une piste
  séparée reste « Brut » ; les anciens projets gardent « Style ». Mode lissé (moteur, `gentle`) : autotune,
  saturation, recalage rythmique et écho éteints ; compresseur ≤ 2,5:1 (attaque ≥ 10 ms, relâche ≥ 120 ms), second
  compresseur ≤ 1,5:1, niveleur ≤ ±3 dB, résonances ≤ 3 dB, débruitage ≤ 6 dB, silences ≤ 6 dB, de-esser ≤ 40 %,
  égaliseur ≤ ±3 dB, réverb ≤ 8 %. Chaque effet se rallume ou se règle dans le tableau des effets. Couleurs : bleu
  = brut, violet = lissé, rose = style.
- Testé e2e (PC, Pixel 7, micro + radio) : piste par défaut « lissée » (autotune, saturation, écho éteints,
  compresseur 2,5:1) ; bouton → Style (autotune allumé, compresseur 3,5 à 6:1) → Brut (sans effet) → Lissé.
- Non vérifié : que « Lissé » sonne propre à l'oreille de Yann (aucune écoute possible ici) ; si ça reste sale en
  « Lissé », éteindre les effets un par un dans le tableau pour trouver lequel.

## Pistes couplets / refrains à la séparation + export de la chanson brute égalisée (demandes de Yann)

- Fait — couplets / refrains : option « Couplets / refrains » (cochée) dans la carte Séparation. Les sections viennent
  de l'analyse du morceau (`detectStructure`, déjà faite à l'import) ; chaque voix est répartie sur une piste
  « Couplets » et une piste « Refrain » (« Chanteur k — couplets / refrain » s'il y a plusieurs chanteurs) ;
  `sectionRanges` déplace chaque coupe vers le creux de la voix le plus proche (± 1,5 s) pour ne pas couper un mot ;
  sans refrain repéré, la voix reste sur une piste (dit dans le compte rendu).
- Fait — défaut corrigé au passage : aux coupes entre deux pistes (chanteurs), les fondus se recouvraient sans se
  compenser : bosse de +6 dB pendant 30 ms à chaque relais en plein chant. `splitRanges` : fondu enchaîné de 20 ms
  centré sur la coupe, la somme des pistes redonne exactement la voix d'origine (essai `web/test/split.mjs` : écart
  3e-8 ; ajouté à la CI).
- Fait — export : bouton « Exporter le brut » (barre du haut) = la chanson complète telle que « ▶ Brut » la joue,
  sans effet, volumes égalisés si « ⚖ Égaliser » est actif (`StudioVoix-brut-egalise.wav`), sinon volumes d'origine
  (`StudioVoix-brut.wav`). Testé e2e : durée = tout le morceau, niveau du fichier = somme attendue à 0,01 dB près
  (démo, et après une séparation à 48 kHz).
- Non vérifié : justesse des sections sur de vrais morceaux (repérage approximatif par blocs de 4 mesures ; sur
  « fishin » : couplet 0–35 s, refrain 35–122 s, outro — non contrôlé à l'oreille).
- Essai complet sur un vrai morceau (« fishin », 2 min 13, une chanteuse, séparé par la page en 11 min 51 sur ce
  serveur) : pistes créées « Couplets », « Refrain », « Backs » ; une seule voix repérée (juste) ; coupes à 0:35 et
  2:01 ; « Égaliser » : couplets et refrain à -19,3 LUFS, backs à -26,3 ; « Exporter le brut » : chanson entière
  (5 864 816 échantillons), niveau attendu ; mixage final -14,1 LUFS.

## « Crépitements et saccades seulement quand c'est mixé, à partir d'un certain niveau ; en brut c'est propre » (Yann)

- Essayé / observé (aucune écoute possible ici, mesures seulement) :
  - chaîne d'effets sur une vraie voix forte (« mardy », crête -0,1 dBFS) : pointes isolées (dérivée seconde) 14,5 /s
    en brut, 13,6 /s traité, 11,6 à 15,4 /s avec chaque effet éteint à tour de rôle → la chaîne n'ajoute pas de
    craquement mesurable sur cet extrait ;
  - chanson mixée contre somme simple (deux morceaux à -9 LUFS) : variation de gain p95 0,9 dB, max 2,7 dB / 50 ms ;
  - creux de l'instru sous la voix : enveloppe 10 ms / 250 ms, 2,5 dB : pas de claquement possible ;
  - lecture : sortie qui saturait quand un solo était retiré en cours de lecture (corrigé au build 120).
- Hypothèses restantes : écrêtage de la sortie dans un cas non reproduit ; effets du style appliqués à des voix déjà
  produites (pistes importées ou FX activé sur une piste séparée) ; découpage d'une voix entre deux pistes de niveaux
  différents.
- Fait pour trancher : témoin rouge « ⚠ sortie saturée ×N (+x dB) » dans la barre de lecture dès que la sortie dépasse
  le maximum (lectures Mix, Brut et Chanson mixée), noté dans le journal ; compression du bus voix au plus fort
  affichée dans le compte rendu du mixage.
- Attendu de Yann : une capture d'écran prise pendant que ça crépite (pistes, étiquettes « traitée » / « sans effet »,
  barre d'état, témoin de saturation).

## Tableau des effets par piste : pré-réglage visible, réglable, actif pendant la lecture (demande de Yann)

- Fait — moteur (`api.cpp`) : `sv_process_voice` rend `preset` (réglages du style ajustés à la prise) et `fx` (réglages
  appliqués), un objet par effet ({ on, valeurs }) ; nouvel argument `fxJson` = réglages faits à la main, appliqués
  par-dessus (valeurs bornées ; « on » à faux neutralise l'effet, « on » à vrai sur un effet éteint par le style lui
  donne une valeur de départ). 13 effets : nettoyage, niveleur, recalage rythmique, autotune, égaliseur, résonances,
  compresseur, compresseur doux, de-esser, saturation, réverb, écho, placement stéréo.
- Fait — page : carte « Effets de « piste » » sous le tableau des pistes (piste sélectionnée) : une ligne par effet
  (symbole, nom, case allumé / éteint, résumé, étiquette « modifié ») ; clic sur la ligne = curseurs avec la valeur du
  pré-réglage rappelée ; « ↺ Pré-réglage de cet effet » et « ↺ Tout remettre au pré-réglage » ; réglages gardés avec
  le projet (`t.fx`) ; la piste est retraitée 0,35 s après le dernier mouvement et, si « ▶ Mix » joue, son nouveau
  son remplace l'ancien à la position courante sans arrêter la lecture (`liveRefresh`, fondu de 30 ms).
- Testé e2e (PC + Pixel 7) pendant la lecture : réverb + écho éteints → traîne de la piste -60,3 → -130,6 dB ; réverb
  poussée à 60 % → -81,0 dB ; 2 échanges de son sans arrêt ; retour au pré-réglage identique au départ.
- À savoir : ce n'est pas instantané — la piste est recalculée par le moteur (≈ 3 s pour une prise de 28 s sur PC,
  plus long sur téléphone ou sur une longue prise), puis le son change. Pas de vocodeur dans le moteur : l'effet le
  plus proche est l'autotune (vitesse 0 = effet « robot »).
- Non vérifié : à l'oreille ; pistes « sans effet » (séparées) : il faut d'abord activer FX sur la piste.
- « Saccades quand la voix monte après mixage » — hypothèse écartée par la mesure : compresseur du bus voix trop
  sollicité par des voix séparées (niveau du bus mesuré -16,6 dBFS sur « mardy », pas plus fort que la démo ;
  variation de gain de la chanson mixée contre la somme simple : p95 0,9 dB, max 2,7 dB par trame de 50 ms). Seuil
  adaptatif essayé (max 1,4 dB) puis retiré : il coupait aussi la « colle » voulue sur les voix enregistrées (3,5 →
  0,2 dB sur la démo). Gardé : `busGrMaxDb` dans le rapport du mixage (diagnostic). Cause toujours non établie ;
  pistes restantes : saturation en lecture (corrigée), conversion 48 kHz (corrigée, build 119), morceau d'un même
  chanteur réparti sur deux pistes de niveaux différents (découpage du build 118, réglé au 119).

## Lecture brute avec volumes égalisés + saturation en lecture (retours de Yann)

- Changé à la demande de Yann (« pas une case à cocher : un bouton qui lance le travail ») : bouton « ⚖ Égaliser » dans la
  barre de lecture, à côté de « ▶ Brut ». Un appui mesure toutes les pistes et règle leurs volumes selon leur type,
  sans aucun effet ; le détail défile piste par piste dans la barre d'état, chaque piste affiche « brut égalisé
  ±x dB », le bouton devient « ⚖ Égalisé ✓ » (« à refaire » si les pistes changent) ; second appui = volumes
  d'origine ; état gardé avec le projet. Testé e2e PC + Pixel 7, et après une séparation à 48 kHz : pistes restées
  « sans effet », Chanteur 1 et 2 à -21,3 LUFS, backs à -28,3 LUFS (7 LU dessous).
- (Première version, remplacée) : case « Égaliser » à côté de « ▶ Brut » (cochée par défaut, choix gardé) : lecture des prises brutes, sans aucun
  effet, avec seulement le volume de chaque piste réglé selon son type (mêmes règles que le Mix : voix principales au
  même niveau, backs -7 LU, ambiance -14 LU, voix / instru) ; équilibre calculé sur les prises brutes
  (`ensureRawBalance`, recalculé seulement si les pistes changent) ; décochée : prises exactement comme enregistrées.
  Testé e2e PC + Pixel 7 (gain de chaque piste = équilibre brut ; décochée pendant la lecture = curseur seul).
- Fait : le volume général de la lecture (marge contre la saturation) n'était calculé qu'au lancement ; un solo retiré,
  une piste réactivée ou un curseur monté pendant la lecture pouvaient faire saturer la sortie (craquements quand le
  niveau monte). Recalculé 120 ms après chaque changement, appliqué en douceur.
- « Pas lisse / saccades quand la voix monte, après mixage » — mesuré sur un vrai morceau calme (« fishin », 45 s,
  48 kHz, séparé puis mixé par la page) : chanson mixée / morceau d'origine = gain stable (variation d'une trame de
  50 ms à l'autre : médiane 0,08 dB, max 0,8 dB, aucun saut > 2 dB ; passages forts 3,7 dB, calmes 3,9 dB) → pas de
  pompage mesuré sur ce morceau. Morceaux forts (-9 LUFS) : voir la section du tableau des effets ci-dessus.

## Une piste par voix quel que soit le nombre + « crépitements dans les aigus » des voix séparées (retours de Yann)

- Constat de Yann : morceau avec sa voix + une voix de femme → une seule piste ; voix séparées « pas lisses », qui
  crépitent quand les aigus montent (écoute en solo après mixage).
- Chanteurs — fait : `singers.js` refait pour un nombre de voix libre. Mis au point sur de vrais chants (voix séparées
  par les modèles de la page : homme « mardy » 20 s, femme « fishin » 36 s, homme « spleeter » 7 s, + 3 locuteurs) :
  deux fenêtres de 2 s d'un même chanteur se ressemblent de 0,2 à 0,8 (moyenne ≈ 0,45), deux chanteurs différents de
  -0,1 à 0,35 (≈ 0,13) → regroupement en 3 temps (petits groupes sûrs ≥ 0,45, fusion des groupes dont les centres se
  ressemblent ≥ 0,44, réaffectation au centre le plus proche, groupes < 3 s absorbés). 11 cas / 11 justes : homme
  seul, femme seule, homme puis femme, alternés 10 s (coupes à ±0,5 s), invité de 7 s (15 %), deux hommes, 3 voix,
  6 voix, parole A/B, A×2, A/B/C. Plus de règle « seconde voix ≥ 20 % ».
- Chanteurs — défaut trouvé : `findPhrases` ne trouvait AUCUNE phrase sur un chant continu (seuil = fond + 15 dB, or
  sans pause le fond est déjà de la voix) → « pas assez de passages », une seule voix. Seuil borné à crête - 20 dB.
- Fait : voix principale presque vide après le modèle backs (voix doublée / en couches : « only time » → tout en
  backs) → toute la voix est gardée en voix principale.
- Crépitements — cause mesurée : les modèles travaillent à 44,1 kHz ; à 48 kHz (téléphones, PC) la page convertissait
  avec OfflineAudioContext + AudioBufferSourceNode = interpolation linéaire. Aller-retour 48 → 44,1 → 48 kHz mesuré
  dans Chromium : 8 kHz -1,7 dB et distorsion -21,8 dB ; 12 kHz -3,9 dB / -15,8 dB ; 16 kHz -6,8 dB / -12,3 dB.
  Jamais vu en essai : la CI tournait à 44,1 kHz (pas de conversion). Fait : `resample.js` (sinc, fenêtre de Kaiser,
  polyphase) : gain ±0,001 dB, distorsion < -95 dB jusqu'à 18 kHz, ~20 ms par seconde de son ; utilisé par « Séparer »
  et par l'isolation de prise ; l'instru est maintenant calculée à la fréquence d'origine (morceau d'origine − voix) ;
  essai `web/test/resample.mjs` + séparation de la CI passée à 48 kHz (`?svRate=48000`).
- Crépitements — second levier, en option : « Finition soignée (2× plus long) » = débruitage du modèle (moyenne de
  modèle(x) et −modèle(−x), comme « Denoise » d'UVR). Mesuré sur le faux morceau : bruit aigu de la voix séparée
  -63,0 → -71,5 dB, dans les silences de la voix -65,1 → -85,1 dB, SDR inchangé (+0,06 dB), temps ×1,8. Sur un vrai
  chant : ce qu'il retire est à -35 dB sous la voix.
- Non vérifié : que ces deux points soient bien LE crépitement entendu par Yann (aucune écoute possible ici ; sur
  l'essai de séparation complet à 48 kHz, l'écart global avant / après n'est pas mesurable : l'erreur du modèle dans les
  aigus, -6 à -12 dB, domine) ; chanteurs sur le morceau de Yann ; deux voix simultanées (non séparables).
- À refaire par Yann : les pistes déjà séparées gardent le défaut → relancer « Séparer » sur le nouveau build.

## Toutes les pistes de voix au même niveau après mixage, même 40 voix principales (demande de Yann)

- Fait : `api.cpp` runBalance — sonie de chaque piste mesurée là où elle chante (porte BS.1770) ; les pistes « voix
  principale » sont ramenées chacune à la même sonie (médiane des voix principales), 1 seule voix principale = pas
  touchée ; les autres types se placent sous la voix principale par piste (deux backs sortent au même niveau) ;
  limites +12 dB (souffle) / -24 dB, piste trop loin signalée dans le rapport ; sert à la lecture Mix et à « Mixer la
  chanson » ; le curseur de volume de la piste s'ajoute par-dessus (réglage à la main gardé).
- Testé (`web/test/balance.mjs`, moteur WASM dans la page, ajouté à la CI) : 40 voix principales de -15 à +5 dB → écart
  20,0 dB avant, 0,29 dB après ; 2 backs à 15 dB d'écart → 0,02 dB, 7,0 dB sous la voix principale ; 2 voix principales
  simultanées → 0,13 dB ; 1 seule → 0,00 dB de correction ; piste à -30 dB → +12 dB et signalée. Non-régression : démo
  PC + Pixel 7, micro + radio, séparation (mix -14,1 LUFS).
- À savoir : sur une chanson séparée, « Chanteur 1 » et « Chanteur 2 » sortent donc au même niveau, même si l'un était
  plus bas dans le morceau d'origine (curseur de volume pour le rebaisser).
- Vérifié sur de vraies voix (3 locuteurs LibriSpeech, 4 pistes « voix principale » importées avec 22,7 dB d'écart,
  traitées par la page) : niveau au Mix -27,9 LUFS sur les 4 ; mesure indépendante (RMS avec porte) : écart 0,8 dB.
- Fait : repère bleu sur le vumètre de chaque piste = son niveau au Mix (aligné d'une piste à l'autre quand elles sont
  égales) ; ligne de la piste « niveau au mix -27,9 LUFS (auto -18,7 dB) ». La barre du vumètre reste la crête
  instantanée : elle bouge avec ce que chaque voix dit, c'est le repère bleu qui montre l'égalité.
- Vérifié après une séparation (e2e, ajouté à l'essai de séparation) : « Chanteur 1 » -16,9 et « Chanteur 2 » -18,1 LUFS
  sortent tous deux à -21,3 LUFS au Mix ; « Backs » -33,4 → -28,3 LUFS (7 LU sous la voix principale).
- Limite : la séparation distingue au plus 2 chanteurs (3 chanteurs ou plus sont regroupés en 2 pistes).
- Non vérifié : à l'oreille (aucune écoute possible ici).

## Séparer sur téléphone : « je vois pas s'il travaille », « la progression n'avance pas » (retours de Yann, Android / Brave)

- Constat (capture build 109, chanson 3:35) : « IA : session webgpu prête en 3023 ms » puis aucun morceau fini en 3 min 33
  → la carte graphique du téléphone bloque au 1er calcul du modèle. Sur PC (WASM 3 fils) : ~12 s par morceau de 6 s,
  50 morceaux par étape pour 3:35 → ~30 min pour 3 étapes.
- Fait : bloc de progression dans la carte Séparation (étape, morceau n/N, durée mesurée par morceau, barre au dixième
  de %, avancée estimée entre deux morceaux, temps écoulé / restant, ligne « IA : … » = ce que fait le worker, roue,
  % dans l'onglet, alerte seulement si plus lent que prévu) ; bouton « Arrêter la séparation » avec confirmation ;
  avertissement avant de quitter la page ; essai carte graphique limité à 20 s → worker relancé en processeur seul,
  choix retenu sur l'appareil (`sv-no-webgpu`) ; morceaux sans signal sautés (backs : -45 dB, voix/instru : -60 dB) ;
  écran gardé allumé (Wake Lock) ; reprise après coupure : chaque étape finie gardée (IndexedDB « meta/sepcache »),
  relue à la relance, effacée après réussite ; durée estimée avant de lancer (vitesse mesurée de l'appareil retenue).
- Écarté après mesure : modèle quantifié int8 (dynamique) : pas plus rapide (6,0 s contre 5,8 s par morceau, ORT CPU)
  et sortie faussée.
- Vérifié par Yann sur son téléphone (Android / Brave, build 111, chanson 3:35) : séparation allée au bout en ~45 min ;
  chaque voix sur sa piste, backs sur leur piste, instrumental « plutôt propre ».
- Point de sauvegarde : commit 865ef8b = build 111 en ligne (tests locaux + CI passés).
- À faire (retour de Yann) : petits nettoyages restants sur l'instrumental séparé ; durée (45 min) à réduire ;
  problème à préciser sur la touche de lecture « Mix ».
- Vérifié par Yann : l'écran est resté allumé pendant toute la séparation (Wake Lock).
- Fait (demande de Yann) : cadenas 🔒 par piste (en-tête, à côté de FX) : piste verrouillée = glisser la prise ne la
  déplace plus (message dans la barre d'état, le geste place seulement la tête de lecture) ; pistes séparées
  verrouillées d'office (anciens projets compris) ; état gardé dans la sauvegarde. Testé e2e PC + Pixel 7 (verrouillée :
  reste à 0,00 s ; déverrouillée : déplacée) et séparation (pistes créées verrouillées).
- Non vérifié : calcul écran éteint / page en arrière-plan sur le vrai téléphone (son de veille, pas essayé) ; Brave isolé ou non (multi-cœur) ;
  recouvrement 0,1 (4:34 contre 5:07 en local, instru identique 16,3 dB) : effet sur backs / voix principale non mesuré.

## Séparer une chanson en pistes (demande de Yann : instru propre, chaque voix / back / ambiance / chanteur sur sa piste)

- Fait (build 99) : `isolate.js` MODELS (voc, kara = UVR_MDXNET_KARA_2, reverb = Reverb_HQ_By_FoxJoy, spk = WeSpeaker
  ResNet34) ; réglages UVR relevés par l'empreinte UVR (md5 des 10 derniers Mo) dans model_data_new.json ; formes
  d'entrée vérifiées ([4,2048,256], [4,3072,512]) ; `isolate-worker.js` une session par modèle, libérée après usage ;
  `singers.js` : phrases, fbank Kaldi 80 (comme WeSpeaker), empreinte par fenêtre de 3 s, regroupement, seuil de
  ressemblance 0,45 ; page : « ✂ Séparer la chanson », options, pistes créées « sans effet », bouton FX par piste,
  « Rétablir le morceau ». Essais : node sur faux morceau (instru 16,3 dB, backs 10,2, principale 17,8 ; zone sans voix =
  original à -46,9 dB) ; chanteurs : 5 cas justes (A/B, A×2, C, A/C, B/A/B ; même voix 0,57-0,64, voix différentes
  -0,01-0,19) ; e2e navigateur + CI (instru ≥ 10 dB, backs, 2 chanteurs, remixage).
- Écarté : timbre MFCC par phrase pour les chanteurs (même voix coupée en deux, deux voix non séparées).
- Non vérifié : ambiance (le modèle réverb n'a presque rien extrait sur deux réverbs de synthèse : à tester sur une vraie
  voix réverbérée) ; chant réel (essais sur de la parole) ; licence du modèle réverb (non indiquée) et des modèles UVR
  pour un usage commercial ; « Rétablir » perdu après rechargement (original non sauvegardé).

## Mixage final « Mixer la chanson » (demande de Yann : « tout mixer à juste niveau, l'instru aussi, une chanson unique »)

- Fait (build 97) : `sv_finalmix_end` (api.cpp) sur les pistes de `sv_balance_begin/add` : place par type (même calcul
  que la lecture, `runBalance` commun), bus voix `dsp::BusGlue` (réduction mesurée, rattrapage 0 à 4 dB), `autoMix`
  voix / instru avec creux 2,5 dB (case), `dsp::master` (couleur `masterTone` du style, cible de sonie, limiteur -1 dBTP) ;
  page : bouton, destination, case « Faire de la place à la voix », écoute A/B, export, chanson marquée périmée à chaque
  changement. Essais : node (Spotify -14,2 LUFS / -1,0 dBTP ; Apple -16,0 ; Fort : -10,5 au lieu de -9, limiteur
  18,8 dB, comme le logiciel PC) ; e2e démo : -14,1 LUFS, -1,1 dBTP, export.
- À faire : priorité réglable par piste (aujourd'hui type + fader) ; mastering par référence (morceau modèle) comme le
  logiciel PC ; export MP3.

## Prise sur téléphone : saccades, IA trop longue, « est-ce que ça marche ? » (retour de Yann)

- Fait (build 96) : l'IA n'est plus préparée pendant la prise (téléchargement 89 Mo + compilation pendant le REC = prise
  qui saccade sur téléphone) ; elle n'est lancée que si la prise contient encore un son extérieur : écart voix / fond
  (90e / 10e centile des tranches de 50 ms) < 25 dB (mesuré : radio au niveau de la voix 7,4 dB ; instru captée seule,
  retirée, 33,3 dB) ; sinon prise prête ~2 s après Stop au lieu de ~50 s (et plus propre : SDR 25,1 dB contre 21,8) ;
  temps restant affiché, bouton « Passer l'IA » ; « 🎙 Micro brut » par prise (ce que le micro a capté, pour comparer) ;
  onde en direct étiquetée « micro en direct — la musique des haut-parleurs sera retirée à l'arrêt ». CI : 3e essai micro
  sans radio (l'IA doit être sautée).
- Non fait : retrait de la musique EN DIRECT pendant la prise (affichage voix seule pendant le REC) : demande un
  annuleur d'écho temps réel (filtre adaptatif dans le worklet, référence = ce qui est joué) ; l'annulation d'écho du
  navigateur passe Android en mode « appel » (instru dégradée) : écartée.
- Le micro brut n'est pas gardé dans la sauvegarde du navigateur (taille) : bouton absent après rechargement.

## Musique extérieure dans le micro (retour de Yann : « même une musique extérieure doit être masquée, que la voix »)

- Fait (build 91, version web) : le retrait par référence ne traite que l'instru jouée par la page ; pour tout le
  reste, isolation de la voix par IA après lui : `web/isolate.js` (STFT façon torch, n_fft 7680 par Bluestein,
  segments de 256 trames, recouvrement 25 %, reprise fidèle de python-audio-separator), `web/isolate-worker.js`
  (ONNX Runtime Web 1.22.0, WebGPU puis WASM multi-cœur, sortie WebGPU contrôlée, modèle 66,8 Mo vérifié SHA-256 et
  gardé en Cache Storage), case « Isoler la voix (IA) » cochée par défaut, sur les prises et les voix importées,
  modèle préparé pendant la prise ; échec = prise gardée sans isolation et signalée (⚠). CI : `web/fetch-ia.sh`
  (cache), faux micro = vraie voix (JFK) + instru captée + « radio » inconnue ; prise mesurée contre la voix seule
  (échec si SDR < 10 dB). Mesures node (4 fils) : musique au niveau de la voix 0 → 18 dB, à −6 dB 6 → 19,6 dB,
  musique seule −55,7 dB, voix seule SDR 22,5 dB ; 37 s de calcul pour 11 s de prise (processeur).
- Non vérifié : WebGPU (pas de carte graphique ici : chemin processeur seul testé) ; vraie voix chantée de Yann dans
  sa pièce ; Firefox / Safari.
- À faire : même isolation dans le logiciel Windows (onnxruntime natif) si Yann garde l'exe ; si trop lent sans carte
  graphique : modèle plus léger ou traitement pendant la prise (par segments de 6 s).

## Niveau de la voix (question de Yann : « il se cale sur la voix la plus haute ? »)

- Fait (build 89) : cause = calage d'entrée et de sortie sur une moyenne d'énergie (tirée vers les passages forts) et
  niveleur limité à ±4 dB. Désormais `dsp::typicalLevelDb` / `gainForTypicalLevel` (médiane des tranches de voix) dans
  la chaîne vocale ; niveleur ±2 à ±10 dB (60 % de l'écart mesuré) avec seuil relatif `gateBelowMedianDb` 12 à 18 dB ;
  journal « Niveau d'entrée : typique … / moyenne d'énergie … ». Test : écart 20 dB → 5,7 dB, sortie calée sur sa cible.
  L'instru (correction automatique) garde l'ancien calage (`gainForActiveRms`, mix dense : médiane ≈ moyenne).
- À vérifier avec Yann sur sa voix : parlé fort / faible, puis chant ; ajuster le 60 % si le résultat est trop « plat ».

## Version web (demande de Yann : « plus de .exe, directement sur une page web »)

- Fait (build 84) : étape 1 — moteur C++ (JUCE core / events / audio_basics / audio_formats / dsp + cœur DSP, 25
  fichiers inchangés) compilé en WebAssembly par `web/build-wasm.sh` (Emscripten 3.1, juce_core patché pour la table
  des priorités WASM, `wcsftime` fourni) ; façade C `web/api.cpp` (styles, analyse instru, voix par style ajustée à la
  mesure, mix auto + limiteur) ; page `web/index.html` + `app.js` (Web Audio : instru, REC avec compte à rebours,
  style, A/B, vumètres, export WAV) ; moteur dans un Web Worker ; essai Playwright `web/test/e2e.mjs` (instru et voix
  de démo, style appliqué, WAV exporté) ; job CI « Web » → GitHub Pages.
- Mesuré (Chromium local) : moteur prêt en 8,5 s, analyse instru 39 s en 1,4 s, voix 28 s traitée en 4 s, WAV 6,9 Mo.
- À faire ensuite : plusieurs pistes (doublages, backs, instruments) et timeline ; punch-in / prises multiples ;
  « ⚠ » + Corriger ; correction automatique de l'instru à la demande ; mastering à l'export ; sauvegarde du projet
  dans le navigateur (OPFS / IndexedDB) ; IA dans le navigateur (whisper.cpp WASM pour les paroles, DeepFilterNet via
  onnxruntime-web ; Demucs trop lourd) ; latence micro mesurée automatiquement (boucle de calibrage) ; threads
  (SharedArrayBuffer) si le traitement devient long ; arrêt des builds .exe si Yann le confirme.

## Édition « StudioVoix IA » (builds 52 et suivants)

- Vérifier sur le PC de Yann : installation des outils (onglet IA locale), nettoyage DeepFilterNet sur une vraie prise,
  reconnaissance des paroles (whisper-cli + modèle base), mastering par référence à l'export. Les téléchargements et
  l'exécution réelle des outils sont impossibles depuis l'environnement de développement (réseau bloqué) ; seule la CI
  Windows a téléchargé les outils et relevé leurs empreintes.
- Demucs (séparation d'instru) : intégration faite (outil `demucs` + modèle `demucs-htdemucs` au catalogue, module
  `core/ai/Separate`, bouton dans IA locale, 4 pistes brutes créées, instru coupée). Binaire `demucs_mt.exe` compilé
  par la CI (build 64 : GCC MinGW 15.2, statique, x86-64-v2, 6 327 386 octets) et publié dans la release GitHub
  `outils-ia` ; taille et SHA-256 épinglés, comme ceux du modèle (83 994 361 octets). La CI ne recompile / republie
  que si l'asset manque ou si le commit contient `[demucs]` (ré-épingler alors l'empreinte). Historique des essais :
  58 CMake 4 ; 59 MSVC ; 60 PowerShell « =3.5 » ; 61 bash + Ninja ; 63 wavpack `<intrin.h>` ; 64 `path` → `string`.
  Exécution réelle vérifiée par la CI Windows (`studiovoix_cli outils-essai` sur la démo, build 66) : deep-filter OK
  (2,5 s), whisper-cli OK (4 s, 0 mot : voix de démo synthétique) ; demucs_mt OK (build 72 : 39,4 s d'audio séparées
  en 196,9 s sur 4 fils, variante compatible ; partie voix quasi muette sur une instru sans voix). Build 73 : deux
  variantes publiées (compatible x86-64-v2 et AVX2), choisies selon le processeur, empreintes épinglées ; l'étape
  d'essai réel est désormais bloquante. Reste à vérifier sur le PC de Yann : un vrai morceau (qualité de la
  séparation, vitesse réelle) ; parties en mono (prises du projet) — stéréo à envisager.
- Linux : les téléchargements d'outils échouent (JUCE sans curl) ; sans effet pour Windows, à activer (JUCE_USE_CURL)
  si une version Linux est un jour distribuée.

## Autres points en attente

- Écoute réelle par Yann des builds 43 à 47 : bus voix (colle 1 à 4 dB, rattrapage), chaîne visible par piste
  (cases, réglages, contournement), édition des blocs (rogner, fondus, couper), orchestre, niveleur, résonances.
- Vrai plugin VST3 sous Windows (hébergement testé seulement avec les effets intégrés).
- Chaîne visible : pas de cases sur une piste en correction automatique (réglages déduits de l'analyse, lisibles
  dans le rapport) ; à décider si les contournements doivent y être proposés aussi.
- Tests réels sur Windows : carte son, latence, recalage, écoute des traitements.
- Appels réels aux API Claude et ElevenLabs (avec clés).
- Export MP3 avec `lame.exe`.
- Réglages des styles à affiner à l'oreille (en particulier rock et latino, ajoutés sans écoute).

## Écartés pour l'instant (relecture de code, à décider)

- Clés API et jeton GitHub de mise à jour stockés en clair dans `%APPDATA%\StudioVoix\StudioVoix.settings` : les chiffrer avec DPAPI
  (Windows) serait plus sûr ; non fait (dépendance système et changement de format des réglages).
- Fermer l'application pendant une génération d'instru IA (jusqu'à plusieurs minutes) : la tâche n'est
  pas annulée proprement (risque de plantage à la fermeture, sans perte du projet).
- Volume, panoramique, muet et solo des pistes ne créent pas d'étape d'annulation.
- Fermeture de session Windows avec la fenêtre Paramètres ouverte : plantage possible à la fermeture.
- Tempo : erreurs de double / moitié / 2/3 sur certains tempos de synthèse (150 lu 75, 132 lu 88,
  175 lu 87,5, 60 lu 120). Le BPM se corrige à la main (clic sur le BPM). Correctif à valider sur de
  vrais morceaux (autocorrélation aux décalages fractionnaires) : le lissage testé cassait 160 BPM.
- « Meilleure prise par phrase » : les créneaux sont l'union des phrases de toutes les prises ; avec
  des prises complètes qui se recouvrent, une seule prise gagne tout le morceau (pas de vrai comping).
- Voix sous 70 Hz non suivie par la détection de hauteur (descendre à 55 Hz coûte +27 % de calcul).
