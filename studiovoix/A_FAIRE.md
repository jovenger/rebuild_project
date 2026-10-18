# À faire

## Guide d'installation du matériel

Fait : [docs/GUIDE_MATERIEL.md](docs/GUIDE_MATERIEL.md) avec 4 schémas (micro USB, interface + XLR,
montages à éviter, placement et niveau). À relire par Yann ; les modèles cités en exemple sont à
revérifier au moment de l'achat. StudioVoix utilise WASAPI (pas d'ASIO dans cette version).

## Audit studio

Voir [docs/AUDIT_STUDIO.md](docs/AUDIT_STUDIO.md) : ce qui manque par rapport à un vrai programme de studio,
comment les automatismes doivent être faits, ordre proposé.

## Édition « StudioVoix IA » (builds 52 et suivants)

- Vérifier sur le PC de Yann : installation des outils (onglet IA locale), nettoyage DeepFilterNet sur une vraie prise,
  reconnaissance des paroles (whisper-cli + modèle base), mastering par référence à l'export. Les téléchargements et
  l'exécution réelle des outils sont impossibles depuis l'environnement de développement (réseau bloqué) ; seule la CI
  Windows a téléchargé les outils et relevé leurs empreintes.
- Demucs (séparation d'instru) : intégration faite (outil `demucs` + modèle `demucs-htdemucs` au catalogue, module
  `core/ai/Separate`, bouton dans IA locale, 4 pistes brutes créées, instru coupée). Binaire : compilation de
  demucs.cpp en CI avec le GCC MinGW de l'image Windows (build 58 : CMake 4 ; 59 : MSVC refuse les drapeaux GCC ;
  60 : PowerShell coupait « =3.5 » ; 61 : bash + Ninja ; 63 : wavpack `<intrin.h>` corrigé, reste une conversion
  `path` → `string` dans demucs_mt.cpp, corrigée au build 64). Dès qu'elle réussit, la CI publie `demucs_mt.exe` dans
  la release GitHub `outils-ia` (adresse déjà épinglée dans le catalogue) et le relevé d'empreintes suivant donne la
  taille et le SHA-256 du binaire à épingler (modèle déjà épinglé : 83 994 361 octets). Non vérifié : exécution réelle de demucs_mt (PC de Yann) ; parties en
  mono (les prises du projet sont mono) — stéréo à envisager.
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
