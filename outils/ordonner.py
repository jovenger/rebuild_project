"""Écrit un ordre pour le poste d'essai du socle, sans passer par la console du jeu.

Usage (sur le PC de JoVenGer) :
    py -3.13 outils/ordonner.py --jeu "G:\\SteamLibrary\\steamapps\\common\\KingdomComeDeliverance2" scriptorium_essai_bandeau
    py -3.13 outils/ordonner.py --liste      les commandes connues du poste

Le fichier écrit est <jeu>\\Mods\\scriptorium_socle\\ordres.lua. Il ne contient que des données :
    return { numero = N, commande = "scriptorium_…" }
Le poste du socle le relit toutes les deux secondes et exécute un ordre neuf une seule fois, en partie.

Garanties :
- n'écrit que dans <jeu>\\Mods\\scriptorium_socle, par les mêmes refus que noyau/installer.py, et seulement
  si le socle y est installé ;
- refuse une commande que le poste ne connaît pas (liste lue dans poste.lua) ;
- écrit d'abord un fichier provisoire puis le met en place d'un coup : le jeu ne lit jamais un ordre à moitié écrit.
"""

import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POSTE = os.path.join(RACINE, "socle", "pak", "Scripts", "scriptorium", "poste.lua")
NOM_DU_FICHIER = "ordres.lua"

sys.path.insert(0, os.path.join(RACINE, "noyau"))
import installer  # noqa: E402

MOTIF_COMMANDE = re.compile(r'\{ nom = "(scriptorium_[a-z_]+)"')
MOTIF_NUMERO = re.compile(r"numero = (\d+)")


def commandes_du_poste():
    with open(POSTE, "r", encoding="utf-8") as fichier:
        return MOTIF_COMMANDE.findall(fichier.read())


def contenu(numero, commande):
    return 'return { numero = %d, commande = "%s" }\n' % (numero, commande)


def numero_suivant(chemin):
    if not os.path.exists(chemin):
        return 1
    with open(chemin, "r", encoding="ascii", errors="replace") as fichier:
        trouve = MOTIF_NUMERO.search(fichier.read())
    return int(trouve.group(1)) + 1 if trouve else 1


def ecrire(dossier, commande):
    chemin = os.path.join(dossier, NOM_DU_FICHIER)
    numero = numero_suivant(chemin)
    provisoire = chemin + ".provisoire"
    with open(provisoire, "wb") as fichier:
        fichier.write(contenu(numero, commande).encode("ascii"))
    os.replace(provisoire, chemin)
    return numero, chemin


def principal(arguments):
    connues = commandes_du_poste()
    if "--liste" in arguments:
        for nom in connues:
            print(nom)
        return 0
    if "--jeu" not in arguments or arguments.index("--jeu") + 1 >= len(arguments):
        print(__doc__)
        return 2
    position = arguments.index("--jeu")
    jeu = arguments[position + 1]
    reste = arguments[:position] + arguments[position + 2:]
    if len(reste) != 1:
        print(__doc__)
        return 2
    commande = reste[0]
    if commande not in connues:
        installer.refuser("commande inconnue du poste : %s (voir --liste)" % commande)
    cible = installer.verifier_cible(jeu)
    if not os.path.isfile(os.path.join(cible, "mod.manifest")):
        installer.refuser("le socle n'est pas installé dans " + cible)
    numero, chemin = ecrire(cible, commande)
    print("Ordre n° %d écrit : %s -> %s" % (numero, commande, chemin))
    return 0


if __name__ == "__main__":
    sys.exit(principal(sys.argv[1:]))
