# À faire

## Guide d'installation du matériel (demandé par Yann)

Le programme ne dépend d'aucun micro ni casque particulier : entrées et sorties se choisissent dans
**Paramètres** et varient d'un utilisateur à l'autre. Le guide d'installation devra expliquer, avec de
belles illustrations soignées (schémas de branchement) :

- **Matériel conseillé** par budget :
  - micro USB avec prise casque intégrée (retour direct) ;
  - interface audio USB + micro XLR (cardioïde, filtre anti-pop) ;
  - casque fermé filaire (pas de Bluetooth : 100 à 300 ms de latence, inutilisable pour enregistrer).
- **Branchements pour la latence minimale** :
  - casque branché sur le micro USB ou sur l'interface (retour direct = 0 ms), écoute logicielle désactivée ;
  - entrée et sortie sur le même appareil (une seule horloge) ;
  - port USB direct sur le PC (pas de hub), pilote WASAPI exclusif (ou ASIO de l'interface).
- **Son le plus propre et le plus direct** :
  - distance bouche-micro, filtre anti-pop, pièce traitée (couvertures, mousse) ;
  - réglage du gain avec le « Test du niveau du micro » (crêtes entre −12 et −6 dBFS) ;
  - calibrage de la latence une fois par matériel.
- **Schémas** : 1) micro USB + casque sur le micro ; 2) interface + micro XLR + casque sur l'interface ;
  3) ce qu'il ne faut pas faire (Bluetooth, casque sur le PC avec écoute logicielle, hub USB).

## Autres points en attente

- Tests réels sur Windows : carte son, latence, recalage, écoute des traitements.
- Appels réels aux API Claude et ElevenLabs (avec clés).
- Export MP3 avec `lame.exe`.
- Réglages des styles à affiner à l'oreille (en particulier rock et latino, ajoutés sans écoute).
