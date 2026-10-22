# Déclencheurs des services jamais vus avec Scriptorium (20/10/2026)

Pour aller vite (demande de JoVenGer, relayée par le pair) : une ligne Lua par service, à lancer par `dire.py` dans une
COPIE de la partie (jamais playline1), séance ouverte. Lues dans le code de 457cb10 ; aucune lancée en jeu à ce jour.
Chaque ligne écrit son résultat au journal (« [Scriptorium] essai … ») ; un service rend l'id, ou (false, raison).
`H.liste()[1]` : le premier homme de la Compagnie (à remplacer par l'id voulu).

1. Mission vers un lieu du socle (butte_des_archers, colline_de_vysoka, chemin_des_convois, fosse_de_l_est…) :
   `local H,M=Scriptorium.hommes,Scriptorium.missions; local l=H.liste(); local a,b=M.prendre_une_mission({lieu="butte_des_archers", hommes={l[1],l[2],l[3]}}); Scriptorium.jeu.journal("essai mission : "..tostring(a).." "..tostring(b))`
   — signe : « Missions : « <id> » partie vers » ; peut_partir de Scriptorium (jour de repos) peut refuser.
2. Camp de bandits (petit 4, moyen 7, grand 10) :
   `local a,b=Scriptorium.missions.dresser_un_camp("butte_des_archers","petit"); Scriptorium.jeu.journal("essai camp : "..tostring(a).." "..tostring(b))`
   — signes : « Missions : camp « <id> » dressé à », « … meublé » ; combat à moins de 35 m.
3. Convoi (missions.routes est vide sans les routes de Scriptorium) :
   `local M=Scriptorium.missions; M.ajouter_une_route("route_d_essai","kutnohorsko",{{x=2620,y=918,z=91},{x=2214,y=1198,z=105}}); local a,b=M.lancer_un_convoi("route_d_essai","petit"); Scriptorium.jeu.journal("essai convoi : "..tostring(a).." "..tostring(b))`
   — signe : « Missions : convoi « <id> » parti sur ».
   Mission contre ce convoi : `local H,M=Scriptorium.hommes,Scriptorium.missions; local l=H.liste(); local a,b=M.prendre_une_mission({convoi="<id>", hommes={l[1],l[2],l[3]}}); Scriptorium.jeu.journal("essai mission convoi : "..tostring(a).." "..tostring(b))`
4. Désertion à l'aube (moral à 0, puis l'horloge au-delà de 5 h) :
   `local H=Scriptorium.hommes; local a,b=H.changer_moral(H.liste()[1],-100); Scriptorium.jeu.journal("essai moral : "..tostring(a).." "..tostring(b))`
   — signe à l'aube : « Hommes : « <nom> » parti (desertion) ».
5. Mort (la voie de la bataille, corps laissé) :
   `local H=Scriptorium.hommes; local a,b=H.retirer(H.liste()[1],"mort"); Scriptorium.jeu.journal("essai mort : "..tostring(a).." corps "..tostring(b))`
   — signe : « Hommes : « <nom> » parti (mort) ». Non vérifié : aucune détection d'une mort HORS bataille trouvée dans
   le code (seule la bataille lit personnage_mort de ses combattants) ; à provoquer en J3.
6. Renvoi : `local H=Scriptorium.hommes; local a,b=H.renvoyer(H.liste()[1]); Scriptorium.jeu.journal("essai renvoi : "..tostring(a).." "..tostring(b))`
   — signe : « Hommes : « <nom> » parti (renvoye) ».
7. Blessure puis guérison :
   `local H=Scriptorium.hommes; local a,b=H.blesser(H.liste()[1],3); Scriptorium.jeu.journal("essai blessure : "..tostring(a).." "..tostring(b))` ;
   `local H=Scriptorium.hommes; H.guerir(H.liste()[1],3)` — signe : « Ordre à <id> : repos (<son lit>) ».
   Lire une fiche : `local f=Scriptorium.hommes.fiche(Scriptorium.hommes.liste()[1]); Scriptorium.jeu.journal("fiche : "..f.nom.." moral "..f.moral.." blessure "..f.blessure)`
