"""Installe le socle dans le jeu, dans son mod d'essai à part : Mods\\scriptorium_socle.

Usage (sur le PC de JoVenGer) :
    py -3.13 noyau/installer.py --jeu "G:\\SteamLibrary\\steamapps\\common\\KingdomComeDeliverance2"
    options : --sans-verification   n'exécute pas essais/tout_verifier.py avant (déconseillé)
              --sans-mise-de-cote   ne garde pas l'ancien mod d'essai dans securite/

Garanties :
- n'écrit que dans <jeu>\\Mods\\scriptorium_socle ; refuse tout autre chemin ;
- refuse en dur les dossiers du Scriptorium actuel, de sa copie de sécurité et des trois mods
  scriptorium, scriptorium_regles, scriptorium_lumiere, ainsi que Data\\ du jeu ;
- met de côté l'ancien mod d'essai dans securite/<date>/ avant de le remplacer ;
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
LANGUES = {"fr": "French"}

DOSSIERS_INTERDITS = ["scriptorium", "scriptorium_regles", "scriptorium_lumiere"]
# Morceaux de chemin interdits, comparés en minuscules et avec des « / » : le Scriptorium actuel et sa copie de sécurité.
MORCEAUX_INTERDITS = ["desktop/scriptorium/", "desktop/scriptorium", "scriptorium v2"]


def refuser(message):
    print("REFUS : " + message)
    sys.exit(2)


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


def faire_pak(dossier_source, chemin_pak):
    os.makedirs(os.path.dirname(chemin_pak), exist_ok=True)
    compte = 0
    with zipfile.ZipFile(chemin_pak, "w", zipfile.ZIP_DEFLATED) as pak:
        for racine, _, noms in os.walk(dossier_source):
            for nom in sorted(noms):
                chemin = os.path.join(racine, nom)
                interne = os.path.relpath(chemin, dossier_source).replace("\\", "/")
                pak.write(chemin, interne)
                compte += 1
    return compte


def installer(cible):
    if os.path.exists(cible):
        shutil.rmtree(cible)
    os.makedirs(cible)
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
