# Fiche 11 — Le caractère de chaque homme

- Morceau : 11. Table : `Scriptorium.caractere`. Fichier : `socle/pak/Scripts/scriptorium/caractere.lua`.
- Idée de JoVenGer du 15/10 : chaque homme est quelqu'un, avec des envies et des aptitudes différentes, comme un être
  « un peu intelligent ». Ses besoins et ses goûts guideront aussi ce que son cerveau choisit de faire (étape 1 du plan
  d'action, fiche 12 à venir).
- Choix de JoVenGer du 15/10 (questions à cocher), tous repris ci-dessous.
- État : écrit et passé au banc (`essais/lua/essai_caractere.lua`, quatorze essais). Rien ne parle au moteur : la veillée choisie part au jeu comme les autres activités. À voir en jeu : les hommes posés le soir au feu, à l'entraînement, aux dés ou au lit.

## Ce que le joueur voit
- Des hommes différents : un gros mangeur qui vide les vivres, un vite las qui traîne, un hardi qui tient la ligne, un
  buveur qui s'enivre, un qui aime les dés et passe ses soirées à jouer.
- Le caractère se **découvre avec le temps** : le rapport du Directeur (« Connaître ses hommes ») ne dit un trait qu'une
  fois qu'il s'est montré, en mots (« gros mangeur », « endurant », « apprend vite », « avisé », « hardi », « garde son
  sang-froid », « porté sur la boisson », « querelleur », « chapardeur », « aime les dés »…). Un trait ordinaire ne
  s'écrit pas. Le reste est dit « encore inconnu ».
- La fatigue (« fatigué », « épuisé ») et l'aguerrissement (« bleu », « vétéran ») s'y lisent aussi.

## Les traits (tirés à l'embauche)
- Notés de 0 à 100, 50 étant l'ordinaire, tirés au hasard **de 0 à 100** (extrêmes possibles) ; fourchette réglable.
- **Appétit, endurance, forme** (récupération), **don d'apprendre**, **jugement**, **courage**, **sang-froid**,
  **penchants** pour la boisson, la bagarre, le vol.
- **Envies** pour le temps libre : le feu, l'entraînement, les dés, le sommeil (chacune de 0 à 100).
- **Aguerrissement** de départ : de 10 à 40.
- Le hasard est celui du caractère (sa propre graine au registre) : il ne dérange pas celui des batailles.
- Ils s'ajoutent aux chiffres que le jeu donne déjà à chaque âme (force, agilité, vitalité, compétences).

## Ce que les traits changent
- **Appétit → ration** : ration × (0,5 à 1,5 selon l'appétit), arrondie, jamais moins d'un vivre : avec deux vivres
  de base, 1, 2 ou 3 vivres par jour.
- **Fatigue** (0 à 100), comptée chaque jour au repas du matin sur les vingt-quatre heures passées : chaque heure de
  travail (exercice, corvée, garde, patrouille, bataille, entraînement du soir) l'élève de 4 × (1,5 − endurance ⁄ 100) ;
  chaque heure de sommeil (ou de repos du blessé) l'abaisse de 10 × (0,5 + forme ⁄ 100) ; une bataille ajoute 20.
  Le compte : neuf heures de travail par jour, plus les tours de garde, contre sept heures de sommeil moins la garde de nuit.
  Un homme ordinaire d'une compagnie de dix perd ainsi une dizaine de points par jour (il reste reposé) ; un homme vite las
  et lent à se remettre se fatigue en une semaine. Le compte d'un jour commence au plus tôt à l'embauche.
  **Fatigué** à 70 : il se bat 15 % moins bien. **Épuisé** à 90 : 30 % moins bien, moral − 2 chaque jour, et il va au lit
  dès son temps libre.
- **Forme → soins** : les jours de soin ôtés chaque jour (1, ou 2 avec un barbier) sont multipliés par 0,5 à 1,5 selon la
  forme ; les fractions s'additionnent d'un jour à l'autre.
- **Don d'apprendre → aguerrissement** (0 à 100) : chaque heure d'exercice ou d'entraînement lui ajoute
  0,25 × (0,5 + don ⁄ 100) ; une bataille survécue, 4 × (0,5 + don ⁄ 100).
- **Au combat** (règle des batailles et des escarmouches), la force de l'homme est multipliée par : l'aguerrissement
  (0,8 pour un bleu à 0, 1,2 pour un vétéran à 100), le courage (0,85 à 1,15), la fatigue (1, 0,85 ou 0,7), en plus de
  l'usure de son équipement.
- **Jugement** : la chance de faute à l'aube est multipliée par 1,5 − jugement ⁄ 100 ; au combat, dans un même rang,
  l'homme de moindre jugement tombe le premier.
- **Sang-froid** : une perte de moral (revers, défaite) est multipliée par 1,5 − sang-froid ⁄ 100.
- **Penchants → fautes** : le poids de chaque faute pour cet homme est multiplié par son penchant ⁄ 50 (boisson → ivresse,
  bagarre → rixe, vol → vol ; l'exaction suit la moyenne de la bagarre et du vol). Un homme sans aucun penchant ne
  commet pas de faute de cette sorte.

## Le temps libre
- La veillée (19 h à 22 h) est son temps libre. L'épuisé va au lit. Sinon, chaque soir, il choisit selon ses envies,
  au hasard pondéré : **le feu** (un siège, sinon debout au feu), **le terrain d'entraînement** (il progresse un peu et se
  fatigue), **les dés** (un coin près du feu), ou **dormir tôt** (sa paillasse).
- Le choix d'un soir est gardé : il ne change pas au cours de la soirée. Il est donné au jeu comme les autres activités ;
  quand le cerveau existera, c'est lui qui le suivra (en attendant, l'homme est posé à l'endroit choisi).

## L'évolution (lente)
- L'entraînement renforce : + 0,1 d'endurance par heure d'exercice ou d'entraînement (près de trois points par semaine).
- La faim affaiblit : un jour affamé, − 1 de forme et − 0,5 d'endurance. Une blessure reçue (bataille, rixe) : − 1 de forme.
- Les traits restent entre 0 et 100.

## La découverte
- Appétit, endurance, forme et envies : après **sept jours** au camp.
- Don d'apprendre : après **sept jours d'exercice**.
- Courage, sang-froid, jugement : à sa **première bataille** ou escarmouche.
- Un penchant : à la **première faute** qu'il lui fait commettre (ivresse → boisson, rixe → bagarre, vol → vol), sinon
  après **trente jours**.
- Chaque découverte est notée au journal.

## Plus tard (choix de JoVenGer)
- Le Directeur et les ennemis recevront leur caractère avec leur cerveau (étape 1 du plan d'action).
- Quand le cerveau marchera, l'entraînement fera aussi monter les compétences du jeu de l'homme (épée, arc, défense…),
  par `soul:AddSkillXP`.

## Réglages (`caractere.reglages`, tous dans le catalogue des réglages par fichier)
`trait_min` 0, `trait_max` 100, `aguerri_min` 10, `aguerri_max` 40, `appetit_facteur_min` 0,5, `appetit_facteur_max` 1,5,
`fatigue_par_heure` 4, `repos_par_heure` 10, `fatigue_bataille` 20, `seuil_fatigue` 70, `seuil_epuise` 90,
`malus_fatigue` 0,85, `malus_epuise` 0,7, `moral_epuise` − 2, `gain_par_heure` 0,25, `gain_bataille` 4,
`aguerri_facteur_min` 0,8, `aguerri_facteur_max` 1,2, `courage_facteur_min` 0,85, `courage_facteur_max` 1,15,
`endurance_par_heure` 0,1, `faim_forme` − 1, `faim_endurance` − 0,5, `blessure_forme` − 1, `jours_pour_connaitre` 7,
`jours_pour_les_penchants` 30, `seuil_faible` 35, `seuil_fort` 65, `seuil_bleu` 30, `seuil_veteran` 70.

## Ce qui est sauvegardé (case `caractere`, version 1)
`{ graine, hommes = { [id] = { traits, envies, connus, fatigue, aguerri, soin_reste, jours, jours_exercice, soir } } }`.
Un homme parti est oublié.

## Ce que le morceau demande au jeu
Rien : il passe par les hommes (activités, rations, soins), la bataille et la discipline ; `journal`.

## Liens avec les autres morceaux
- Hommes : tirage à l'embauche, ration, soins, compte du jour, temps libre, oubli au départ, moral selon le sang-froid.
- Bataille : force au combat, ordre de chute, retour d'une bataille (fatigue, aguerrissement, découverte, forme des blessés).
- Discipline : chance de faute, poids des fautes, découverte des penchants, forme du blessé d'une rixe.
- Directeur : entrée « Connaître ses hommes » de la Gestion du camp.

## Essais au banc (`essais/lua/essai_caractere.lua`)
Tirage dans les fourchettes et graine propre ; ration selon l'appétit ; fatigue d'une journée selon endurance et forme,
seuils et moral de l'épuisé ; une semaine ordinaire laisse un homme ordinaire d'une compagnie de dix sous 50 de fatigue ; soins selon la forme ; aguerrissement selon le don ; force au combat ; ordre de chute ;
sang-froid ; chance et poids des fautes ; temps libre (épuisé au lit, choix gardé pour la soirée) ; évolution ;
découvertes ; rapport en mots ; oubli au départ ; écriture puis relecture.
