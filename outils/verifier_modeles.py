"""Vérifie que chaque modèle du jeu de base appelé par le socle existe dans les paks du jeu (lecture seule).

Usage (sur le PC de JoVenGer) :
    py -3.13 outils/verifier_modeles.py --jeu "G:\\SteamLibrary\\steamapps\\common\\KingdomComeDeliverance2"

Lit les chemins « chemin = "…" » des morceaux du socle (camp.lua, enceinte.lua) et les cherche, sans tenir
compte des majuscules, parmi les fichiers des paks de <jeu>\\Data. N'écrit rien, n'extrait rien.
Un modèle introuvable donne une forme blanche en jeu (vu le 14/10).
"""

import glob
import os
import re
import sys
import zipfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MORCEAUX = [os.path.join(RACINE, "socle", "pak", "Scripts", "scriptorium", nom) for nom in ("camp.lua", "enceinte.lua")]
MOTIF_CHEMIN = re.compile(r'(\w+)\s*=\s*\{\s*chemin\s*=\s*"([^"]+)"')


def modeles_du_socle():
    modeles = []
    for chemin in MORCEAUX:
        with open(chemin, "r", encoding="utf-8") as fichier:
            for sorte, modele in MOTIF_CHEMIN.findall(fichier.read()):
                modeles.append((os.path.basename(chemin), sorte, modele))
    return modeles


def fichiers_des_paks(jeu):
    noms = set()
    for pak in glob.glob(os.path.join(jeu, "Data", "*.pak")):
        try:
            with zipfile.ZipFile(pak) as archive:
                noms.update(nom.lower().replace("\\", "/") for nom in archive.namelist())
        except zipfile.BadZipFile:
            continue
    return noms


def principal(arguments):
    if "--jeu" not in arguments or arguments.index("--jeu") + 1 >= len(arguments):
        print(__doc__)
        return 2
    jeu = arguments[arguments.index("--jeu") + 1]
    if not os.path.isdir(os.path.join(jeu, "Data")):
        print("REFUS : dossier du jeu introuvable : " + jeu)
        return 2
    noms = fichiers_des_paks(jeu)
    manquants = 0
    for morceau, sorte, modele in modeles_du_socle():
        present = modele.lower().replace("\\", "/") in noms
        if not present:
            manquants += 1
        print("%s %s / %s : %s" % ("trouvé    " if present else "INTROUVABLE", morceau, sorte, modele))
    print("Modèles : %d introuvable(s)" % manquants)
    return 1 if manquants else 0


if __name__ == "__main__":
    sys.exit(principal(sys.argv[1:]))
