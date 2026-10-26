"""Squelette du tableau du guichet (fiche 16, demande du pair du 17/10) : une ligne par entrée du contrat de Scriptorium
(accroches, fonctions, données, retouches), lue en lecture seule dans le dossier de Scriptorium, avec une case
« notre service » à remplir. N'écrase jamais un tableau existant : il écrit à côté (« .squelette.md »).

Usage :
    py -3.13 outils/squelette_guichet.py "C:\\Users\\maste\\Desktop\\Scriptorium\\docs\\socle\\CONTRAT_DU_SOCLE.md"
"""
import hashlib
import logging
import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SORTIE = os.path.join(RACINE, "docs", "socle", "guichet.squelette.md")

journal = logging.getLogger("squelette_guichet")

SECTIONS = [
    ("## 1.", "A", "accroche"),
    ("## 2.", "F", "fonction"),
    ("## 3.", "D", "donnée"),
    ("## 4.", "R", "retouche"),
]
ENTREE = re.compile(r"^- \*\*(.+?)\*\*(.*)$")


def relever(texte):
    entrees, sorte = [], None
    for ligne in texte.splitlines():
        for debut, lettre, nom in SECTIONS:
            if ligne.startswith(debut):
                sorte = (lettre, nom)
        m = ENTREE.match(ligne)
        if sorte and m:
            nom = m.group(1).strip("`")
            reste = m.group(2).strip(" —-")
            # La description : ce qui suit le dernier « — » (accroches, fonctions, données) ; le titre seul (retouches).
            description = reste.split(" — ")[-1] if " — " in reste else reste
            if sorte[0] == "R":
                description = ""
            entrees.append((sorte[0], nom, description.replace("|", "/")[:160]))
    return entrees


def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s : %(message)s")
    if len(sys.argv) != 2 or not os.path.isfile(sys.argv[1]):
        journal.error("donner le chemin du contrat (CONTRAT_DU_SOCLE.md)")
        return 2
    brut = open(sys.argv[1], "rb").read()
    entrees = relever(brut.decode("utf-8"))
    comptes = {}
    for lettre, _, _ in entrees:
        comptes[lettre] = comptes.get(lettre, 0) + 1
    journal.info("relevé : %s", comptes)
    lignes = [
        "# Le guichet — chaque entrée du contrat de Scriptorium face au service du socle",
        "",
        "Contrat lu : `CONTRAT_DU_SOCLE.md`, empreinte sha256 " + hashlib.sha256(brut).hexdigest()[:16] + ".",
        "",
        "| n° | entrée du contrat | ce qu'elle fait | notre service |",
        "|---|---|---|---|",
    ]
    numeros = {}
    for lettre, nom, description in entrees:
        numeros[lettre] = numeros.get(lettre, 0) + 1
        lignes.append(f"| {lettre}{numeros[lettre]} | `{nom}` | {description} |  |")
    with open(SORTIE, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lignes) + "\n")
    journal.info("écrit : %s (%d lignes)", SORTIE, len(entrees))
    return 0


if __name__ == "__main__":
    sys.exit(main())
