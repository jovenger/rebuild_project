"""Écrit les dialogues du socle (fiche 21) depuis leur description en données, socle/dialogues/arbres.json :
- le projet de quêtes du socle : socle/pak/Quests/scriptorium_socle.xml, un Level par carte (kutnohorsko, trosecko),
  une quête de fond par carte (éveillée avec la carte : arête OnWake vers son port « eveil »), un FaderDialog par arbre ;
- la table des rôles : socle/pak/Libs/Tables/rpg/role__scriptorium_socle.xml ;
- les règles Storm : socle/pak/Libs/Storm/storm__scriptorium_socle.xml (la tâche « roles ») et
  socle/pak/Libs/Storm/scriptorium_socle/roles.xml (une règle hasName par âme de nos réserves -> le rôle des hommes ;
  l'âme du Directeur -> son rôle) ;
- les textes : socle/textes/fr/text_ui_dialog__scriptorium_socle.xml.
Formes relevées dans les paks du jeu (lecture seule ; fiche 21). Rien n'est lu dans le jeu ici : l'outil n'écrit que dans
le dépôt, toujours à l'identique pour la même description.

Usage :
    py -3.13 outils/dialogues.py            écrit les fichiers (seulement s'ils changent)
    py -3.13 outils/dialogues.py --verifier  rend 1 si un fichier écrit n'est pas à jour (pour essais/tout_verifier.py)
"""
import json
import os
import re
import sys
from xml.sax.saxutils import escape, quoteattr

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DONNEES = os.path.join(RACINE, "socle", "dialogues", "arbres.json")
PAK = os.path.join(RACINE, "socle", "pak")
TEXTES = os.path.join(RACINE, "socle", "textes", "fr", "text_ui_dialog__scriptorium_socle.xml")
PROJET = "scriptorium_socle"
CARTES = [("kutnohorsko", "kut"), ("trosecko", "tro")]
FACTION = "scriptorium_socle_compagnie"          # outils/ames.py
AME_DU_DIRECTEUR = "scriptorium_directeur"       # outils/ames.py
VARIABLES = ["scriptorium_dialogue_code_1", "scriptorium_dialogue_code_2", "scriptorium_dialogue_code_3"]
VARIABLE_DU_COLONEL = "scriptorium_dialogue_colonel"
# La base des fichiers de quêtes : celle du jeu (Quests/Final/Barbora.xml : Name="brambora").
TETE = ('<?xml version="1.0" encoding="utf-8"?>\n<Database xmlns:xsd="http://www.w3.org/2001/XMLSchema" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Name="brambora">\n  <Skald>\n')
TABLE_DES_AMES = os.path.join(RACINE, "socle", "pak", "Libs", "Tables", "rpg", "soul__scriptorium_socle.xml")
PREFIXE_DES_ROLES = "5c7a5c7a-0006-4000-8000-%012x"   # le préfixe de nos âmes (outils/ames.py), code 6 : les rôles
PIED = "  </Skald>\n</Database>\n"
# L'activation d'un FaderDialog dans sa quête : une arête du port « run » de la quête vers ce port du FaderDialog
# (None : aucune arête). À fixer d'après les quêtes du jeu (fiche 21).
PORT_D_EVEIL = None


class Textes:
    """Les clés de texte et leur texte français, dans l'ordre d'apparition ; une clé a toujours le même texte."""

    def __init__(self):
        self.ordre, self.textes = [], {}

    def cle(self, cle, texte):
        if cle in self.textes and self.textes[cle] != texte:
            raise SystemExit("REFUS : la clé %s a deux textes" % cle)
        if cle not in self.textes:
            self.ordre.append(cle)
            self.textes[cle] = texte
        return cle


def attr(**valeurs):
    return "".join(" %s=%s" % (cle, quoteattr(str(v))) for cle, v in valeurs.items() if v is not None)


def texte(t, cle, contenu):
    return "<Text%s />" % attr(StringName=t.cle(cle, contenu), Text=contenu)


def reponse(t, role, cle, contenu):
    """Une réplique, écrite sur plusieurs lignes comme dans les dialogues du jeu."""
    if contenu is None:
        return ['<Response Role="%s" />' % role]
    return ['<Response Role="%s">' % role, "  " + texte(t, cle, contenu), "</Response>"]


def appel(arbre, choix, role):
    return ("if Scriptorium and Scriptorium.jeu and Scriptorium.jeu.dialogue_choix then "
            "Scriptorium.jeu.dialogue_choix('%s', '%s', dc['%s']) end" % (arbre, choix, role))


class Ecrivain:
    def __init__(self, t, nom, arbre, description, donnees):
        self.t, self.nom, self.arbre, self.d, self.donnees = t, nom, arbre, description, donnees
        self.role = description["role"]
        self.lignes = []
        self.compte = 0

    def ecrire(self, profondeur, ligne):
        self.lignes.append("  " * profondeur + ligne)

    def elements(self, p, *reponses):
        self.ecrire(p, "<Elements>")
        for lignes in reponses:
            for ligne in lignes:
                self.ecrire(p + 1, ligne)
        self.ecrire(p, "</Elements>")

    def nom_unique(self, base):
        self.compte += 1
        return "%s_%s_%d" % (self.nom, base, self.compte)

    def cle(self, *parties):
        return "_".join(["ui_scriptorium_dlg", self.arbre] + [str(p) for p in parties])

    def places(self, repliques):
        places = {}
        for r in repliques:
            places.setdefault(r["place"], []).append(r)
        return [places[p] for p in sorted(places)]

    def chaine_des_places(self, p, chemin, places, fin, numero=0):
        """Les places de réplique, une décision Autoselect par place, recopiée sous chaque branche ; « fin » écrit la
        sortie de la dernière branche."""
        if numero >= len(places):
            fin(p)
            return
        variable = VARIABLES[numero]
        self.ecrire(p, '<Decision%s>' % attr(Name=self.nom_unique("place%d" % (numero + 1)), Autoselect="true",
                                             Priority="General", DesignName="place %d" % (numero + 1)))
        self.ecrire(p + 1, "<Sequences>")
        branches = [(r, "gvar('%s') == %d" % (variable, r["code"])) for r in places[numero]]
        rien = "gvar('%s') == 0" % variable
        if numero == 0:
            branches.append(({"code": 0, "texte": self.donnees["repli"]}, rien))
        else:
            branches.append(({"code": 0, "texte": None}, rien))
        for r, condition in branches:
            fermer = r.get("fin") == "fermer"
            if fermer:
                self.ecrire(p + 2, "<Sequence%s>" % attr(Name=self.nom_unique("code"), DesignName="code %d" % r["code"],
                                                         EntryCondition=condition, EndType="EndDialogue"))
            elif numero + 1 < len(places):
                self.ecrire(p + 2, "<Sequence%s>" % attr(Name=self.nom_unique("code"), DesignName="code %d" % r["code"],
                                                         EntryCondition=condition, EndType="Decision"))
            else:
                self.ecrire(p + 2, "<Sequence%s>" % (attr(Name=self.nom_unique("code"), DesignName="code %d" % r["code"],
                                                          EntryCondition=condition) + fin(None)))
            cle = self.cle(chemin, "repli") if (numero == 0 and r["code"] == 0) else self.cle(chemin, "p%d" % (numero + 1), r["code"])
            self.elements(p + 3, reponse(self.t, self.role if r["texte"] else "HENRY", cle, r["texte"]))
            if not fermer and numero + 1 < len(places):
                self.chaine_des_places(p + 3, chemin, places, fin, numero + 1)
            self.ecrire(p + 2, "</Sequence>")
        self.ecrire(p + 1, "</Sequences>")
        self.ecrire(p, "</Decision>")

    def sortie_vers(self, decision):
        def fin(p):
            if p is None:
                return attr(EndType="GoTo", GoToDecision=decision)
            return None
        return fin

    def choix(self, p, c, chemin, menu):
        cond = "gvar('%s') == 1" % VARIABLE_DU_COLONEL if c.get("condition") == "colonel" else None
        places = self.places(c.get("repliques", []))
        nom = self.nom_unique(c["nom"])
        fin_attr = attr(EndType="Decision") if places else attr(EndType="GoTo", GoToDecision=menu)
        self.ecrire(p, "<Sequence%s%s>" % (attr(Name=nom, DesignName=c["nom"], EntryCondition=cond,
                                                ExitScript=appel(self.arbre, c["nom"], self.role)), fin_attr))
        self.ecrire(p + 1, texte(self.t, self.cle(chemin, c["nom"], "invite"), c["invite"]).replace("<Text", "<UiPrompt"))
        elements = [reponse(self.t, "HENRY", self.cle(chemin, c["nom"], "henry"), c.get("henry"))]
        if c.get("reponse"):
            elements.append(reponse(self.t, self.role, self.cle(chemin, c["nom"], "reponse"), c["reponse"]))
        self.elements(p + 1, *elements)
        if places:
            self.chaine_des_places(p + 1, chemin + "_" + c["nom"], places, self.sortie_vers(menu))
        self.ecrire(p, "</Sequence>")

    def sous_menu(self, p, cat, menu):
        nom = self.nom_unique(cat["categorie"] + "_menu")
        self.ecrire(p, "<Decision%s>" % attr(Name=nom, Priority="General", DesignName=cat["categorie"]))
        self.ecrire(p + 1, "<Sequences>")
        for c in cat["choix"]:
            self.choix(p + 2, c, cat["categorie"], menu)
        self.ecrire(p + 2, "<Sequence%s>" % attr(Name=self.nom_unique("retour"), DesignName="retour", EndType="GoTo",
                                                  GoToDecision=menu))
        self.ecrire(p + 3, texte(self.t, self.cle("retour_aux_sujets"), self.donnees["retour_aux_sujets"]).replace("<Text", "<UiPrompt"))
        self.elements(p + 3, reponse(self.t, "HENRY", None, None))
        self.ecrire(p + 2, "</Sequence>")
        self.ecrire(p + 1, "</Sequences>")
        self.ecrire(p, "</Decision>")

    def categorie(self, p, cat, menu):
        cond = "gvar('%s') == 1" % VARIABLE_DU_COLONEL if cat.get("condition") == "colonel" else None
        self.ecrire(p, "<Sequence%s>" % attr(Name=self.nom_unique(cat["categorie"]), DesignName=cat["categorie"],
                                              EntryCondition=cond, ExitScript=appel(self.arbre, cat["categorie"], self.role),
                                              EndType="Decision"))
        self.ecrire(p + 1, texte(self.t, self.cle(cat["categorie"], "invite"), cat["invite"]).replace("<Text", "<UiPrompt"))
        elements = [reponse(self.t, "HENRY", self.cle(cat["categorie"], "henry"), cat.get("henry"))]
        if cat.get("reponse"):
            elements.append(reponse(self.t, self.role, self.cle(cat["categorie"], "reponse"), cat["reponse"]))
        self.elements(p + 1, *elements)
        places = self.places(cat.get("repliques_categorie", []))
        if places:
            # La réponse de la catégorie (le conseil, les fautes), puis son sous-menu sous chaque branche.
            self.chaine_des_places_puis(p + 1, cat, places, menu)
        else:
            self.sous_menu(p + 1, cat, menu)
        self.ecrire(p, "</Sequence>")

    def chaine_des_places_puis(self, p, cat, places, menu, numero=0):
        variable = VARIABLES[numero]
        self.ecrire(p, '<Decision%s>' % attr(Name=self.nom_unique("place%d" % (numero + 1)), Autoselect="true",
                                             Priority="General", DesignName="place %d" % (numero + 1)))
        self.ecrire(p + 1, "<Sequences>")
        branches = [(r, "gvar('%s') == %d" % (variable, r["code"])) for r in places[numero]]
        branches.append(({"code": 0, "texte": self.donnees["repli"] if numero == 0 else None}, "gvar('%s') == 0" % variable))
        for r, condition in branches:
            self.ecrire(p + 2, "<Sequence%s>" % attr(Name=self.nom_unique("code"), DesignName="code %d" % r["code"],
                                                     EntryCondition=condition, EndType="Decision"))
            cle = self.cle(cat["categorie"], "repli") if (numero == 0 and r["code"] == 0) else self.cle(cat["categorie"], "p%d" % (numero + 1), r["code"])
            self.elements(p + 3, reponse(self.t, self.role if r["texte"] else "HENRY", cle, r["texte"]))
            if numero + 1 < len(places):
                self.chaine_des_places_puis(p + 3, cat, places, menu, numero + 1)
            else:
                self.sous_menu(p + 3, cat, menu)
            self.ecrire(p + 2, "</Sequence>")
        self.ecrire(p + 1, "</Sequences>")
        self.ecrire(p, "</Decision>")

    def fader(self):
        menu = self.nom + "_menu"
        self.ecrire(2, "<FaderDialog%s>" % attr(Name=self.nom, Time="ANYTIME"))
        self.ecrire(3, texte(self.t, self.cle("titre"), "Scriptorium, " + self.arbre))
        self.ecrire(3, "<Dialogue%s>" % attr(TechnicalStatus="Enabled", AllowFarewell="false", AllowGreeting="false"))
        self.ecrire(4, "<Decision%s>" % attr(Name=self.nom + "_entree", Priority="General", DesignName="entree"))
        self.ecrire(5, "<Sequences>")
        self.ecrire(6, "<Sequence%s>" % attr(Name=self.nom + "_ouverture", DesignName="ouverture",
                                              ExitScript=appel(self.arbre, "ouverture", self.role), EndType="Decision"))
        self.elements(7, reponse(self.t, "HENRY", None, None),
                      reponse(self.t, self.role, self.cle("ouverture"), self.d["ouverture"]))
        self.ecrire(7, "<Decision%s>" % attr(Name=menu, Priority="General", DesignName="menu"))
        self.ecrire(8, "<Sequences>")
        for item in self.d["menu"]:
            if "categorie" in item:
                self.categorie(9, item, menu)
            else:
                self.choix(9, item, "menu", menu)
        self.ecrire(9, "<Sequence%s>" % attr(Name=self.nom + "_tout", DesignName="ce_sera_tout", EndType="EndDialogue"))
        self.ecrire(10, texte(self.t, self.cle("ce_sera_tout"), self.donnees["ce_sera_tout"]).replace("<Text", "<UiPrompt"))
        self.elements(10, reponse(self.t, "HENRY", None, None))
        self.ecrire(9, "</Sequence>")
        self.ecrire(8, "</Sequences>")
        self.ecrire(7, "</Decision>")
        self.ecrire(6, "</Sequence>")
        self.ecrire(5, "</Sequences>")
        self.ecrire(4, "</Decision>")
        self.ecrire(3, "</Dialogue>")
        self.ecrire(2, "</FaderDialog>")
        return TETE + "\n".join(self.lignes) + "\n" + PIED


def fichiers(donnees):
    t = Textes()
    sortie = {}
    objectifs = "\n".join([
        '      <ObjectiveValueTypes>',
        '        <ObjectiveValueType Type="None" IsPast="false" Icon="Exclamation" />',
        '        <ObjectiveValueType Type="Started" IsPast="false" Icon="Exclamation" Hint="objective_HintStarted" />',
        '        <ObjectiveValueType Type="Updated" IsPast="false" Icon="Exclamation" Hint="objective_HintUpdated" />',
        '        <ObjectiveValueType Type="Completed" IsPast="true" Icon="Check" Hint="objective_HintCompleted" />',
        '        <ObjectiveValueType Type="Canceled" IsPast="true" Icon="Check" Hint="objective_HintCanceled" />',
        '      </ObjectiveValueTypes>'])
    # Principe transmis par le pair (18/10) : un projet à la racine de Quests, un nœud par carte (nom de la carte,
    # position), son titre ; un Level par carte au nom exact de la carte, réveillant sa quête (OnWake) ; chaque
    # dialogue un fichier à part, nœud de la quête ; chaque chemin relatif au dossier du fichier qui le déclare.
    sortie["Quests/%s.xml" % PROJET] = TETE + "\n".join(
        ['    <Project Name="%s">' % PROJET, "      <Definitions>"]
        + ['        <Definition File="%s/carte_%s.xml" />' % (PROJET, carte) for carte, _ in CARTES]
        + ["      </Definitions>", "      <Nodes>"]
        + ['        <%s Name="%s" PositionX="%d" PositionY="0" />' % (carte, carte, 300 * i) for i, (carte, _) in enumerate(CARTES)]
        + ["      </Nodes>", '      <Text Text="%s" />' % PROJET, objectifs, "    </Project>"]) + "\n" + PIED
    for carte, court in CARTES:
        quete = "%s_fond_%s" % (PROJET, court)
        sortie["Quests/%s/carte_%s.xml" % (PROJET, carte)] = TETE + "\n".join([
            '    <Level Name="%s" HibernateMode="Auto">' % carte,   # la forme du jeu (Barbora/kutnohorsko.xml)
            "      <Definitions>", '        <Definition File="%s/%s.xml" />' % (carte, quete), "      </Definitions>",
            "      <Nodes>", '        <%s Name="%s" PositionX="0" PositionY="0" RequiredForOutput="%s">' % (quete, quete, carte),
            '          <Edge From="OnWake" To="eveil" />',
            "        </%s>" % quete, "      </Nodes>", "    </Level>"]) + "\n" + PIED
        dialogues = []
        for arbre, description in donnees["arbres"].items():
            nom = "%s_%s_%s" % (PROJET, arbre, court)
            dialogues.append(nom)
            sortie["Quests/%s/%s/%s/%s.xml" % (PROJET, carte, quete, nom)] = Ecrivain(t, nom, arbre, description, donnees).fader()
        noeuds = []
        for nom in dialogues:
            if PORT_D_EVEIL:
                noeuds += ['        <%s Name="%s">' % (nom, nom), '          <Edge From="eveil" To="%s" />' % PORT_D_EVEIL,
                           "        </%s>" % nom]
            else:
                noeuds.append('        <%s Name="%s" PositionX="0" PositionY="%d" />' % (nom, nom, 200 * len(noeuds)))
        sortie["Quests/%s/%s/%s.xml" % (PROJET, carte, quete)] = TETE + "\n".join(
            ['    <Quest Name="%s" Type="Side" Players="0" Repeatable="true" VoiceNamespace="false">' % quete, "      <Ports>",
             '        <Port Name="eveil" Direction="In" Type="trigger"><DesignName Text="eveil" /></Port>', "      </Ports>",
             "      <Definitions>"] + ['        <Definition File="%s/%s.xml" />' % (quete, nom) for nom in dialogues]
            + ["      </Definitions>", "      <Nodes>"] + noeuds + ["      </Nodes>", "    </Quest>"]) + "\n" + PIED
    # Les rôles et les règles Storm.
    # Principe transmis par le pair (18/10) : chaque rôle porte un identifiant neuf à nous (role_id), metarole « NPC »
    # et son nom ; <roles> sans version.
    roles = [d["role"] for d in donnees["arbres"].values()]
    sortie["Libs/Tables/rpg/role__%s.xml" % PROJET] = "\n".join(
        ['<?xml version="1.0" encoding="us-ascii"?>',
         '<database xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="barbora" '
         'xsi:noNamespaceSchemaLocation="../database.xsd">', '  <roles>']
        + ['    <role metarole_name="NPC" role_id="%s" role_name="%s" />' % (PREFIXE_DES_ROLES % (i + 1), r)
           for i, r in enumerate(roles)]
        + ["  </roles>", "</database>", ""])
    homme, directeur = donnees["arbres"]["homme"]["role"], donnees["arbres"]["directeur"]["role"]
    sortie["Libs/Storm/storm__%s.xml" % PROJET] = "\n".join([
        '<?xml version="1.0"?>', "<storm>", "  <tasks>", '    <task name="roles" class="roles">',
        '      <source path="%s\\roles.xml" />' % PROJET, "    </task>", "  </tasks>", "</storm>", ""])
    # Principe transmis par le pair (18/10) : une règle par âme, un seul hasName (le nom exact de l'âme), le nom de la
    # règle est celui de l'âme ; les âmes de nos réserves (combattants, gens de métier, femmes) reçoivent le rôle des
    # hommes, celle du Directeur le sien.
    with open(TABLE_DES_AMES, "r", encoding="ascii") as f:
        ames = sorted(set(re.findall(r'soul_name="(scriptorium_(?:combattant|metier|femme)_[0-9_]+)"', f.read())))
    if not ames:
        raise SystemExit("REFUS : aucune âme de réserve dans " + TABLE_DES_AMES)
    regles = []
    for ame, role in [(a, homme) for a in ames] + [(AME_DU_DIRECTEUR, directeur)]:
        regles += ['    <rule name="%s">' % ame, "      <selectors>", '        <hasName name="%s" />' % ame, "      </selectors>",
                   "      <operations>", '        <addRole name="%s" />' % role, "      </operations>", "    </rule>"]
    sortie["Libs/Storm/%s/roles.xml" % PROJET] = "\n".join(
        ['<?xml version="1.0"?>', '<!DOCTYPE storm SYSTEM "../storm.dtd">', "<storm>", "  <rules>"] + regles
        + ["  </rules>", "</storm>", ""])
    lignes = ["<Table>"]
    for cle in t.ordre:
        lignes.append("  <Row><Cell>%s</Cell><Cell>%s</Cell><Cell>%s</Cell></Row>" % (cle, escape(t.textes[cle]), escape(t.textes[cle])))
    lignes.append("</Table>")
    textes = "\n".join(lignes) + "\n"
    return sortie, textes


def principal(arguments):
    with open(DONNEES, "r", encoding="utf-8") as f:
        donnees = json.load(f)
    sortie, textes = fichiers(donnees)
    cibles = [(os.path.join(PAK, *chemin.split("/")), contenu) for chemin, contenu in sorted(sortie.items())]
    cibles.append((TEXTES, textes))
    a_jour = True
    for chemin, contenu in cibles:
        ancien = None
        if os.path.isfile(chemin):
            with open(chemin, "r", encoding="utf-8", newline="") as f:
                ancien = f.read()
        # Les fins de ligne ne comptent pas (git peut les convertir à l'extraction).
        if ancien is not None and ancien.replace("\r\n", "\n") == contenu:
            continue
        a_jour = False
        if "--verifier" in arguments:
            print("pas à jour : " + os.path.relpath(chemin, RACINE))
            continue
        os.makedirs(os.path.dirname(chemin), exist_ok=True)
        with open(chemin, "w", encoding="utf-8", newline="") as f:
            f.write(contenu)
        print("écrit : %s (%d octets)" % (os.path.relpath(chemin, RACINE), len(contenu.encode("utf-8"))))
    if "--verifier" in arguments:
        return 0 if a_jour else 1
    if a_jour:
        print("déjà à jour")
    return 0


if __name__ == "__main__":
    sys.exit(principal(sys.argv[1:]))
