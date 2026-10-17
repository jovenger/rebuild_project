"""Pose des copies de nos morceaux Lua dans le dossier du mod, pour le rechargement d'essai (V73 g 0, la sonde) : le
poste les relit dans le jeu ouvert par l'ordre scriptorium_essai_recharger, sans relancer le jeu.

Usage :
    py -3.13 outils/recharger.py --jeu "G:\\SteamLibrary\\steamapps\\common\\KingdomComeDeliverance2" hommes directeur
    py -3.13 outils/recharger.py --jeu "<jeu>" hommes --marque "sonde 1"   (une ligne au journal à la relecture)

Écrit <jeu>\\Mods\\scriptorium_socle\\recharge\\<morceau>.lua et liste.lua, par les mêmes refus que noyau/installer.py,
et seulement si le socle y est installé. Seuls les morceaux que le poste sait recharger sont acceptés (le poste refuse
de toute façon les autres).
"""

import os
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = os.path.join(RACINE, "socle", "pak", "Scripts", "scriptorium")
RECHARGEABLES = ("liaison", "coffre", "camp", "hommes", "bataille", "directeur", "enceinte", "atelier", "patrouilles",
                 "missions", "discipline", "caractere")

sys.path.insert(0, os.path.join(RACINE, "noyau"))
import installer  # noqa: E402


def ecrire_d_un_coup(chemin, octets):
    provisoire = chemin + ".provisoire"
    with open(provisoire, "wb") as fichier:
        fichier.write(octets)
    os.replace(provisoire, chemin)


def principal(arguments):
    if "--jeu" not in arguments or arguments.index("--jeu") + 1 >= len(arguments):
        print(__doc__)
        return 2
    position = arguments.index("--jeu")
    jeu = arguments[position + 1]
    reste = arguments[:position] + arguments[position + 2:]
    marque = None
    if "--marque" in reste:
        i = reste.index("--marque")
        if i + 1 >= len(reste):
            print(__doc__)
            return 2
        marque = reste[i + 1]
        reste = reste[:i] + reste[i + 2:]
        if not all(c.isalnum() or c in " -_" for c in marque):
            installer.refuser("marque refusée (lettres, chiffres, espaces, tirets)")
    if not reste:
        print(__doc__)
        return 2
    for nom in reste:
        if nom not in RECHARGEABLES:
            installer.refuser("morceau non rechargeable : %s" % nom)
    cible = installer.verifier_cible(jeu)
    if not os.path.isfile(os.path.join(cible, "mod.manifest")):
        installer.refuser("le socle n'est pas installé dans " + cible)
    dossier = os.path.join(cible, "recharge")
    os.makedirs(dossier, exist_ok=True)
    for nom in reste:
        with open(os.path.join(SOURCES, nom + ".lua"), "rb") as fichier:
            octets = fichier.read()
        if marque:
            octets += ('\nScriptorium.jeu.journal("Rechargement : %s relu (%s)")\n' % (nom, marque)).encode("utf-8")
        ecrire_d_un_coup(os.path.join(dossier, nom + ".lua"), octets)
        print("posé : %s" % os.path.join(dossier, nom + ".lua"))
    liste = "return { " + ", ".join('"%s"' % nom for nom in reste) + " }\n"
    ecrire_d_un_coup(os.path.join(dossier, "liste.lua"), liste.encode("ascii"))
    print("liste : %s" % ", ".join(reste))
    return 0


if __name__ == "__main__":
    sys.exit(principal(sys.argv[1:]))
