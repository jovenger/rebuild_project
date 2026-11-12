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
