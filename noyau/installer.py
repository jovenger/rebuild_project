"""Installe le socle dans le jeu, dans son mod d'essai à part : Mods\\scriptorium_socle.

Usage (sur le PC de JoVenGer) :
    py -3.13 noyau/installer.py --jeu "G:\\SteamLibrary\\steamapps\\common\\KingdomComeDeliverance2"
    options : --sans-verification   n'exécute pas essais/tout_verifier.py avant (déconseillé)
              --sans-mise-de-cote   ne garde pas l'ancien mod d'essai dans securite/

Garanties :
- n'écrit que dans <jeu>\\Mods\\scriptorium_socle ; refuse tout autre chemin ;
- refuse hors d'une séance ouverte par le programme Scriptorium (depuis la bascule du 19/10/2026, ce dossier est le mod
  de tous les jours de JoVenGer ; voir seance_ouverte) ;
- refuse en dur les dossiers du Scriptorium actuel, de sa copie de sécurité et des trois mods
  scriptorium, scriptorium_regles, scriptorium_lumiere, ainsi que Data\\ du jeu ;
- met de côté l'ancien mod d'essai dans securite/<date>/ avant de le remplacer ;
- garde le fichier de réglages du PC (reglages.lua, fiche 10) d'une installation à l'autre ;
- ne lance pas l'installation si la vérification complète échoue.
"""

import os
import shutil
import subprocess
import sys
import zipfile
from datetime import datetime

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOCLE = os.path.join(RACINE, "socle")
PAK = os.path.join(SOCLE, "pak")
TEXTES = os.path.join(SOCLE, "textes")
SECURITE = os.path.join(RACINE, "securite")

NOM_DU_MOD = "scriptorium_socle"
NOM_DES_REGLAGES = "reglages.lua"
LANGUES = {"fr": "French"}

DOSSIERS_INTERDITS = ["scriptorium", "scriptorium_regles", "scriptorium_lumiere"]
# Morceaux de chemin interdits, comparés en minuscules et avec des « / » : le Scriptorium actuel et sa copie de sécurité.
MORCEAUX_INTERDITS = ["desktop/scriptorium/", "desktop/scriptorium", "scriptorium v2"]


def refuser(message):
    print("REFUS : " + message)
    sys.exit(2)


# Après la bascule (19/10/2026) : Mods\scriptorium_socle est le mod de tous les jours de JoVenGer. Rien n'y est écrit
# hors d'une séance ouverte par le programme Scriptorium (outils_de_session/seance_du_socle.py « installer ») : le dernier
# dossier <Bureau>\Scriptorium_securite\*_seance_du_socle (ordre des noms, donc des dates) a un etat.txt dont la première
# ligne non vide est « en cours » (sinon « remise » ou « gardee » ; les anciens dossiers sans etat.txt : pas de séance).
SEANCES = os.path.join(os.path.dirname(RACINE), "Scriptorium_securite")
SUFFIXE_DES_SEANCES = "_seance_du_socle"


def seance_ouverte(dossier=None):
    """Rend (True, nom du dossier de la séance) si une séance est ouverte, sinon (False, raison)."""
    dossier = dossier or SEANCES
    if not os.path.isdir(dossier):
        return False, "dossier des mises de côté introuvable : " + dossier
    seances = sorted(n for n in os.listdir(dossier)
                     if n.endswith(SUFFIXE_DES_SEANCES) and os.path.isdir(os.path.join(dossier, n)))
    if not seances:
        return False, "aucune séance dans " + dossier
    derniere = seances[-1]
    chemin = os.path.join(dossier, derniere, "etat.txt")
    if not os.path.isfile(chemin):
        return False, "la dernière séance (%s) n'a pas d'etat.txt" % derniere
    try:
        with open(chemin, encoding="utf-8-sig") as fichier:
            lignes = [l.strip() for l in fichier.read().splitlines() if l.strip()]
    except (OSError, UnicodeDecodeError) as erreur:
        return False, "etat.txt illisible (%s) : %s" % (derniere, erreur)
    etat = lignes[0].lower() if lignes else ""
    if etat != "en cours":
        return False, "la dernière séance (%s) est « %s »" % (derniere, etat or "vide")
    return True, derniere


def exiger_une_seance():
    ouverte, detail = seance_ouverte()
    if not ouverte:
        refuser("pas de séance ouverte (%s) : Mods\\%s est le mod de tous les jours de JoVenGer, rien n'y est écrit"
                % (detail, NOM_DU_MOD))
    print("Séance ouverte : " + detail)


def verifier_cible(jeu):
    jeu = os.path.abspath(jeu)
    if not os.path.isdir(jeu):
        refuser("dossier du jeu introuvable : " + jeu)
    if not os.path.isdir(os.path.join(jeu, "Mods")) and not os.path.isdir(os.path.join(jeu, "Data")):
        refuser("ce dossier ne ressemble pas au jeu (ni Mods ni Data) : " + jeu)
    cible = os.path.join(jeu, "Mods", NOM_DU_MOD)
    normal = os.path.normcase(os.path.abspath(cible))
    lisible = normal.replace("\\", "/").lower()
    for interdit in MORCEAUX_INTERDITS:
        if interdit in lisible:
            refuser("chemin interdit (Scriptorium actuel ou sa copie de sécurité) : " + cible)
    if os.path.basename(normal) != NOM_DU_MOD or os.path.basename(normal) in DOSSIERS_INTERDITS:
        refuser("la cible doit s'appeler " + NOM_DU_MOD + " : " + cible)
    if os.path.normcase(os.path.join(jeu, "Data")) in normal:
        refuser("jamais dans Data du jeu : " + cible)
    return cible


def verification_complete():
    print("Vérification complète avant installation…")
    code = subprocess.call([sys.executable, os.path.join(RACINE, "essais", "tout_verifier.py")])
    if code != 0:
        refuser("la vérification complète ne passe pas : rien n'est installé")


def mettre_de_cote(cible):
    if not os.path.exists(cible):
        return None
    horodatage = datetime.now().strftime("%Y-%m-%d_%H%M%S")
    destination = os.path.join(SECURITE, horodatage, NOM_DU_MOD)
    os.makedirs(os.path.dirname(destination), exist_ok=True)
    shutil.copytree(cible, destination)
    return destination


# Le wiki de Warhorse : un pak de mod est un zip sans compression.
def faire_pak(dossier_source, chemin_pak):
    os.makedirs(os.path.dirname(chemin_pak), exist_ok=True)
    compte = 0
    with zipfile.ZipFile(chemin_pak, "w", zipfile.ZIP_STORED) as pak:
        for racine, _, noms in os.walk(dossier_source):
            for nom in sorted(noms):
                chemin = os.path.join(racine, nom)
                interne = os.path.relpath(chemin, dossier_source).replace("\\", "/")
                pak.write(chemin, interne)
                compte += 1
    return compte


def installer(cible):
    # Le fichier de réglages appartient au PC (outils/regler.py, plus tard le programme Scriptorium) : il est gardé.
    chemin_reglages = os.path.join(cible, NOM_DES_REGLAGES)
    reglages = None
    if os.path.isfile(chemin_reglages):
        with open(chemin_reglages, "rb") as fichier:
            reglages = fichier.read()
    if os.path.exists(cible):
        shutil.rmtree(cible)
    os.makedirs(cible)
    if reglages is not None:
        with open(chemin_reglages, "wb") as fichier:
            fichier.write(reglages)
        print("  %s : gardé (réglages du PC)" % NOM_DES_REGLAGES)
    shutil.copy2(os.path.join(SOCLE, "mod.manifest"), os.path.join(cible, "mod.manifest"))
    cfg = os.path.join(SOCLE, "mod.cfg")
    if os.path.exists(cfg):
        shutil.copy2(cfg, os.path.join(cible, "mod.cfg"))
    nb_pak = faire_pak(PAK, os.path.join(cible, "Data", NOM_DU_MOD + ".pak"))
    print("  Data/%s.pak : %d fichiers" % (NOM_DU_MOD, nb_pak))
    for code, nom_jeu in LANGUES.items():
        source = os.path.join(TEXTES, code)
        if os.path.isdir(source):
            nb = faire_pak(source, os.path.join(cible, "Localization", nom_jeu + "_xml.pak"))
            print("  Localization/%s_xml.pak : %d fichiers" % (nom_jeu, nb))


def principal(arguments):
    if "--jeu" not in arguments:
        print(__doc__)
        return 2
    jeu = arguments[arguments.index("--jeu") + 1]
    cible = verifier_cible(jeu)
    exiger_une_seance()
    if "--sans-verification" not in arguments:
        verification_complete()
    if "--sans-mise-de-cote" not in arguments:
        garde = mettre_de_cote(cible)
        if garde:
            print("Ancien mod d'essai mis de côté : " + garde)
    print("Installation dans " + cible)
    installer(cible)
    print("Installé. Rappel : désactiver les trois mods Scriptorium pendant l'essai (décision D10), "
          "et jouer sur la partie d'essai, jamais sur la partie actuelle.")
    return 0


if __name__ == "__main__":
    sys.exit(principal(sys.argv[1:]))
