# Protocole d'écoute — StudioVoix Web

Ce que les essais automatiques ne peuvent pas juger : **le son, à l'oreille, sur un vrai téléphone**. Chaque essai
dit quoi faire, quoi écouter, et quoi renvoyer. Compter 30 à 40 minutes pour tout faire ; chaque essai peut se faire
seul.

Page : https://jovenger.github.io/rebuild_project/ — noter d'abord le **numéro de build** affiché en haut.

## Comment noter

Pour chaque défaut entendu, une ligne :

`essai · piste · instant (m:ss) · ce qu'on entend · note`

- note : **OK** (rien à dire), **gênant** (ça s'entend, on peut vivre avec), **bloquant** (inutilisable) ;
- mots utiles : craquement, souffle, voix qui pompe (le volume respire), voix métallique, voix étouffée, écho, saturation
  (grain sale), décalage (la voix n'est pas calée sur l'instru), reste de voix dans l'instru, trou dans le son ;
- **journal** : tout en bas de la page, « Réglages de prise, détail de la piste, journal ». Copier les lignes
  demandées (appui long sur le texte) : elles disent ce que le programme a mesuré et décidé.

Matériel : le téléphone, un casque ou des écouteurs filaires pour l'écoute (le haut-parleur du téléphone cache les
défauts), une chanson connue (MP3) de 3 à 4 minutes, une instru.

## 1. Prise au micro, corrigée toute seule

1. Importer l'instru. Armer la piste (●), **REC**, rapper ou chanter 30 secondes **sans casque** (l'instru sort du
   téléphone), arrêter.
2. Attendre la pastille « corrigée » sur la piste. Ne rien régler.
3. Écouter **▶ Brut** puis **▶ Mix**, au casque.

À écouter :
- en Mix, la voix est-elle propre quand elle monte (pas de craquement, pas de grain) ?
- le volume est-il régulier sans « pomper » ?
- reste-t-il de l'instru dans la voix (couper l'instru avec **M** sur la piste Instru) ?
- la voix est-elle calée sur l'instru ?
- sur du rap : la voix a-t-elle été « accordée » (effet robot) ? Elle ne doit pas l'être.

Refaire une prise **avec casque**, puis une prise **très près du micro en parlant fort**.

À renvoyer : la ligne du journal « … correction automatique finie … décisions du moteur … », et les lignes notées.

## 2. Voix lissée, style, inspection

1. Sur la prise de l'essai 1 : toucher la piste, partie « Effets de la piste ».
2. Basculer **Voix lissée** (oui / non) : écouter la différence en ▶ Mix.
3. Choisir un style dans la liste de la piste (par exemple Rap conscient, puis Trap) : écouter ; avec et sans Voix
   lissée.
4. **Inspecter** (bouton 🔍) : lire ce que le programme signale. Est-ce que cela correspond à ce qu'on entend ?
   Appuyer sur le bouton proposé (« Éteindre … ») et réécouter.
5. Revenir à **Correction**.

À écouter : craquements ou grain qui apparaissent avec un style ; écho ou réverb trop présents ; l'inspection
signale-t-elle un défaut qu'on n'entend pas, ou rate-t-elle un défaut qu'on entend ?

À renvoyer : le style, Voix lissée oui / non, le texte de l'inspection, les lignes notées.

## 3. Séparer une chanson

1. « Nouveau projet ». Poser la chanson sur la piste Instru. Lire la **durée estimée** affichée sous « Séparer la
   chanson » et la noter.
2. Laisser les cases comme elles sont (téléphone : mode rapide). **Séparer la chanson**, écran allumé, page ouverte.
   Noter la durée réelle.
3. Écouter l'instru seule (S sur la piste Instru), puis la voix seule, puis les deux.
4. Si le temps le permet : recommencer avec « Voix principale / backs » et « Une piste par chanteur » cochées, sur
   une chanson où une seule personne chante couplets et refrains, puis sur une chanson à deux voix.

À écouter :
- instru : restes de voix (où ?), sons métalliques, volume qui bouge, aigus étouffés sous la voix ;
- voix : restes de musique, voix métallique, trous ;
- pistes : une même personne est-elle bien sur **une seule** piste ? Deux personnes différentes sont-elles
  séparées ? (Deux voix proches peuvent rester ensemble : le noter.)

À renvoyer : les deux lignes du journal « Séparation — départ » et « Séparation — bilan », la durée estimée, la
durée réelle, le titre de la chanson, les lignes notées.

## 4. Montage au doigt

Sur une piste **déverrouillée** (cadenas 🔓) avec une prise :

1. Toucher la prise à un endroit, **✂ Couper**. Recommencer plus loin : trois bouts.
2. **Appui long** sur le bout du milieu → **Supprimer**. **↶ Annuler**, puis **↷ Rétablir**.
3. **Maintenir** un bout un quart de seconde puis le glisser sur une autre piste ; le lâcher.
4. Glisser un bout dans le temps ; rogner un bord avec une poignée jaune ; **🔍 +** pour zoomer, couper plus
   finement.
5. Appui long → **Muet**, **Inverser**, **Volume**, **Fondu d'entrée / de sortie** : écouter chacun.

À noter (pas seulement le son) :
- la page défile-t-elle au lieu de déplacer le bout ? Le menu s'ouvre-t-il quand on ne le veut pas ?
- les poignées sont-elles assez grosses pour le doigt ?
- après un geste, combien de temps avant que le son corrigé revienne ?
- entend-on un clic à l'endroit d'une coupe ou d'un fondu ?

## 5. Projet dans un fichier

1. **⬇ Enregistrer le projet** : le fichier `.studiovoix` arrive-t-il dans les téléchargements ? Noter sa taille.
2. **Nouveau projet**, puis **⬆ Ouvrir un projet** : choisir le fichier. Le projet revient-il à l'identique (pistes,
   montage, modes, cadenas) ?
3. Si possible : ouvrir le même fichier sur un autre appareil (ordinateur).

À renvoyer : appareil et navigateur, taille du fichier, ce qui manque ou diffère après ouverture, le message affiché
en cas de refus.

## 6. Mix final et export MP3

1. Avec au moins une voix principale et un back : **Mixer la chanson**, écouter « avant / après ».
2. « Écarts par type » : déplacer le curseur des backs, réécouter ▶ Mix.
3. **Exporter** en MP3 (« Chanson mixée »). Sur iPhone : le fichier s'enregistre-t-il, s'ouvre-t-il dans l'app
   Fichiers ou Musique, se lit-il jusqu'au bout ?
4. Écouter le MP3 au casque, puis sur le haut-parleur du téléphone, puis en voiture ou sur une enceinte.

À écouter : les backs sont-ils à leur place ? La voix est-elle devant sans écraser l'instru ? Y a-t-il de la
saturation dans les passages forts ? Le MP3 sonne-t-il comme la page ?

## Ce que je fais de tes retours

- un défaut **bloquant** est traité en premier, avec un essai automatique qui le reproduit quand c'est possible ;
- les lignes de journal me donnent ce que le programme a mesuré : sans elles je ne peux que deviner ;
- ce qui n'est pas vérifiable sans ton oreille reste marqué « non vérifié » dans le suivi tant que tu ne l'as pas
  écouté.
