# Fiche 20 — Les paroles des hommes (répliques, conversations, dialogue vers Henry)

Source : la demande du pair (17/10) : deux choses de Scriptorium qui marchent aujourd'hui passent par des globales du
mod d'Alex (principe seulement) : un homme dit une ligne de dialogue de Scriptorium (ses alias « scr_… »), et deux
hommes se parlent ; l'arbre de chaque homme lit une demande posée pour lui, la joue une fois, puis l'efface. Formes
réelles des nœuds, relevées dans les arbres du jeu (`Scripts.pak`, lecture seule) : `AI/battle/battleLadderController.xml`
et `AI/carts/carts.xml` ; définitions dans `AI/speech/schedulermonolog.xml`, `schedulerpolylog_initiator.xml`,
`dialoginitiator.xml`.

Comportement :
- `hommes.dire_une_replique(id, { alias | metarole, regard_henry })` : `Function_speech_schedulerMonolog` (alias, ou
  metarole sans alias ; l'animation de dialogue coupée ; regard vers Henry si demandé).
- `hommes.conversation(id, partenaire, { alias | metarole })` : `Function_speech_schedulerPolylog_initiator`,
  l'initiateur et son partenaire (un autre homme de la Compagnie).
- `hommes.dialogue_force(id, alias)` : `Function_speech_dialogInitiator`, un dialogue du jeu vers Henry.
- **Le personnel mené** (demande du pair, 20/10, séance J : « réplique pour un inconnu », le forgeron qui crie sa
  marchandise, les dames du camp en conversation) : `hommes.dire_une_replique_du_personnage(personnage, quoi)` et
  `hommes.conversation_du_personnage(personnage, partenaire, quoi)`, par le nom de l'entité ; le partenaire est un
  mené ou un homme de la Compagnie (trouvé par son personnage). Mêmes règles que pour un homme (jouée une fois, pas en
  route, jamais au lit ni en combat). Refus : `pas_mene` (ni mené ni de la Compagnie : sans notre cerveau, il ne peut
  rien dire par nous), `partenaire_invalide`. Essai (vérifié qu'il échoue sans) ; non vu en jeu.
- La demande devient l'activité « parole » (ordre 23) : l'arbre la joue une fois, compte une parole jouée, et l'homme
  reprend sa journée au battement suivant. Une demande nouvelle remplace la précédente.
- **Jamais en combat, en bataille ni au lit** : la décision remplaçable `hommes.peut_parler(id, parole)` (par défaut :
  ni occupé en combat, ni tenu par la bataille, ni au sommeil) ; sinon la demande attend. Une demande qui attend plus de
  `parole_attente_max_h` heures du jeu est oubliée (une ligne au journal).
- **Pas en route** (choix du pair, 20/10, vu sur une copie : deux porteurs tenaient une conversation au lieu de porter
  leur corps) : une parole non urgente attend que l'homme soit arrivé à son but (à moins de
  `hommes.reglages.secours_arrivee_m`) ; la ronde et la suite, qui n'arrivent jamais, n'attendent pas ; une parole
  urgente (l'alerte) passe toujours. Essai (vérifié qu'il échoue sans) ; non vu en jeu.
- **Jamais devant une règle plus forte que celle de Scriptorium** (vu sur une copie de la partie de JoVenGer le 21/10,
  J3 : une parole coupait neuf fois la colonne d'une mission ; décision de JoVenGer par le pair) : une parole non
  urgente attend tant que l'homme est tenu par une règle de rang plus petit que `hommes.reglages.parole_rang_min` (3,
  le rang de la règle de Scriptorium : bataille, mission, escorte, rassemblement) ; les conversations du camp tenues
  par Scriptorium passent. Une parole urgente passe toujours. Essai (vérifié en échec sans) ; non vu en jeu.
- La parole n'est pas une tenue : elle remplace l'activité le temps d'être dite, puis l'homme reprend ce que dit sa
  tenue la plus forte, qui n'a pas bougé.
- Une demande n'est pas gardée au registre (une parole n'a de sens que sur le moment).
- Réponses prises d'office : une seule demande à la fois par homme ; la conversation se joue depuis l'initiateur seul (le
  jeu y fait entrer le partenaire).

**Vu en jeu le 17/10** : la réplique (en regardant Henry) et la conversation : la demande donne l'ordre 23, l'arbre
joue le nœud de parole du jeu, le compteur avance, le socle dit « a dit » et l'homme reprend sa journée. **Aucune
ligne n'a été dite** : le metarole d'essai « GOSSIP » est muet pour nos âmes, et les alias de Scriptorium (« scr_… »)
sont dans ses tables, absentes du socle d'essai : la ligne entendue et sous-titrée se vérifiera après la bascule.
Corrigé en jeu : l'ordre de parole tombait dans « sans but » (pas de position) ; sa branche passe avant ce test. Le
dialogue vers Henry (sorte 3), essayé le 18/10 (metarole « GOSSIP ») : la demande va de bout en bout (ordre 23,
nœud joué, « a dit »), **aucun dialogue ne s'ouvre** (même limite : pas de dialogue du jeu pour nos âmes) ; à vérifier
après la bascule, avec les dialogues de Scriptorium.
- **Les paroles du Directeur** (vu sur une copie de la partie de JoVenGer le 21/10, J11 : « réplique refusée pour
  Scriptorium_Directeur : pas_mene ») : `directeur.dire_une_replique(quoi)` et `directeur.conversation(partenaire,
  quoi)`, ou les deux services par nom d'entité (`hommes.dire_une_replique_du_personnage`,
  `hommes.conversation_du_personnage`) qui le reconnaissent. Mêmes règles que pour un homme : jouée une fois par l'ordre
  « parole », puis oubliée (sa tâche lui est redonnée) ; jamais au sommeil (sauf urgente) ni en combat ; oubliée après
  `parole_attente_max_h`. Essai (vérifié en échec sans) ; non vu en jeu.
- **Les provocations des pillards** (demande du pair, 21/10, J14 ; vu dans les journaux de J4 et J5 : neuf demandes de
  Scriptorium, aucune dite, « pas_mene ») : `bataille.dire_une_replique(personnage, quoi)`, aussi par
  `hommes.dire_une_replique_du_personnage` avec le nom d'entité de l'ennemi : un ennemi debout d'une bande au contact dit
  sa réplique (alias ou metarole) par l'ordre « parole » de notre arbre ; il ne se bat pas tant qu'il la dit ; dite, ou
  attendue plus de `bataille.reglages.parole_ennemi_max_h` (0,05 h), l'attaque lui est redonnée. Refus : `hors_bataille`
  (alors, comme avant, « pas_mene »), `ennemi_a_terre`, `parole_invalide`. Essai (vérifié en échec sans) ; non vu en jeu.
