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
- Si les « trous » dans l'instru persistent : passer le ducking par défaut à 0 dB (actuellement 2,5 dB, réglable dans
  Mix & Master) et demander le fichier `%APPDATA%\StudioVoix IA\logs\app.log` pour voir les décrochages du moteur
  temps réel (lignes `[Moteur]` / `xrun`).
- À faire selon le prochain retour : panneau « Piste » adapté à l'instru (remplacer, séparer, caler) ; bouton
  « Séparer » visible sur l'en-tête de l'instru ; sélection du style directement dans l'en-tête de piste ; réduire la
  barre du haut (Nouveau / Ouvrir / Sauver dans l'accueil) ; glisser-déposer d'un fichier sur une piste existante.

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
