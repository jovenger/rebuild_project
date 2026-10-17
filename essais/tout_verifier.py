"""Vérification complète du socle. Rien ne se commet ni ne s'installe si elle ne passe pas.

Usage :
    py -3.13 essais/tout_verifier.py            # mode suivi
    py -3.13 essais/tout_verifier.py --strict   # mode strict : les empreintes d'Alex sont exigées

Étapes :
  1. syntaxe Lua (Lua 5.1, celui du moteur) de tous les scripts du socle ;
  2. banc d'essai Lua (essais/lua/essai_*.lua) sur le faux jeu ;
  3. noms interdits et brouillons oubliés dans le socle ;
  4. textes : tables de langue bien formées, clés uniques, clés employées <-> clés définies ;
  5. manifeste du mod ;
  6. contrôle d'absence : empreintes du socle comparées à celles d'Alex (docs/socle/empreintes_alex.json).
"""

import json
import os
import re
import sys
import xml.etree.ElementTree as ET
import zipfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOCLE = os.path.join(RACINE, "socle")
PAK = os.path.join(SOCLE, "pak")
TEXTES = os.path.join(SOCLE, "textes")
ESSAIS_LUA = os.path.join(RACINE, "essais", "lua")
EMPREINTES = os.path.join(RACINE, "docs", "socle", "empreintes_alex.json")

sys.path.insert(0, os.path.join(RACINE, "outils"))
sys.path.insert(0, os.path.join(RACINE, "noyau"))
import empreintes as outil_empreintes  # noqa: E402

MOTIFS_INTERDITS = [
    (re.compile(r"mercenar", re.I), "nom du mod d'Alex"),
    (re.compile(r"\bMerc[A-Z_]"), "personnage d'Alex"),
    (re.compile(r"\bmerc_"), "préfixe d'Alex"),
    (re.compile(r"\bQM[A-Z]"), "clé de sauvegarde d'Alex"),
    (re.compile(r"Quartermaster", re.I), "intendant d'Alex"),
    (re.compile(r"WBRaid"), "fonction de bataille d'Alex"),
    (re.compile(r"\b(TODO|FIXME|XXX)\b"), "brouillon oublié"),
]

MOTIF_CLE = re.compile(r"ui_scriptorium_[A-Za-z0-9_]+")

erreurs = []
avertissements = []


def erreur(message):
    erreurs.append(message)


def avertir(message):
    avertissements.append(message)


def fichiers(dossier, extensions):
    for racine, _, noms in os.walk(dossier):
        for nom in sorted(noms):
            if os.path.splitext(nom)[1].lower() in extensions:
                yield os.path.join(racine, nom)


def lire(chemin):
    with open(chemin, "r", encoding="utf-8") as fichier:
        return fichier.read()


def relatif(chemin):
    return os.path.relpath(chemin, RACINE).replace("\\", "/")


# ------------------------------------------------------------------ 1. syntaxe Lua

def runtime_lua():
    try:
        from lupa import lua51
    except ImportError:
        erreur("lupa (Lua 5.1) absent : py -3.13 -m pip install lupa")
        return None
    return lua51.LuaRuntime(unpack_returned_tuples=True)


def verifier_syntaxe(lua):
    compte = 0
    charger = lua.eval("function(code, nom) local f, err = loadstring(code, nom) if not f then error(err, 0) end return true end")
    for chemin in list(fichiers(PAK, {".lua"})) + list(fichiers(ESSAIS_LUA, {".lua"})):
        compte += 1
        try:
            charger(lire(chemin), "=" + relatif(chemin))
        except Exception as exception:  # noqa: BLE001
            erreur("syntaxe Lua : %s" % exception)
    return compte


# ------------------------------------------------------------------ 2. banc Lua

ORDRE_SOCLE = ["noyau.lua", "bandeau.lua", "registre.lua", "coffre.lua", "camp.lua", "hommes.lua", "bataille.lua", "directeur.lua", "enceinte.lua", "atelier.lua", "patrouilles.lua", "discipline.lua", "caractere.lua", "reglages.lua", "poste.lua"]


def executer_banc(lua):
    executer = lua.eval("function(code, nom) local f, err = loadstring(code, nom) if not f then error(err, 0) end return f() end")
    executer(lire(os.path.join(ESSAIS_LUA, "faux_jeu.lua")), "=essais/lua/faux_jeu.lua")
    executer(lire(os.path.join(ESSAIS_LUA, "outils_essai.lua")), "=essais/lua/outils_essai.lua")
    for nom in ORDRE_SOCLE:
        chemin = os.path.join(PAK, "Scripts", "scriptorium", nom)
        try:
            executer(lire(chemin), "=" + relatif(chemin))
        except Exception as exception:  # noqa: BLE001
            erreur("banc Lua : chargement du socle en échec : %s" % exception)
            return 0, 1, 0
    essais = sorted(f for f in os.listdir(ESSAIS_LUA) if f.startswith("essai_") and f.endswith(".lua"))
    for nom in essais:
        chemin = os.path.join(ESSAIS_LUA, nom)
        try:
            executer(lire(chemin), "=" + relatif(chemin))
        except Exception as exception:  # noqa: BLE001
            erreur("banc Lua : %s interrompu : %s" % (nom, exception))
    resultats = lua.globals().Essais
    for message in list(resultats.messages.values()):
        erreur("banc Lua : " + message)
    return int(resultats.reussis), int(resultats.echecs), len(essais)


# ------------------------------------------------------------------ 2 bis. ordres par fichier

def verifier_ordres():
    """Un ordre écrit par outils/ordonner.py est relu tel quel par la vraie liaison ; un fichier qui
    voudrait toucher au jeu ne voit rien (environnement vide)."""
    import tempfile
    import ordonner
    connues = ordonner.commandes_du_poste()
    if len(connues) != 149:
        erreur("ordres : %d commandes lues dans poste.lua, 149 attendues" % len(connues))
    lua = runtime_lua()
    if lua is None:
        return len(connues)
    chemin_liaison = os.path.join(PAK, "Scripts", "scriptorium", "liaison.lua")
    lua.execute(lire(os.path.join(PAK, "Scripts", "scriptorium", "noyau.lua")))
    lua.execute(lire(chemin_liaison))
    liaison = lua.globals().Scriptorium.liaison_reelle
    with tempfile.TemporaryDirectory() as dossier:
        chemin = os.path.join(dossier, ordonner.NOM_DU_FICHIER)
        liaison.chemins_des_ordres = lua.table_from([os.path.join(dossier, "absent.lua"), chemin])
        if liaison.lire_ordres() is not None:
            erreur("ordres : sans fichier, la liaison devrait ne rien rendre")
        for attendu in (1, 2):
            numero, _ = ordonner.ecrire(dossier, "scriptorium_bilan")
            donnees, lu_a = liaison.lire_ordres()
            if numero != attendu or donnees is None or donnees.numero != attendu \
                    or donnees.commande != "scriptorium_bilan" or lu_a != chemin:
                erreur("ordres : l'ordre n° %d écrit n'est pas relu tel quel par la liaison" % attendu)
        with open(chemin, "w", encoding="ascii") as fichier:
            fichier.write('return { numero = 3, commande = tostring(os) }\n')
        donnees, _, raison = liaison.lire_ordres()
        if donnees is not None or not raison:
            erreur("ordres : un fichier qui appelle le jeu devrait être refusé (environnement vide)")
    return len(connues)


def verifier_reglages_par_fichier():
    """Fiche 10 : un fichier écrit par outils/regler.py est relu tel quel par la vraie liaison ; l'outil fait
    éprouver chaque valeur par le socle avant d'écrire ; l'installateur garde le fichier d'une installation à l'autre.
    Rend le nombre de valeurs réglables."""
    import tempfile
    import regler
    import installer
    lua = runtime_lua()
    if lua is None:
        return 0
    socle = regler.charger_le_socle()
    nombre = len(socle.globals().Scriptorium.reglages.liste_des_valeurs())
    if nombre < 100:
        erreur("réglages : %d valeurs réglables seulement" % nombre)
    if regler.eprouver(socle, {"hommes": {"ration": 3}, "issues": {"victoire": {"blesses": 0.1}}}):
        erreur("réglages : des valeurs justes refusées par l'outil")
    refus = regler.eprouver(socle, {"hommes": {"ration": 2.5}, "magie": {"mana": 1}})
    if sorted(r[2] for r in refus) != ["pas_entier", "section_inconnue"]:
        erreur("réglages : refus de l'outil inattendus : %s" % refus)
    donnees = {}
    regler.poser(donnees, "hommes.ration", regler.lire_la_valeur("3"))
    regler.poser(donnees, "issues.victoire.blesses", regler.lire_la_valeur("0,1"))
    if not regler.retirer(donnees, "hommes.ration") or "hommes" in donnees:
        erreur("réglages : retirer une valeur devrait vider sa section")
    regler.poser(donnees, "hommes.ration", 3)
    lua.execute(lire(os.path.join(PAK, "Scripts", "scriptorium", "noyau.lua")))
    lua.execute(lire(os.path.join(PAK, "Scripts", "scriptorium", "liaison.lua")))
    liaison = lua.globals().Scriptorium.liaison_reelle
    with tempfile.TemporaryDirectory() as dossier:
        chemin = regler.ecrire(dossier, donnees)
        liaison.chemins_des_reglages = lua.table_from([os.path.join(dossier, "absent.lua"), chemin])
        lu, lu_a = liaison.lire_reglages()
        if lu is None or lu_a != chemin or lu.hommes.ration != 3 or abs(lu.issues.victoire.blesses - 0.1) > 1e-12:
            erreur("réglages : le fichier écrit par l'outil n'est pas relu tel quel par la liaison")
        if regler.lire_le_fichier(chemin) != donnees:
            erreur("réglages : l'outil ne relit pas ce qu'il a écrit")
        with open(chemin, "w", encoding="ascii") as fichier:
            fichier.write("return { hommes = { ration = tostring(os) } }\n")
        lu, _, raison = liaison.lire_reglages()
        if lu is not None or not raison:
            erreur("réglages : un fichier qui appelle le jeu devrait être refusé (environnement vide)")
        cible = os.path.join(dossier, "Mods", installer.NOM_DU_MOD)
        os.makedirs(cible)
        with open(os.path.join(cible, installer.NOM_DES_REGLAGES), "w", encoding="ascii") as fichier:
            fichier.write("return { hommes = { ration = 4 } }\n")
        sortie = sys.stdout
        try:
            sys.stdout = open(os.devnull, "w", encoding="utf-8")
            installer.installer(cible)
        finally:
            sys.stdout.close()
            sys.stdout = sortie
        if not os.path.isfile(os.path.join(cible, "mod.manifest")):
            erreur("réglages : l'installation d'essai n'a pas posé le socle")
        if regler.lire_le_fichier(os.path.join(cible, installer.NOM_DES_REGLAGES)) != {"hommes": {"ration": 4}}:
            erreur("réglages : l'installateur n'a pas gardé le fichier de réglages")
    return nombre


def verifier_identifiants():
    """Les entités posées par la vraie liaison sont désignées par leur nom (une chaîne que le registre
    sait garder), pas par entite.id, donnée du moteur refusée au registre (vu en jeu le 14/10)."""
    lua = runtime_lua()
    if lua is None:
        return
    lua.execute("""
        System = { entites = {} }
        function System.GetEntityByName(nom) return System.entites[nom] end
        function System.GetTerrainElevation(p) return 7 end
        function System.SpawnEntity(p)
          System.derniere_orientation = p.orientation
          System.derniere_position = p.position
          local e = { id = newproxy(), name = p.name }
          function e:SetWorldAngles(a) System.derniers_angles = a end
          System.entites[p.name] = e
          return e
        end
        function System.RemoveEntity(id)
          for nom, e in pairs(System.entites) do if e.id == id then System.entites[nom] = nil end end
        end
        function System.LogAlways() end
    """)
    lua.execute(lire(os.path.join(PAK, "Scripts", "scriptorium", "noyau.lua")))
    lua.execute(lire(os.path.join(PAK, "Scripts", "scriptorium", "liaison.lua")))
    resultat = lua.eval("""(function()
        local l = Scriptorium.liaison_reelle
        local p = { x = 1, y = 2, z = 3 }
        local a = l.poser_objet("feu", "modele", p, 90, "feu_central")
        local b = l.poser_objet("feu", "modele", p, 90, "feu_central")
        if a ~= "scriptorium_feu_central" then return "premier nom : " .. tostring(a) end
        if b ~= "scriptorium_feu_central_2" then return "second nom : " .. tostring(b) end
        if not l.objet_existe(a) then return "objet posé introuvable" end
        if System.derniere_position.z ~= 7 then return "objet non posé au sol : z = " .. tostring(System.derniere_position.z) end
        l.retirer_objet(a)
        if l.objet_existe(a) then return "objet retiré encore là" end
        if not l.objet_existe(b) then return "l'autre objet a disparu" end
        local h = l.poser_objet("lit", "modele", p, 0, "Mikuláš Kladivo")
        if h ~= "scriptorium_Mikul_____Kladivo" then return "nom d'entité hors ASCII ou mal formé" end
        -- Henry face à l'ouest : +90° pour le moteur, 270° en cap de boussole ; et retour (vu en jeu le 14/10).
        player = { GetWorldAngles = function() return { x = 0, y = 0, z = math.rad(90) } end }
        local cap = l.cap_du_joueur()
        if math.abs(cap - 270) > 1e-6 then return "cap d'Henry face à l'ouest : " .. tostring(cap) .. ", 270 attendu" end
        l.poser_objet("tente", "modele", p, cap, "tente")
        -- « orientation » est un vecteur de direction (l'avant), à l'horizontale ; les angles sont posés à part.
        local o = System.derniere_orientation
        if math.abs(o.x + 1) > 1e-6 or math.abs(o.y) > 1e-6 or o.z ~= 0 then
          return "objet posé à 270 : avant (" .. o.x .. ", " .. o.y .. ", " .. o.z .. "), l'ouest (-1, 0, 0) attendu"
        end
        if math.abs(System.derniers_angles.z - math.pi / 2) > 1e-6 then
          return "objet posé à 270 : angle moteur " .. tostring(System.derniers_angles.z) .. ", +90° attendu"
        end
        -- Registre : par le jeton du jeu, relu même sans la mémoire ; mémoire de secours sans jeton.
        GameToken = { valeurs = {} }
        function GameToken.SetToken(nom, valeur) GameToken.valeurs[nom] = valeur end
        function GameToken.GetToken(nom) return GameToken.valeurs[nom] end
        l.ecrire_registre("{a=1}")
        l.memoire.registre = nil
        if l.lire_registre() ~= "{a=1}" then return "registre non relu depuis le jeton" end
        local marque = nil
        for nom in pairs(System.entites) do
          if string.find(nom, "^scriptorium_registre_") then marque = nom end
        end
        if not marque then return "pas de marque de la partie posée dans le monde" end
        -- Une autre partie (sauvegarde sans la marque) : le jeton est ignoré (vu en jeu le 14/10).
        System.entites[marque] = nil
        if l.lire_registre() ~= nil then return "le jeton d'une autre partie n'est pas ignoré" end
        l.ecrire_registre("{c=3}")
        if l.lire_registre() ~= "{c=3}" then return "nouvelle partie : registre non relu après marquage" end
        GameToken = nil
        l.memoire.registre = "{b=2}"
        if l.lire_registre() ~= "{b=2}" then return "sans jeton, la mémoire de secours n'est pas lue" end
        -- Bataille (V18, V19) : une description qui ne casse pas quand le moteur n'a pas la fonction demandée.
        AI = {}
        function AI.GetFactionOf(id) return "brigands" end
        local e1 = l.faire_venir_ennemis("brigands", 2, p, 0)
        local n1 = l.faire_venir_homme(l.ame_de("combattant", 1, 1), "homme_1", p)
        if type(e1) ~= "table" or #e1 ~= 2 or not n1 then return "ennemis ou homme non venus" end
        local lignes = l.decrire_personnage(e1[1], n1, true)
        local texte = table.concat(lignes, " | ")
        if not string.find(texte, "faction = brigands", 1, true) then return "description sans faction : " .. texte end
        if not string.find(texte, "personnellement = absente", 1, true) then return "fonction absente mal dite : " .. texte end
        if l.decrire_personnage("personne")[1] ~= "introuvable" then return "personnage absent mal dit" end
        -- Blesser (soul:DealDamage : vie, endurance, rien, vrai ; vu en jeu le 14/10, V19).
        local brigand = System.entites[e1[1]]
        brigand.soul = { DealDamage = function(self, vie, endurance, rien, drapeau) AI.coup = { vie, endurance, drapeau } end }
        if not l.blesser(e1[1], 1000) or AI.coup[1] ~= 1000 or AI.coup[2] ~= 1000 or AI.coup[3] ~= true then return "blessure mal donnée" end
        if l.blesser("personne", 1) then return "un absent blessé" end
        AI = nil
        -- Personnages : les propriétés données remplacent celles de la classe (vu le 14/10 : avec la seule âme, ils
        -- restaient inertes) ; un personnage reçoit une copie des propriétés de sa classe, plus son âme. Les objets,
        -- non (une copie de leurs propriétés physiques n'a pas été essayée en jeu).
        NPC = { Properties = { bWH_PerceptorObject = true, esNavigationType = "MediumSizedCharacters", CharacterSounds = { foleyEffect = "foleys_npc" } } }
        local recu = nil
        local naissance_d_origine = System.SpawnEntity
        function System.SpawnEntity(params) recu = params.properties ; return naissance_d_origine(params) end
        local h2 = l.faire_venir_homme(l.ame_de("combattant", 1, 2), "homme_2", p)
        if not h2 or not recu then return "personnage non venu" end
        if recu.guidSharedSoulId ~= "5c7a5c7a-0001-4001-8000-000000000002" then return "âme perdue dans les propriétés complètes" end
        if l.faire_venir_homme(nil, "homme_3", p) ~= nil then return "un homme venu sans âme" end
        if l.ame_de("combattant", 4, 1) or l.ame_de("combattant", 1, 81) or l.ame_de("femme", 1, 0) or l.ame_de("aucune", 1, 1) then
          return "âme rendue hors des réserves"
        end
        if recu.bWH_PerceptorObject ~= true or recu.esNavigationType ~= "MediumSizedCharacters" then return "propriétés de la classe NPC perdues" end
        recu.CharacterSounds.foleyEffect = "change"
        if NPC.Properties.CharacterSounds.foleyEffect ~= "foleys_npc" then return "propriétés de la classe partagées au lieu d'être copiées" end
        if NPC.Properties.guidSharedSoulId ~= nil then return "l'âme écrite dans la classe du jeu" end
        l.poser_objet("feu", "modele", p, 0, "feu_x")
        if recu.bWH_PerceptorObject ~= nil or recu.object_Model ~= "modele" then return "un objet a reçu les propriétés d'un personnage" end
        System.SpawnEntity = naissance_d_origine
        NPC = nil
        -- Argent d'Henry (règle de JoVenGer) : jamais un retrait de zéro, négatif, non entier, au-dessus de la bourse,
        -- ni avec une bourse illisible ; le 10/10, RemoveMoney(0) a vidé toute la bourse. Le moteur n'est jamais appelé
        -- pour un montant refusé.
        local bourse, appels = 100, {}
        player = { inventory = {
          GetMoney = function(self) return bourse end,
          RemoveMoney = function(self, n) table.insert(appels, "retirer " .. tostring(n)); bourse = bourse - n end,
          AddMoney = function(self, n) table.insert(appels, "donner " .. tostring(n)); bourse = bourse + n end,
        } }
        for _, montant in ipairs({ 0, -5, 2.5, 101, "10", 0 / 0, math.huge }) do
          if l.retirer_groschen_a_henry(montant) then return "retrait accepté : " .. tostring(montant) end
        end
        for _, montant in ipairs({ 0, -3, 1.5, "5" }) do
          if l.donner_groschen_a_henry(montant) then return "versement accepté : " .. tostring(montant) end
        end
        if #appels > 0 then return "le moteur a été appelé pour un montant refusé : " .. appels[1] end
        if not l.retirer_groschen_a_henry(100) or bourse ~= 0 then return "retrait juste refusé" end
        if not l.donner_groschen_a_henry(30) or bourse ~= 30 then return "versement juste refusé" end
        player.inventory.GetMoney = function(self) error("bourse illisible") end
        if l.retirer_groschen_a_henry(10) then return "retrait accepté avec une bourse illisible" end
        if #appels ~= 2 then return "appels au moteur inattendus : " .. #appels end
        player = nil
        -- Registre en tranches (note de JoVenGer : aucune valeur de plus de 65 535 octets). Un registre de 200 Ko se
        -- coupe, se recolle et se relit à l'identique ; une tranche abîmée ou d'une autre partie fait tout refuser.
        GameToken = { valeurs = {} }
        function GameToken.SetToken(nom, valeur) GameToken.valeurs[nom] = valeur end
        function GameToken.GetToken(nom) return GameToken.valeurs[nom] end
        local morceaux = {}
        for i = 1, 4000 do morceaux[i] = string.format("[%d]={[\\"nom\\"]=\\"homme_%d\\",[\\"moral\\"]=%d},", i, i, i % 100) end
        local gros = "{" .. table.concat(morceaux) .. "}"
        while #gros < 200000 do gros = "{[1]=" .. gros .. "}" end
        l.ecrire_registre(gros)
        l.memoire.registre = nil
        if l.lire_registre() ~= gros then return "registre de " .. #gros .. " octets mal recollé" end
        local tranches, plus_long = 0, 0
        for nom, valeur in pairs(GameToken.valeurs) do
          if string.find(nom, "^scriptorium_socle%.registre%.%d+$") and valeur ~= "" then
            tranches = tranches + 1
            plus_long = math.max(plus_long, #valeur)
          end
        end
        if tranches ~= math.ceil(#gros / l.taille_des_tranches) then return "nombre de tranches : " .. tranches end
        -- Le Lua du jeu compte en simple précision et écrit les grands nombres « 1.03997e+09 » (vu en jeu le 15/10) :
        -- l'en-tête ne porte que des chiffres, et sa somme reste sous 65 521.
        local entete = GameToken.valeurs["scriptorium_socle.registre"]
        local somme = tonumber(string.match(entete, "^[%w_]+|tranches|%d+|%d+|(%d+)$") or "")
        if not somme or somme >= 65521 then return "en-tête mal formé : " .. entete end
        if not string.find(l.entete_du_registre("p1", 2, string.rep("x", 1000000)), "^p1|tranches|2|1000000|%d+$") then
          return "en-tête d'un million de caractères mal écrit"
        end
        GameToken.valeurs["scriptorium_socle.registre"] = string.match(entete, "^([%w_]+)|") .. "|tranches|1|5434|1.03997e+09"
        l.memoire.registre = "{secours=1}"
        if l.lire_registre() ~= "{secours=1}" then return "un en-tête illisible n'est pas refusé" end
        GameToken.valeurs["scriptorium_socle.registre"] = entete
        l.memoire.registre = nil
        -- Les calculs qui doivent rester justes dans le jeu : mêmes valeurs qu'au banc, et aucun produit du hasard
        -- au-dessus de 2^24.
        local justes, ligne = l.verifier_les_nombres()
        if not justes then return "nombres attendus faux au banc : " .. ligne end
        for i, module in ipairs(Scriptorium.modules_du_hasard) do
          if Scriptorium.facteurs_du_hasard[i] * (module - 1) >= 16777216 then return "hasard au-dessus de 2^24" end
        end
        if plus_long > 65535 then return "une tranche dépasse 65 535 octets : " .. plus_long end
        -- Aucun jeton au-delà de 65 535 octets, essais compris (vu en jeu le 15/10 : la sauvegarde ne se recharge plus).
        local poses = 0
        local pose_d_origine = GameToken.SetToken
        GameToken.SetToken = function(nom, valeur) poses = poses + 1 ; return pose_d_origine(nom, valeur) end
        if l.essayer_un_jeton(65536) or poses ~= 0 then return "un jeton d'essai de 65 536 octets a été écrit" end
        local relu, intact = l.essayer_un_jeton(65535)
        if relu ~= 65535 or not intact or poses ~= 1 then return "le jeton d'essai de 65 535 octets n'est pas écrit et relu" end
        GameToken.SetToken = pose_d_origine
        GameToken.valeurs["scriptorium_socle.essai_jeton_65535"] = nil
        local juste = GameToken.valeurs["scriptorium_socle.registre.2"]
        GameToken.valeurs["scriptorium_socle.registre.2"] = string.gsub(juste, "homme", "hommx", 1)
        if l.lire_registre() ~= nil then return "une tranche abîmée n'est pas refusée" end
        GameToken.valeurs["scriptorium_socle.registre.2"] = string.gsub(juste, "^[%w_]+|", "p_autre|")
        if l.lire_registre() ~= nil then return "une tranche d'une autre partie n'est pas refusée" end
        GameToken.valeurs["scriptorium_socle.registre.2"] = juste
        if l.lire_registre() ~= gros then return "registre non relu une fois la tranche rendue" end
        -- La ronde (fiche 15, V73 d 2) : appelée par l'arbre, la liaison pose le point suivant et le regard, et écrit la
        -- pause dans les variables de l'arbre ; sans accroche, sans pas, ou sur une erreur, rien ne casse, et le journal
        -- le dit.
        local lignes, journal_d_origine = {}, System.LogAlways
        System.LogAlways = function(texte) table.insert(lignes, texte) end
        XGenAIModule = { variables = {} }
        function XGenAIModule.SetBrainVariable(id, nom, valeur) XGenAIModule.variables[nom] = valeur end
        local rondier = { this = { id = "wuid_rondier" } }
        function rondier:GetName() return "scriptorium_rondier" end
        local donnees = { ronde_pause = "2000ms" }
        l.pas_de_ronde = nil
        l.au_point_de_ronde(rondier, donnees)
        if donnees.ronde_pause ~= "2000ms" or XGenAIModule.variables.scriptorium_essai_point then
          return "ronde sans accroche : quelque chose a été posé"
        end
        l.accrocher_la_ronde(function(nom)
          if nom ~= "scriptorium_rondier" then return nil, "homme inconnu" end
          return { point = { x = 3, y = 4 }, regard = { x = 10, y = 0 }, pause_ms = 6500, longue = true, ici = 1,
                   suivant = 2, pas = 1, ecart = 0.4 }
        end)
        l.au_point_de_ronde(rondier, donnees)
        local pose, vers = XGenAIModule.variables.scriptorium_essai_point, XGenAIModule.variables.scriptorium_regard
        if donnees.ronde_pause ~= "6500ms" then return "pause de la ronde : " .. tostring(donnees.ronde_pause) end
        if not pose or pose.x ~= 3 or pose.y ~= 4 or pose.z ~= 7 then return "point de la ronde mal posé" end
        if not vers or vers.x ~= 10 or vers.y ~= 0 or vers.z ~= 7 then return "regard de la ronde mal posé" end
        if l.buts["scriptorium_rondier"] ~= pose or l.regards["scriptorium_rondier"] ~= vers then
          return "but ou regard de la ronde non retenus pour le poste d'essai"
        end
        if l.pas_de_ronde_vus["scriptorium_rondier"] ~= 1 then return "pas de ronde non comptés" end
        if not string.find(lignes[#lignes], "pas 1, au point 1 (à 0.4 m), vers le point 2 (3.0, 4.0), pause 6500 ms (longue)", 1, true) then
          return "ligne du pas de ronde : " .. tostring(lignes[#lignes])
        end
        local autre = { this = { id = "wuid_autre" } }
        function autre:GetName() return "scriptorium_autre" end
        XGenAIModule.variables = {}
        donnees.ronde_pause = "2000ms"
        l.au_point_de_ronde(autre, donnees)
        if donnees.ronde_pause ~= "2000ms" or XGenAIModule.variables.scriptorium_essai_point then
          return "un homme sans ronde a reçu un pas"
        end
        if not string.find(lignes[#lignes], "aucun pas (homme inconnu)", 1, true) then return "sans pas, rien n'est dit" end
        l.accrocher_la_ronde(function() error("panne") end)
        l.au_point_de_ronde(rondier, donnees)
        if not string.find(lignes[#lignes], "Ronde : erreur au point", 1, true) then return "une erreur de la ronde n'est pas écrite" end
        l.au_point_de_ronde(nil, donnees)
        if not string.find(lignes[#lignes], "Ronde : erreur au point", 1, true) then return "une entité absente n'est pas dite" end
        -- Le rassemblement (fiche 15, V73 e) : l'ordre de poste écrit l'allure, 1 en courant, 0 sinon (une garde qui suit
        -- un briefing ne court pas).
        System.entites["scriptorium_rondier"] = rondier
        XGenAIModule.variables = {}
        local but_avant, regard_avant = l.buts["scriptorium_rondier"], l.regards["scriptorium_rondier"]
        l.ordonner("scriptorium_rondier", "rassemblement", { x = 1, y = 1 }, "briefing", nil, nil, { x = 2, y = 2 }, "course")
        if XGenAIModule.variables.scriptorium_allure ~= 1 then return "rassemblement : allure " .. tostring(XGenAIModule.variables.scriptorium_allure) end
        if not string.find(lignes[#lignes], "en courant", 1, true) then return "l'ordre ne dit pas « en courant »" end
        l.ordonner("scriptorium_rondier", "garde", { x = 1, y = 1 }, "poste_1", nil, nil, { x = 2, y = 2 })
        if XGenAIModule.variables.scriptorium_allure ~= 0 then return "garde : allure " .. tostring(XGenAIModule.variables.scriptorium_allure) end
        System.entites["scriptorium_rondier"] = nil
        l.buts["scriptorium_rondier"], l.regards["scriptorium_rondier"] = but_avant, regard_avant
        -- Suivre (fiche 15, V73 f 1) : le WUID du chef écrit avant l'ordre 14 ; un chef introuvable : une marche.
        System.entites["scriptorium_rondier"] = rondier
        player = { nom = "henry" }
        local suivi = { GetName = function() return "scriptorium_chef_d_essai" end }
        System.entites["scriptorium_chef_d_essai"] = suivi
        XGenAIModule.GetMyWUID = function(e) return e == player and "wuid_henry" or (e == suivi and "wuid_chef" or nil) end
        XGenAIModule.variables = {}
        l.ordonner("scriptorium_rondier", "suivre", { x = 1, y = 1 }, "escorte", nil, nil, nil, nil, "henry")
        if XGenAIModule.variables.scriptorium_chef ~= "wuid_henry" then return "suivre Henry : chef " .. tostring(XGenAIModule.variables.scriptorium_chef) end
        if not string.find(lignes[#lignes], "suit « henry »", 1, true) then return "la ligne ne dit pas qui il suit" end
        l.ordonner("scriptorium_rondier", "suivre", { x = 1, y = 1 }, "escorte", nil, nil, nil, nil, "scriptorium_chef_d_essai")
        if XGenAIModule.variables.scriptorium_chef ~= "wuid_chef" then return "suivre un homme : chef " .. tostring(XGenAIModule.variables.scriptorium_chef) end
        l.ordonner("scriptorium_rondier", "suivre", { x = 1, y = 1 }, "escorte", nil, nil, nil, nil, "personne")
        if not string.find(lignes[#lignes], "introuvable, marche", 1, true) then return "un chef introuvable : " .. lignes[#lignes] end
        -- V73 f 1 bis : mener une formation (ordre 15, le modèle retenu pour l'arbre), s'y ranger (ordre 16).
        l.ordonner("scriptorium_rondier", "suivre", { x = 1, y = 1 }, "escorte", nil, nil, nil, nil, "henry", { mode = "mener", formation = "followNPC" })
        if not string.find(lignes[#lignes], "mène la formation « followNPC »", 1, true) then return "mener : " .. lignes[#lignes] end
        local donnees_f = {}
        l.nom_de_la_formation(rondier, donnees_f)
        if donnees_f.formation_nom ~= "followNPC" then return "le modèle n'est pas écrit pour l'arbre : " .. tostring(donnees_f.formation_nom) end
        l.ordonner("scriptorium_rondier", "suivre", { x = 1, y = 1 }, "escorte", nil, nil, nil, nil, "scriptorium_chef_d_essai", { mode = "formation" })
        if not string.find(lignes[#lignes], "se range dans la formation", 1, true) then return "se ranger : " .. lignes[#lignes] end
        donnees_f = {}
        l.nom_de_la_formation(rondier, donnees_f)
        if donnees_f.formation_nom ~= nil then return "un suiveur reçoit un modèle à ouvrir" end
        l.nom_de_la_formation(nil, donnees_f)
        if not string.find(lignes[#lignes], "Formation : erreur", 1, true) then return "une entité absente n'est pas dite" end
        -- V73 f 2 a : à cheval (ordre 17, le WUID du cheval) ; un cheval introuvable, à pied (ordre 14).
        local monture = { GetName = function() return "scriptorium_cheval_essai" end }
        System.entites["scriptorium_cheval_essai"] = monture
        XGenAIModule.GetMyWUID = function(e) return e == player and "wuid_henry" or (e == monture and "wuid_cheval" or nil) end
        XGenAIModule.variables = {}
        l.ordonner("scriptorium_rondier", "suivre", { x = 1, y = 1 }, "cavaliers", nil, nil, nil, nil, "henry", { mode = "cheval", cheval = "scriptorium_cheval_essai" })
        if XGenAIModule.variables.scriptorium_cheval ~= "wuid_cheval" then return "à cheval : WUID " .. tostring(XGenAIModule.variables.scriptorium_cheval) end
        if not string.find(lignes[#lignes], "monte « scriptorium_cheval_essai »", 1, true) then return "à cheval : " .. lignes[#lignes] end
        System.entites["scriptorium_cheval_essai"] = nil
        l.ordonner("scriptorium_rondier", "suivre", { x = 1, y = 1 }, "cavaliers", nil, nil, nil, nil, "henry", { mode = "cheval", cheval = "scriptorium_cheval_essai" })
        if not string.find(lignes[#lignes], "introuvable, suit « henry » à pied", 1, true) then return "cheval absent : " .. lignes[#lignes] end
        -- Le piège des doublures (transmis par le pair, 17/10) : pendant un dialogue, le jeu crée des doublures dont le nom
        -- contient celui de l'original (« DialogTwin_… ») ; en retirer une fait planter le jeu. Le retrait se fait par le
        -- nom exact : la doublure reste, même quand l'original n'est plus là.
        local doublure = "DialogTwin_scriptorium_cheval_essai"
        System.entites["scriptorium_cheval_essai"] = { id = newproxy() }
        System.entites[doublure] = { id = newproxy() }
        l.retirer_cheval("scriptorium_cheval_essai")
        if System.entites["scriptorium_cheval_essai"] ~= nil then return "cheval d'essai non retiré" end
        l.retirer_cheval("scriptorium_cheval_essai")
        if System.entites[doublure] == nil then return "une doublure de dialogue retirée avec le cheval" end
        System.entites[doublure] = nil
        System.entites["scriptorium_rondier"], System.entites["scriptorium_chef_d_essai"] = nil, nil
        XGenAIModule.GetMyWUID = nil
        l.buts["scriptorium_rondier"], l.regards["scriptorium_rondier"] = but_avant, regard_avant
        l.chefs["scriptorium_rondier"] = nil   -- la suite à pied ci-dessus lui a laissé Henry pour chef
        -- La vue d'Henry : à moins de 60° de son regard, il voit ; derrière lui, non ; sans Henry, rien de lisible.
        player = { GetWorldPos = function() return { x = 0, y = 0, z = 0 } end,
                   GetWorldAngles = function() return { x = 0, y = 0, z = 0 } end }   -- face au nord
        if l.henry_voit({ x = 1, y = 10 }, 0.5) ~= true then return "Henry ne voit pas devant lui" end
        if l.henry_voit({ x = 10, y = 1 }, 0.5) ~= false then return "Henry voit à 84° de son regard" end
        if l.henry_voit({ x = 0, y = -10 }, 0.5) ~= false then return "Henry voit derrière lui" end
        player = nil
        if l.henry_voit({ x = 1, y = 10 }, 0.5) ~= nil then return "sans Henry, une vue est rendue" end
        -- La lecture du poste d'essai (voir_sur_la_place) sur ce rondier : l'écart au but et les pas de ronde, sans
        -- erreur de format (sinon la seule lecture de la séance manquerait en jeu).
        function XGenAIModule.GetBrainVariable(id, nom) return 0 end
        function rondier:GetWorldPos() return { x = 0, y = 0, z = 7 } end
        function rondier:GetWorldAngles() return { x = 0, y = 0, z = 0 } end
        System.entites["scriptorium_rondier"] = rondier
        local lu, vue = pcall(l.voir_sur_la_place, "scriptorium_rondier", nil)
        System.entites["scriptorium_rondier"] = nil
        if not lu then return "lecture du poste sur un rondier : " .. tostring(vue) end
        if not string.find(vue, "à 5.00 m de son but, pas de ronde 1, à - m de son chef, en selle", 1, true) then return "lecture du poste : " .. vue end
        XGenAIModule = nil
        l.pas_de_ronde = nil
        System.LogAlways = journal_d_origine
        l.ecrire_registre("{a=2}")
        l.memoire.registre = nil
        if l.lire_registre() ~= "{a=2}" then return "un registre plus court n'est pas relu" end
        if GameToken.valeurs["scriptorium_socle.registre.3"] ~= "" then return "les tranches d'une écriture plus longue restent" end
        local identite = string.match(GameToken.valeurs["scriptorium_socle.registre"], "^([%w_]+)|")
        GameToken.valeurs["scriptorium_socle.registre"] = identite .. "|{ancien=1}"
        if l.lire_registre() ~= "{ancien=1}" then return "l'ancien format en un seul jeton n'est plus lu" end
        GameToken = nil
        return "ok"
    end)()""")
    if resultat != "ok":
        erreur("liaison : identifiants d'entités : " + str(resultat))
    # Les longueurs des jetons d'essai du poste restent sous 65 535 octets (vu en jeu le 15/10).
    longueurs = re.search(r"poste\.longueurs_de_jetons = \{([^}]*)\}", lire(os.path.join(PAK, "Scripts", "scriptorium", "poste.lua")))
    if not longueurs:
        erreur("poste : longueurs des jetons d'essai introuvables")
    else:
        trop = [n for n in (int(x) for x in re.findall(r"\d+", longueurs.group(1))) if n > 65535]
        if trop:
            erreur("poste : jetons d'essai au-delà de 65 535 octets : " + str(trop))


# ------------------------------------------------------------------ 3. noms interdits

TABLE_DES_AMES = os.path.join(PAK, "Libs", "Tables", "rpg", "soul__scriptorium_socle.xml")
TABLE_DES_FACTIONS = os.path.join(PAK, "Libs", "Tables", "rpg", "FactionTree__scriptorium_socle.xml")
NOTRE_CERVEAU = "b8a850d0-47c6-44a1-872e-ce7efcf4b9f9"


def verifier_ames():
    """Fiche 13 : la table des âmes (écrite par outils/ames.py) et les réserves de la liaison s'accordent, âme par âme ;
    chaque âme a notre cerveau, un nom et un identifiant uniques ; les femmes ont l'archétype féminin du jeu (1), les
    combattants un niveau de combat. Fiche 14 : toutes les âmes des réserves sont de la Compagnie, seule faction de la
    table des factions du socle, amie d'Henry, sans étiquette, sans lieu ni carte. Rend le nombre d'âmes des réserves."""
    lua = runtime_lua()
    if lua is None:
        return 0
    lua.execute("System = { LogAlways = function() end }")
    lua.execute(lire(os.path.join(PAK, "Scripts", "scriptorium", "noyau.lua")))
    lua.execute(lire(os.path.join(PAK, "Scripts", "scriptorium", "liaison.lua")))
    lignes = lua.eval("""(function()
        local l = Scriptorium.liaison_reelle
        local lignes = {}
        for reserve, r in pairs(l.reserves_d_ames) do
          for palier, taille in ipairs(r.paliers) do
            for numero = 1, taille do
              table.insert(lignes, reserve .. "|" .. palier .. "|" .. tostring(l.ame_de(reserve, palier, numero)))
            end
          end
        end
        return table.concat(lignes, "\\n")
    end)()""")
    attendues = {}
    for ligne in lignes.split("\n"):
        reserve, palier, ame = ligne.split("|")
        attendues[ame] = (reserve, int(palier))
    racine = ET.parse(TABLE_DES_AMES).getroot()
    ames = [s.attrib for s in racine.iter("soul")]
    noms = [a.get("soul_name") for a in ames]
    ids = [a.get("soul_id", "").lower() for a in ames]
    if len(set(noms)) != len(noms) or len(set(ids)) != len(ids):
        erreur("âmes : nom ou identifiant en double dans la table")
    for a in ames:
        if a.get("brain_id") != NOTRE_CERVEAU:
            erreur("âmes : %s n'a pas notre cerveau" % a.get("soul_name"))
    du_mod = {a["soul_id"].lower(): a for a in ames if a.get("soul_id", "").lower().startswith("5c7a5c7a")}
    for ame, (reserve, palier) in attendues.items():
        a = du_mod.get(ame)
        if a is None:
            erreur("âmes : %s (réserve %s, palier %d) absente de la table" % (ame, reserve, palier))
            continue
        if reserve == "femme" and a.get("soul_archetype_id") != "1":
            erreur("âmes : %s, une femme sans l'archétype féminin" % a.get("soul_name"))
        if reserve == "combattant" and not a.get("combat_level"):
            erreur("âmes : %s, un combattant sans niveau de combat" % a.get("soul_name"))
    for ame in du_mod:
        if ame not in attendues:
            erreur("âmes : %s dans la table, hors des réserves de la liaison" % du_mod[ame].get("soul_name"))
    compagnie = verifier_la_compagnie()
    for a in du_mod.values():
        if compagnie and a.get("factionName") != compagnie:
            erreur("âmes : %s n'est pas de la Compagnie (%s)" % (a.get("soul_name"), a.get("factionName")))
    return len(attendues)


def verifier_la_compagnie():
    """Fiche 14 : la table des factions du socle (écrite par outils/ames.py, qui vérifie les cibles dans l'arbre du jeu).
    Rend le nom de la Compagnie, ou None."""
    racine = ET.parse(TABLE_DES_FACTIONS).getroot()
    factions = list(racine.iter("Faction"))
    if racine.tag != "database" or racine.find("FactionTree") is None or len(factions) != 1:
        erreur("factions : une seule faction attendue, sous database/FactionTree")
        return None
    f = factions[0]
    nom = f.get("Name", "")
    if not nom.startswith("scriptorium_socle_"):
        erreur("factions : %s n'a pas le préfixe du socle" % nom)
    # Sans étiquette : « settlement » lui ôterait crime_skipInformationBroadcast ; « camp » ou « publicEnemy » ferait de nos
    # hommes des brigands pour les règles du jeu (isBandit). Sans lieu ni carte : valable partout, comme animalCompanions.
    for attribut in ("Labels", "LocationId", "LevelId"):
        if f.get(attribut):
            erreur("factions : la Compagnie porte %s" % attribut)
    relations = [(r.get("target", ""), r.get("reputation", "")) for r in f.iter("Relation")]
    for cible, reputation in relations:
        try:
            juste = cible != "" and -1 <= float(reputation) <= 1
        except ValueError:
            juste = False
        if not juste:
            erreur("factions : relation mal formée (%s, %s)" % (cible, reputation))
    if ("player", "1") not in relations:
        erreur("factions : la Compagnie n'est pas amie d'Henry")
    return nom


def verifier_equipement():
    """Fiche 13, V71 b : chaque préréglage que citent les règles d'équipement (hommes.equipement) est dans le bloc des
    pièces de la liaison (écrit par outils/equipement.py) ; chaque palier de chaque famille et de la tenue a au moins un
    préréglage ; chaque assemblage de tir a ses munitions ; chaque objet a la forme d'un identifiant. Rend le nombre de
    préréglages du bloc."""
    lua = runtime_lua()
    if lua is None:
        return 0
    lua.execute("System = { LogAlways = function() end }")
    for nom in ("noyau.lua", "liaison.lua", "hommes.lua"):
        lua.execute(lire(os.path.join(PAK, "Scripts", "scriptorium", nom)))
    rendu = lua.eval("""(function()
        local l = Scriptorium.liaison_reelle
        local e = Scriptorium.hommes.equipement
        local erreurs, noms = {}, l.noms_des_prereglages()
        local pavois = {}
        for _, liste in pairs(e.pavois) do for _, p in ipairs(liste) do pavois[p] = true end end
        local exclues = {}
        for _, nom in ipairs(e.tenue.exclues or {}) do
          if not l.pieces_de(nom) then table.insert(erreurs, "tenue exclue inconnue " .. nom) end
          exclues[nom] = true
        end
        local function candidats(sorte, bornes)
          local n = 0
          for _, nom in ipairs(noms) do
            local s, niveau = string.match(nom, "^(.-)_(%d+)_%d+$")
            niveau = tonumber(niveau)
            if s == sorte and niveau and niveau >= bornes.de and niveau <= bornes.a and not pavois[nom] and not exclues[nom] then n = n + 1 end
          end
          return n
        end
        for palier = 1, 3 do
          local cle = "palier_" .. palier
          if candidats(e.tenue.sorte, e.tenue[cle]) == 0 then table.insert(erreurs, "tenue " .. cle) end
          for famille, f in pairs(e.familles) do
            if candidats(f.sorte, f[cle]) == 0 then table.insert(erreurs, famille .. " " .. cle) end
          end
          for _, p in ipairs(e.pavois[cle] or {}) do
            if not l.pieces_de(p) then table.insert(erreurs, "pavois absent " .. p) end
          end
          if #(e.pavois[cle] or {}) == 0 then table.insert(erreurs, "pavois " .. cle) end
          for role, t in pairs(e.tir) do
            if #((t[cle] or {}).prereglages or {}) == 0 then table.insert(erreurs, role .. " " .. cle) end
            for _, p in ipairs((t[cle] or {}).prereglages or {}) do
              if not l.pieces_de(p) then table.insert(erreurs, "tir absent " .. p) end
              if not l.munition_de(p) then table.insert(erreurs, "munitions absentes " .. p) end
            end
          end
        end
        for _, nom in ipairs(noms) do
          for _, objet in ipairs(l.pieces_de(nom)) do
            if not string.match(objet, "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") then
              table.insert(erreurs, nom .. " : objet mal formé " .. tostring(objet))
            end
          end
        end
        return #noms .. "|" .. table.concat(erreurs, ";")
    end)()""")
    nombre, erreurs = rendu.split("|", 1)
    for e in [x for x in erreurs.split(";") if x]:
        erreur("équipement : " + e)
    if int(nombre) == 0:
        erreur("équipement : bloc des pièces vide (lancer outils/equipement.py)")
    return int(nombre)


def verifier_noms():
    compte = 0
    for chemin in fichiers(SOCLE, {".lua", ".xml", ".cfg", ".manifest", ".txt"}):
        texte = lire(chemin)
        for numero, ligne in enumerate(texte.splitlines(), 1):
            for motif, raison in MOTIFS_INTERDITS:
                if motif.search(ligne):
                    compte += 1
                    erreur("nom interdit (%s) : %s:%d : %s" % (raison, relatif(chemin), numero, ligne.strip()))
    return compte


# ------------------------------------------------------------------ 3 bis. un seul nom par table

# Note de JoVenGer (partie 2, point 5) : à la bascule, la table du socle deviendra « scriptorium.socle ». Seul le noyau
# la pose ; chaque autre fichier la reprend par sa première ligne de code ; aucune chaîne ne porte son nom ; aucun nom
# du socle ne diffère d'un autre par une majuscule seulement, sauf les noms imposés par le moteur.
REPRISE_DE_LA_TABLE = "local Scriptorium = Scriptorium"
NOMS_DU_MOTEUR = {"properties": "Properties des classes d'entités, properties de System.SpawnEntity",
                  "name": "Name de la classe sociale (soul:GetSocialClass().Name, Scripts/Utils/EntityUtils.lua)"}


def lignes_de_code(texte):
    """Les lignes sans commentaires ni contenu de chaînes (assez pour des noms)."""
    texte = re.sub(r"--\[\[.*?\]\]", " ", texte, flags=re.S)
    resultat = []
    for ligne in texte.splitlines():
        ligne = re.sub(r'"(?:[^"\\]|\\.)*"', '""', ligne)
        ligne = re.sub(r"'(?:[^'\\]|\\.)*'", "''", ligne)
        resultat.append(re.sub(r"--.*$", "", ligne).rstrip())
    return resultat


def verifier_un_seul_nom():
    morceaux = os.path.join(PAK, "Scripts", "scriptorium")
    formes = {}
    for chemin in fichiers(os.path.join(PAK, "Scripts"), {".lua"}):
        texte = lire(chemin)
        code = lignes_de_code(texte)
        nom = os.path.basename(chemin)
        poses = [i + 1 for i, ligne in enumerate(code) if re.match(r"^\s*Scriptorium\s*=", ligne)]
        if os.path.dirname(chemin) == morceaux and nom != "noyau.lua":
            if poses:
                erreur("un seul nom par table : %s pose la table du socle (ligne %d)" % (relatif(chemin), poses[0]))
            premiere = next((ligne.strip() for ligne in code if ligne.strip()), "")
            if premiere != REPRISE_DE_LA_TABLE:
                erreur("un seul nom par table : %s ne commence pas par « %s » : %s" % (relatif(chemin), REPRISE_DE_LA_TABLE, premiere))
        elif nom == "noyau.lua" and len(poses) != 1:
            erreur("un seul nom par table : le noyau doit poser la table une fois (%d)" % len(poses))
        for numero, ligne in enumerate(texte.splitlines(), 1):
            sans_commentaire = re.sub(r"--.*$", "", ligne)
            if re.search(r"""["']Scriptorium[.:]""", sans_commentaire):
                erreur("un seul nom par table : nom de la table dans une chaîne, %s:%d : %s" % (relatif(chemin), numero, ligne.strip()))
        for ligne in code:
            for mot in re.findall(r"[A-Za-z_][A-Za-z0-9_]*", ligne):
                formes.setdefault(mot.lower(), set()).add(mot)
    doubles = {cle: sorted(f) for cle, f in formes.items() if len(f) > 1 and cle not in NOMS_DU_MOTEUR}
    for cle, f in sorted(doubles.items()):
        erreur("un seul nom par table : noms qui ne diffèrent que par une majuscule : " + ", ".join(f))
    return len(formes)


# ------------------------------------------------------------------ 4. textes

def verifier_textes():
    definies = {}
    for chemin in fichiers(TEXTES, {".xml"}):
        # Le jeu ne charge comme textes de mod que les fichiers <nom>__<modid>.xml (constaté au journal le 14/10).
        if not os.path.basename(chemin).endswith("__scriptorium_socle.xml"):
            erreur("texte : %s : le nom doit finir par « __scriptorium_socle.xml », sinon le jeu ne le charge pas" % relatif(chemin))
        try:
            arbre = ET.parse(chemin)
        except ET.ParseError as exception:
            erreur("texte : %s mal formé : %s" % (relatif(chemin), exception))
            continue
        for rangee in arbre.getroot().iter("Row"):
            cellules = [(c.text or "").strip() for c in rangee.findall("Cell")]
            if len(cellules) != 3:
                erreur("texte : %s : une rangée n'a pas 3 cellules : %s" % (relatif(chemin), cellules))
                continue
            cle, source, traduction = cellules
            if not MOTIF_CLE.fullmatch(cle):
                erreur("texte : clé hors convention (ui_scriptorium_…) : %s" % cle)
            if cle in definies:
                erreur("texte : clé définie deux fois : %s" % cle)
            if not traduction:
                erreur("texte : traduction vide pour %s" % cle)
            if source != traduction:
                avertir("texte : source et traduction différentes pour %s" % cle)
            definies[cle] = traduction
    employees = {}
    for chemin in fichiers(PAK, {".lua"}):
        for numero, ligne in enumerate(lire(chemin).splitlines(), 1):
            for cle in MOTIF_CLE.findall(ligne):
                employees.setdefault(cle, []).append("%s:%d" % (relatif(chemin), numero))
    for cle, endroits in sorted(employees.items()):
        if cle not in definies:
            erreur("texte : clé employée mais jamais définie : %s (%s)" % (cle, endroits[0]))
    for cle in sorted(definies):
        if cle not in employees:
            erreur("texte : clé définie mais jamais employée : %s" % cle)
    return len(definies), len(employees)


# ------------------------------------------------------------------ 5. manifeste

def verifier_manifeste():
    chemin = os.path.join(SOCLE, "mod.manifest")
    if not os.path.exists(chemin):
        erreur("manifeste absent : socle/mod.manifest")
        return
    # Le jeu lit le manifeste en ASCII : un « — » est devenu « Scriptorium     socle » dans la sauvegarde (14/10).
    with open(chemin, "rb") as fichier:
        if any(octet > 127 for octet in fichier.read()):
            erreur("manifeste : caractère hors ASCII ; le jeu l'écrit mal dans la sauvegarde")
    try:
        racine = ET.parse(chemin).getroot()
    except ET.ParseError as exception:
        erreur("manifeste mal formé : %s" % exception)
        return
    modid = racine.findtext("info/modid")
    if modid != "scriptorium_socle":
        erreur("manifeste : modid attendu « scriptorium_socle », trouvé « %s »" % modid)
    for champ in ("name", "version", "author"):
        if not (racine.findtext("info/" + champ) or "").strip():
            erreur("manifeste : champ vide : " + champ)


# ------------------------------------------------------------------ 6. contrôle d'absence

def verifier_releve_des_noms():
    """Le relevé des noms ne prend que les définitions (affectations, fonctions), jamais les comparaisons."""
    noms = set(outil_empreintes.noms_du_lua("if a.role == 1 then end\nif b.total ~= 2 then end\nif c.lieu <= 3 then end"))
    if noms:
        erreur("contrôle d'absence : des comparaisons sont relevées comme des noms : " + ", ".join(sorted(noms)))
    noms = set(outil_empreintes.noms_du_lua("a.metier = 1\nfunction b.chercher() end"))
    if not {"metier", "chercher"} <= noms:
        erreur("contrôle d'absence : une affectation ou une fonction n'est pas relevée : " + ", ".join(sorted(noms)))
    # Le nom d'un fichier imposé par le jeu (mod.manifest) n'est pas un nom choisi ; un autre nom de fichier l'est.
    import tempfile
    with tempfile.TemporaryDirectory() as dossier:
        for nom in ("mod.manifest", "camp.lua"):
            with open(os.path.join(dossier, nom), "w", encoding="utf-8") as fichier:
                fichier.write("-- essai\n")
        releve, _ = outil_empreintes.relever(dossier)
        if outil_empreintes.empreinte("mod") in releve["noms"] or outil_empreintes.empreinte("camp") not in releve["noms"]:
            erreur("contrôle d'absence : noms de fichiers mal relevés (imposés par le jeu ou choisis)")


JEU = r"G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2"
# Les familles de fichiers XML du jeu de base dont le socle reprend la forme : (pak, début des chemins).
FAMILLES_DU_JEU = [(os.path.join("Data", "Tables.pak"), "Libs/Tables/"), (os.path.join("Data", "Scripts.pak"), "AI/")]


FORMES_ADMISES_AU_PLUS = 32   # au-delà, le banc échoue : revoir la liste, puis relever cette borne en connaissance
# (15/10 : 19 avec l'arbre qui s'assoit : Then, Else, IfElseCondition, StanceElement ; 21 avec CombatMoveDecorator ; 25 avec les balises fermantes de la chaîne de combat et SuppressFailure ; 26 avec MeleeOffenseAutomationDecorator ; 27 avec EntityContext ; revues)
# (16/10, V73 d 1 : 32 avec « <Else canSkip="1"> », la branche « sinon » de IsNightTimeOfDay, telle quelle dans
# AI/events/randomEventsBehaviors.xml du jeu ; revue)
# Les attributs d'une ligne de forme : structure des tables et des arbres, jamais un nom, une valeur ni un comportement.
ATTRIBUTS_DE_FORME = {"version", "xmlns:xsi", "xsi:noNamespaceSchemaLocation", "OneTimeOnly", "FailState", "saveVersion",
                      "canSkip", "is_function", "successMode", "failureMode"}
NOMS_DE_FORME = {"barbora", "onUpdate"}   # le nom de toutes les bases du jeu, le nom d'entrée des arbres


def est_une_ligne_de_forme(ligne):
    """Vrai pour une ligne de structure : déclaration XML, balise fermante, balise vide sans attribut, ou balise dont
    tous les attributs sont de structure (ATTRIBUTS_DE_FORME, et « name » seulement s'il vaut un NOMS_DE_FORME)."""
    if re.fullmatch(r'<\?xml version="1\.0" encoding="us-ascii"\?>', ligne) or re.fullmatch(r"</\w+>", ligne):
        return True
    balise = re.fullmatch(r"<\w+((?:\s+[\w:]+=\"[^\"]*\")*)\s*/?>", ligne)
    if not balise:
        return False
    for nom, valeur in re.findall(r'([\w:]+)="([^"]*)"', balise.group(1)):
        if nom == "name" and valeur in NOMS_DE_FORME:
            continue
        if nom not in ATTRIBUTS_DE_FORME:
            return False
    return True


def verifier_le_filtre_des_formes():
    """Le filtre des lignes de forme refuse toute ligne qui porte un nom, une valeur ou un comportement."""
    admises = ['<?xml version="1.0" encoding="us-ascii"?>', "</brains>", '<brains version="1">', "<ForestContainer />",
               '<Root OneTimeOnly="false" FailState="Recoverable" saveVersion="2">']
    refusees = ['<brain brain_id="b8a850d0" brain_name="scriptorium_essai_marche" />', '<Move speed="Walk" />',
                '<BehaviorTree name="secret" is_function="0">', '<Wait duration="5s" />', "<Sequence> <Move />"]
    for ligne in admises:
        if not est_une_ligne_de_forme(ligne):
            erreur("filtre des lignes de forme : ligne de structure refusée : " + ligne)
    for ligne in refusees:
        if est_une_ligne_de_forme(ligne):
            erreur("filtre des lignes de forme : ligne admise à tort : " + ligne)


def formes_du_jeu(lignes_d_alex):
    """Les lignes XML du socle communes avec Alex qui sont des lignes de forme (est_une_ligne_de_forme) et figurent
    aussi, telles quelles, dans les fichiers XML du jeu de base (lecture seule, en mémoire : rien n'est extrait), à
    chaque passage. Rend { empreinte : ligne }. Sans le jeu, aucune."""
    voulues = {}
    for chemin in fichiers(PAK, {".xml"}):
        for ligne in lire(chemin).splitlines():
            normalisee = outil_empreintes.normaliser_ligne(ligne, ".xml")
            marque = outil_empreintes.empreinte(normalisee)
            if len(normalisee) >= outil_empreintes.LIGNE_MIN and marque in lignes_d_alex and est_une_ligne_de_forme(normalisee):
                voulues[normalisee] = marque
    trouvees = {}
    for pak, debut in FAMILLES_DU_JEU:
        chemin_du_pak = os.path.join(JEU, pak)
        if not voulues or not os.path.exists(chemin_du_pak):
            continue
        with zipfile.ZipFile(chemin_du_pak) as archive:
            for info in archive.infolist():
                if not voulues or not info.filename.startswith(debut) or not info.filename.lower().endswith(".xml"):
                    continue
                info.orig_filename = info.filename.replace("/", "\\") if "\\" in info.orig_filename else info.orig_filename
                try:
                    texte = archive.open(info).read().decode("utf-8", "replace")
                except zipfile.BadZipFile:
                    continue
                for ligne in texte.splitlines():
                    normalisee = outil_empreintes.normaliser_ligne(ligne, ".xml")
                    if normalisee in voulues:
                        trouvees[voulues.pop(normalisee)] = normalisee
    return trouvees


# Décision de JoVenGer du 16/10/2026 (fiche 14) : les relations de la Compagnie sont celles de la faction du chien et du
# cheval d'Henry, recopiées de l'arbre des factions du jeu ; Alex a repris les mêmes lignes du jeu. Seules ces lignes-là
# sont admises : celles de la table des factions du socle qui sont, telles quelles, une relation de animalCompanions dans
# l'arbre du jeu (relu à chaque passage, en mémoire), au plus RELATIONS_DU_JEU_AU_PLUS. Sans le jeu, aucune.
FACTION_MODELE = "animalCompanions"
RELATIONS_DU_JEU_AU_PLUS = 8


def relations_du_jeu(lignes_d_alex):
    """Les lignes de la table des factions du socle communes avec Alex qui sont une relation de FACTION_MODELE dans
    Libs/Tables/rpg/FactionTree.xml du jeu. Rend { empreinte : ligne }."""
    voulues = {}
    for ligne in lire(TABLE_DES_FACTIONS).splitlines():
        normalisee = outil_empreintes.normaliser_ligne(ligne, ".xml")
        marque = outil_empreintes.empreinte(normalisee)
        if marque in lignes_d_alex and re.fullmatch(r'<Relation target="[^"]+" reputation="[^"]+" />', normalisee):
            voulues[normalisee] = marque
    chemin_du_pak = os.path.join(JEU, "Data", "Tables.pak")
    if not voulues or not os.path.exists(chemin_du_pak):
        return {}
    with zipfile.ZipFile(chemin_du_pak) as archive:
        texte = archive.read("Libs/Tables/rpg/FactionTree.xml").decode("utf-8", "replace")
    debut = texte.find('<Faction Name="%s"' % FACTION_MODELE)
    fin = texte.find("</Faction>", debut)
    if debut < 0 or fin < 0:
        return {}
    du_modele = {outil_empreintes.normaliser_ligne(l, ".xml") for l in texte[debut:fin].splitlines()}
    return {marque: ligne for ligne, marque in voulues.items() if ligne in du_modele}


def controle_absence(strict):
    verifier_releve_des_noms()
    if not os.path.exists(EMPREINTES):
        message = ("contrôle d'absence : empreintes d'Alex absentes (docs/socle/empreintes_alex.json) ; "
                   "examens fichiers, chemins, lignes, noms, clés et textes non faits. "
                   "Les relever avec outils/empreintes.py sur le PC.")
        if strict:
            erreur(message)
        else:
            avertir(message)
        return None
    with open(EMPREINTES, "r", encoding="utf-8") as fichier:
        alex = json.load(fichier)
    alex = {nom: set(alex.get(nom, [])) for nom in ("fichiers", "chemins", "lignes", "noms", "cles", "textes")}
    socle, _ = outil_empreintes.relever(SOCLE)

    # Chemins : on compare les chemins tels qu'ils seront dans le pak (socle/pak/…) et les textes.
    chemins_installes = set()
    for base in (PAK, os.path.join(TEXTES, "fr")):
        for racine, _, noms in os.walk(base):
            for nom in noms:
                chemins_installes.add(outil_empreintes.empreinte(
                    os.path.relpath(os.path.join(racine, nom), base).replace("\\", "/").lower()))
    socle["chemins"] = chemins_installes

    # Les lignes XML qui figurent telles quelles dans les fichiers du jeu de base (en-têtes des tables, nœuds des
    # arbres de comportement) sont la forme imposée par le jeu à tout mod, pas des lignes d'Alex : elles sont comptées
    # à part. Toute autre ligne en commun reste une erreur.
    verifier_le_filtre_des_formes()
    formes = formes_du_jeu(alex["lignes"])
    socle["lignes"] = socle["lignes"] - set(formes)
    for ligne in sorted(formes.values()):
        print("   ligne de forme du jeu : " + ligne)
    if len(formes) > FORMES_ADMISES_AU_PLUS:
        erreur("contrôle d'absence : %d lignes de forme du jeu, plus que les %d admises : revoir la liste"
               % (len(formes), FORMES_ADMISES_AU_PLUS))
    relations = relations_du_jeu(alex["lignes"])
    socle["lignes"] = socle["lignes"] - set(relations)
    for ligne in sorted(relations.values()):
        print("   relation du jeu (%s) : %s" % (FACTION_MODELE, ligne))
    if len(relations) > RELATIONS_DU_JEU_AU_PLUS:
        erreur("contrôle d'absence : %d relations du jeu, plus que les %d admises" % (len(relations), RELATIONS_DU_JEU_AU_PLUS))

    resultats = {}
    for nom in ("fichiers", "chemins", "lignes", "noms", "cles", "textes"):
        communs = socle[nom] & alex[nom]
        resultats[nom] = len(communs)
        if communs:
            erreur("contrôle d'absence : %d %s en commun avec Alex" % (len(communs), nom))
    resultats["lignes de forme du jeu"] = len(formes)
    resultats["relations du jeu"] = len(relations)
    if resultats["lignes"] or resultats["noms"] or resultats["textes"]:
        # Nommer les coupables, pour corriger vite.
        for chemin in list(fichiers(PAK, {".lua", ".xml", ".cfg"})) + list(fichiers(TEXTES, {".xml"})):
            texte = lire(chemin)
            extension = os.path.splitext(chemin)[1].lower()
            for numero, ligne in enumerate(texte.splitlines(), 1):
                normalisee = outil_empreintes.normaliser_ligne(ligne, extension)
                marque = outil_empreintes.empreinte(normalisee)
                if len(normalisee) >= outil_empreintes.LIGNE_MIN and marque in alex["lignes"] and marque not in formes \
                        and marque not in relations:
                    erreur("  ligne d'Alex : %s:%d" % (relatif(chemin), numero))
            if extension == ".lua":
                for identifiant in set(outil_empreintes.noms_du_lua(texte)):
                    if outil_empreintes.empreinte(identifiant) in alex["noms"]:
                        erreur("  nom d'Alex : %s : %s" % (relatif(chemin), identifiant))
            if extension == ".xml":
                cles, textes = outil_empreintes.cellules_du_xml(texte)
                for cle in cles:
                    if outil_empreintes.empreinte(cle) in alex["cles"]:
                        erreur("  clé d'Alex : %s : %s" % (relatif(chemin), cle))
                for t in textes:
                    if outil_empreintes.empreinte(t) in alex["textes"]:
                        erreur("  texte d'Alex : %s : %s…" % (relatif(chemin), t[:40]))
    return resultats


# ------------------------------------------------------------------ principal

ARBRES = os.path.join(PAK, "AI", "scriptorium")
TABLE_DES_VARIABLES = os.path.join(PAK, "Libs", "Tables", "ai", "brain_variable__scriptorium_socle.xml")
TABLE_DES_COMPORTEMENTS = os.path.join(PAK, "Libs", "Tables", "ai", "smartEntity", "SmartEntity__so_interrupt__scriptorium_socle.xml")


def verifier_la_vie_du_camp():
    """Fiche 12, révision du 16/10 : un oubli ici ne se verrait qu'en jeu, en silence. Chaque activité que la liaison
    donne a sa branche dans le comportement long ; chaque comportement lancé par le switch est déclaré auprès du jeu,
    et son arbre existe ; chaque variable du cerveau employée par nos arbres est déclarée. Rend (activités, variables)."""
    liaison = lire(os.path.join(PAK, "Scripts", "scriptorium", "liaison.lua"))
    arbres = {nom: lire(os.path.join(ARBRES, nom)) for nom in sorted(os.listdir(ARBRES)) if nom.endswith(".xml")}
    comportements = arbres.get("comportements.xml", "")
    donnees = set(re.findall(r"poser_l_activite\([^,()]*(?:\([^()]*\))?[^,()]*,\s*(\d+)\)", liaison))
    places = re.search(r"ordres_des_places\s*=\s*\{([^}]*)\}", liaison)
    if places:
        donnees |= set(re.findall(r"=\s*(\d+)", places.group(1)))
    if not donnees:
        erreur("vie du camp : aucune activité trouvée dans liaison.lua (poser_l_activite, ordres_des_places)")
    # L'activité 0 (attendre sur place, fiche 15, V73 b 3) n'a pas de branche : c'est la garde seule, au bas de la boucle.
    donnees.discard("0")
    branches = set(re.findall(r"\$scriptorium_activite == (\d+)", comportements))
    for activite in sorted(donnees - branches, key=int):
        erreur("vie du camp : l'activité %s est donnée par la liaison mais n'a pas de branche dans comportements.xml" % activite)
    declares = dict(re.findall(r'<SmartBehaviorTemplate Name="([^"]+)"[^>]*>\s*<TreeLocation TreeName="([^"]+)"', lire(TABLE_DES_COMPORTEMENTS)))
    noms_d_arbres = set(re.findall(r'<BehaviorTree name="([^"]+)"', comportements))
    for nom, texte in arbres.items():
        for lance in re.findall(r"<AddInterrupt Behavior=\"&apos;([^&]+)&apos;\"", texte):
            if lance not in declares:
                erreur("vie du camp : %s lance « %s », absent de %s" % (nom, lance, os.path.basename(TABLE_DES_COMPORTEMENTS)))
    for nom, arbre in declares.items():
        if arbre not in noms_d_arbres:
            erreur("vie du camp : « %s » est déclaré, mais son arbre « %s » n'est pas dans comportements.xml" % (nom, arbre))
    variables = set(re.findall(r'brain_variable_name="([^"]+)"', lire(TABLE_DES_VARIABLES)))
    employees = set()
    for texte in arbres.values():
        employees |= set(re.findall(r"\$(scriptorium_[a-z_]+)", texte))
    for variable in sorted(employees - variables):
        erreur("vie du camp : la variable du cerveau « %s » est employée par nos arbres mais pas déclarée" % variable)
    # V73 c 5 : « 0.5s » ne prend pas (la garde tournait sans attendre) ; les arbres du jeu n'écrivent que des nombres
    # entiers suivis de ms, s ou m, ou -1 (relevé du 16/10 dans Data/Scripts.pak), ou une variable (76 fois).
    for nom, texte in arbres.items():
        for duree in re.findall(r'duration="([^"]*)"', texte):
            litterale = re.fullmatch(r"&apos;(-1|\d+(ms|s|m))&apos;", duree)
            if not litterale and not re.fullmatch(r"\$[a-z_]+", duree):
                erreur("vie du camp : %s : durée « %s » hors des formes du jeu (entier suivi de ms, s ou m, ou -1, ou une variable)" % (nom, duree))
    # Fiche 12 (les valeurs de l'arbre en données) : chaque valeur de hommes.cerveau a sa variable de cerveau, déclarée,
    # lue par un arbre ; chaque variable du cerveau lue par un arbre a sa valeur au catalogue ; et l'arbre ne la lit
    # jamais seule, mais avec la valeur par défaut du catalogue (« (a > 0 ? a : défaut) »), qui doit être la même (V73 c 10).
    hommes_lua = lire(os.path.join(PAK, "Scripts", "scriptorium", "hommes.lua"))
    bloc = re.search(r"hommes\.cerveau = \{(.*?)\n\}", hommes_lua, re.S)
    cles = set(re.findall(r"^\s*([a-z_]+) = \d+", bloc.group(1), re.M)) if bloc else set()
    if not cles:
        erreur("vie du camp : la table hommes.cerveau est introuvable ou vide dans hommes.lua")
    declarees = set(re.findall(r'brain_variable_name="scriptorium_cerveau_([a-z_]+)" type="int"', lire(TABLE_DES_VARIABLES)))
    valeurs = dict((cle, int(v)) for cle, v in re.findall(r"^\s*([a-z_]+) = (\d+)", bloc.group(1), re.M)) if bloc else {}
    lues = set()
    for texte in arbres.values():
        lues |= set(re.findall(r"\$scriptorium_cerveau_([a-z_]+)", texte))
    for cle in sorted(cles - declarees):
        erreur("vie du camp : hommes.cerveau.%s n'a pas sa variable scriptorium_cerveau_%s déclarée" % (cle, cle))
    for nom, texte in arbres.items():
        lectures = re.findall(r"\$scriptorium_cerveau_([a-z_]+)", texte)
        defauts = re.findall(r"\(\$scriptorium_cerveau_([a-z_]+) &gt; 0 \? \$scriptorium_cerveau_([a-z_]+) : (\d+)\)", texte)
        if len(lectures) != 2 * len(defauts):
            erreur("vie du camp : %s lit une valeur du cerveau sans sa valeur par défaut" % nom)
        for cle, cle2, defaut in defauts:
            if cle != cle2 or valeurs.get(cle) != int(defaut):
                erreur("vie du camp : %s : défaut de %s = %s, le catalogue dit %s" % (nom, cle, defaut, valeurs.get(cle)))
    for cle in sorted(cles - lues):
        erreur("vie du camp : hommes.cerveau.%s n'est lue par aucun arbre" % cle)
    for cle in sorted(lues - cles):
        erreur("vie du camp : scriptorium_cerveau_%s est lue par un arbre mais n'est pas dans hommes.cerveau" % cle)
    # Fiche 15, V73 b 1 : la liaison (le secours, la lecture au poste) et le switch (la relance) disent « occupé » par
    # les mêmes contextes ; un nom changé d'un seul côté ne se verrait qu'en jeu.
    ligne = re.search(r"^local CONTEXTES_OCCUPE = (.*)$", liaison, re.M)
    occupe_liaison = set(re.findall(r'"([A-Za-z_]+)" \}', ligne.group(1))) if ligne else set()
    occupe_switch = set(re.findall(r'<EntityContextCheck context="([^"]+)"', arbres.get("essai_ordres.xml", "")))
    if not occupe_liaison or occupe_liaison != occupe_switch:
        erreur("vie du camp : contextes « occupé » de la liaison %s, du switch %s : ils doivent être les mêmes"
               % (sorted(occupe_liaison), sorted(occupe_switch)))
    # Fiche 15, V73 b 2 (le plafond de relances, proposition du pair) : le switch ne lance jamais la vie du camp hors de
    # son plafond, et il compte ses arrêts, que le battement dit au journal. Le banc ne joue pas les arbres : le
    # « 3 relances, puis arrêt » se mesure en jeu.
    switch = arbres.get("essai_ordres.xml", "")
    ouverts, gardes, lancements = [], 0, 0
    for fermant, nom, attributs, seul in re.findall(r"<(/?)(\w+)([^>]*?)(/?)>", switch):
        if nom == "IfCondition" and not fermant and not seul:
            condition = re.search(r'condition="([^"]*)"', attributs)
            ouverts.append(condition.group(1) if condition else "")
        elif nom == "IfCondition" and fermant and ouverts:
            ouverts.pop()
        elif nom == "AddInterrupt" and "&apos;scriptorium_vie_du_camp&apos;" in attributs:
            lancements += 1
            if any("$relances &lt; $relances_max" in c for c in ouverts):
                gardes += 1
    if lancements == 0 or gardes != lancements:
        erreur("vie du camp : %d lancement(s) de la vie du camp dans le switch, %d sous le plafond de relances"
               % (lancements, gardes))
    if "$scriptorium_vie_arrets = $scriptorium_vie_arrets + 1" not in switch:
        erreur("vie du camp : le switch ne compte pas ses arrêts (scriptorium_vie_arrets)")
    # V73 b 2, vu en jeu : retenu par le plafond, le switch restait « à lancer » alors que le pouls repartait, et relançait
    # à la fin de la fenêtre un comportement vivant. Un pouls qui avance le remet « en marche », quel que soit son état.
    if '<IfCondition condition="$scriptorium_vie_pouls ~= $pouls_vu"' not in switch:
        erreur("vie du camp : le pouls qui avance doit remettre le switch en marche quel que soit son état")
    # Fiche 13, la garde de la tenue (relecture du pair, principe d'Alex) : le switch compte les fins de combat au front
    # descendant du contexte de combat, lu à chaque tour ; le battement les relit pour rhabiller l'homme.
    front = re.search(r'<IfCondition condition="\$etait_en_combat &amp; ~\$en_combat"[^>]*>\s*'
                      r'<Expression expressions="\$scriptorium_fins_de_combat = \$scriptorium_fins_de_combat \+ 1" />', switch)
    if not front or '<Expression expressions="$etait_en_combat = $en_combat" />' not in switch:
        erreur("vie du camp : le switch doit compter les fins de combat au front descendant du contexte de combat")
    # Fiche 15, V73 d 1 (tenir un poste) : la liaison pose le point regardé avant l'ordre 12, et la branche 12 marche au
    # poste puis se tourne vers ce point ; un nom changé d'un seul côté ne se verrait qu'en jeu.
    if '"scriptorium_regard"' not in liaison or "poser_l_activite(entite, 12)" not in liaison:
        erreur("vie du camp : la liaison ne pose pas le point regardé (scriptorium_regard) avec l'ordre 12")
    branche = comportements.split("$scriptorium_activite == 12", 1)
    tourne = r'<Turn target="\$scriptorium_regard" align="false" />'
    if (len(branche) != 2 or 'destinationSpecification="$scriptorium_essai_point"' not in branche[1]
            or not re.search(tourne + r'\s*<Expression expressions="\$scriptorium_en_poste = \$scriptorium_en_poste \+ 1" />',
                             branche[1])
            or not re.search(r'<UnstanceAction unstance="LookingAround" locationObject="" slaveObject="" />\s*'
                             r'<SuppressFailure>\s*' + tourne, branche[1])):
        erreur("vie du camp : la branche 12 (tenir un poste) doit marcher au poste, se tourner vers $scriptorium_regard "
               "avant de se dire « en poste », et de nouveau après chaque geste")
    # Fiche 15, V73 d 2 (la ronde) : la liaison donne l'ordre 13 et sait recevoir l'appel de l'arbre ; la branche 13
    # marche au point, compte l'arrivée, met la pause par défaut, appelle la liaison sous pcall (relecture du pair : une
    # erreur non attrapée casse la branche) au nom de la table du socle, se tourne vers le dehors, puis attend la pause
    # écrite par le Lua. Aucun commentaire Lua dans un appel de l'arbre (le pair : « -- » coupe tout le reste, en silence).
    chemin = re.search(r'^Scriptorium\.chemin = "([A-Za-z_.]+)"', lire(os.path.join(PAK, "Scripts", "scriptorium", "noyau.lua")), re.M)
    appel = '<ExecuteLua code="pcall(function() %s.jeu.au_point_de_ronde(entity, data) end)" />' % (chemin.group(1) if chemin else "?")
    if ("poser_l_activite(entite, 13)" not in liaison or "function liaison.au_point_de_ronde(entite, donnees)" not in liaison
            or 'donnees.ronde_pause = string.format("%dms", pas.pause_ms)' not in liaison):
        erreur("vie du camp : la liaison doit donner l'ordre 13 et écrire la pause de la ronde (liaison.au_point_de_ronde)")
    branche = comportements.split("$scriptorium_activite == 13", 1)
    motif = (r'destinationSpecification="\$scriptorium_essai_point"[^>]*stopWithinDistance="\$ronde_arret" '
             r'stopDistanceVariation="\$ronde_ecart"[^>]*/>[\s\S]*?'
             r'<Expression expressions="\$scriptorium_essai_arrive = \$scriptorium_essai_arrive \+ 1" />\s*'
             r'</Sequence>\s*</SuppressFailure>\s*<Expression expressions="\$ronde_pause = concat\(\$sortie_ms, &apos;ms&apos;\)" />\s*'
             r'<SuppressFailure>\s*' + re.escape(appel) + r'\s*</SuppressFailure>\s*<SuppressFailure>\s*' + tourne
             + r'\s*</SuppressFailure>\s*<Wait duration="\$ronde_pause" ')
    if len(branche) != 2 or not re.search(motif, branche[1]):
        erreur("vie du camp : la branche 13 (la ronde) doit marcher au point, compter l'arrivée, appeler "
               "%s.jeu.au_point_de_ronde sous pcall, se tourner vers $scriptorium_regard, puis attendre $ronde_pause"
               % (chemin.group(1) if chemin else "?"))
    # Fiche 15, V73 e (le rassemblement) : la branche 12 écrit l'allure sous condition, sous la forme du jeu
    # (`$speed = $enum:movementSpeed.run`, AI/crime/followhelpingnpc.xml), et la donne au Move ; la liaison l'écrit avec
    # le point et le regard.
    branche12 = comportements.split("$scriptorium_activite == 12", 1)
    allure = (r'<Expression expressions="\$allure = \$enum:movementSpeed\.walk" />\s*'
              r'<IfCondition condition="\$scriptorium_allure == 1" failOnCondition="false">\s*'
              r'<Expression expressions="\$allure = \$enum:movementSpeed\.run" />\s*</IfCondition>[\s\S]*?'
              r'<Move destinationSpecification="\$scriptorium_essai_point"[^>]*speed="\$allure" stopWithinDistance="\$poste_arret"')
    if len(branche12) != 2 or not re.search(allure, branche12[1].split("$scriptorium_activite == 13")[0]):
        erreur("vie du camp : la branche 12 doit écrire l'allure (marche, puis course si $scriptorium_allure == 1) et la "
               "donner au Move du poste")
    if '<Variable name="allure" type="enum:movementSpeed"' not in comportements:
        erreur("vie du camp : la variable de l'arbre allure (enum:movementSpeed) n'est pas déclarée")
    if '"scriptorium_allure", allure == "course" and 1 or 0' not in liaison:
        erreur("vie du camp : la liaison doit écrire scriptorium_allure à chaque ordre de poste")
    # Fiche 15, V73 f 1 (suivre Henry) : la branche 14 appelle la fonction de suivi du jeu avec le chef du cerveau et nos
    # huit distances ; la liaison écrit le chef avant l'ordre 14 ; et la fonction du jeu a toujours ses paramètres (une
    # mise à jour du jeu casserait l'appel en silence).
    branche14 = comportements.split("$scriptorium_activite == 14", 1)
    attendus = {"leader": "$scriptorium_chef", "run2sprint": "$suivi_course_sprint", "run2walk": "$suivi_course_marche",
                "sprint2run": "$suivi_sprint_course", "sprint2walk": "$suivi_sprint_marche", "startDistance": "$suivi_depart",
                "stopDistance": "$suivi_arret", "walk2run": "$suivi_marche_course", "walk2sprint": "$suivi_marche_sprint"}
    appel_suivi = re.search(r"<Function_followNpc\b([^>]*)/>", branche14[1]) if len(branche14) == 2 else None
    trouves = dict(re.findall(r'(\w+)="([^"]*)"', appel_suivi.group(1))) if appel_suivi else {}
    if not appel_suivi or any(trouves.get(k) != v for k, v in attendus.items()):
        erreur("vie du camp : la branche 14 doit appeler Function_followNpc avec $scriptorium_chef et les huit distances : %s" % trouves)
    if "poser_l_activite(entite, 14)" not in liaison or '"scriptorium_chef", wuid' not in liaison:
        erreur("vie du camp : la liaison doit écrire scriptorium_chef avant l'ordre 14")
    pak = os.path.join(JEU, "Data", "Scripts.pak")
    if os.path.exists(pak):
        with zipfile.ZipFile(pak) as archive:
            utils = archive.read("AI/move/moveUtils.xml").decode("utf-8", "replace")
        fonction = re.search(r'<BehaviorTree name="followNpc" is_function="1">(.*?)</BehaviorTree>', utils, re.S)
        parametres = dict(re.findall(r'<Variable name="(\w+)" type="([^"]+)"[^>]*requirementType="In"', fonction.group(1))) if fonction else {}
        if not fonction or parametres.get("leader") != "_wuid" or set(attendus) - set(parametres):
            erreur("vie du camp : la fonction followNpc du jeu a changé (paramètres : %s)" % parametres)
    # Fiche 15, V73 f 1 bis (l'escorte en formation) : la branche 15 lit le modèle par le Lua, ouvre la formation et suit
    # son chef ; la branche 16 retrouve la formation du chef et s'y range ; chaque modèle du catalogue existe dans le jeu.
    branche15 = comportements.split("$scriptorium_activite == 15", 1)
    branche16 = comportements.split("$scriptorium_activite == 16", 1)
    appel15 = '<ExecuteLua code="pcall(function() %s.jeu.nom_de_la_formation(entity, data) end)" />' % (chemin.group(1) if chemin else "?")
    if (len(branche15) != 2 or appel15 not in branche15[1].split("$scriptorium_activite == 16")[0]
            or '<MakeFormation FormationName="$formation_nom" HandleVariable="$formation_menee" />' not in branche15[1]
            or '<Function_followNpc leader="$scriptorium_chef"' not in branche15[1].split("$scriptorium_activite == 16")[0]):
        erreur("vie du camp : la branche 15 doit lire le modèle par le Lua, ouvrir la formation et suivre son chef")
    if (len(branche16) != 2
            or '<GetMemberFormation MemberWUID="$scriptorium_chef" FormationHandleOut="$formation_suivie" />' not in branche16[1]
            or branche16[1].count('<FormationFollower FormationHandle="$formation_suivie"') != 4
            or '<Function_followNpc leader="$scriptorium_chef"' not in branche16[1]):
        erreur("vie du camp : la branche 16 doit retrouver la formation de son chef, s'y ranger (un nœud par mode), et le "
               "suivre normalement tant qu'elle n'est pas ouverte")
    # Relecture du pair : la formation n'est fermée que quand le chef cesse de mener (jamais au premier échec de sa marche :
    # chez Alex, cela défaisait toute la troupe) ; et « fermer avant d'ouvrir » : la branche 15 ferme l'ancienne formation
    # du même chef juste avant d'en ouvrir une (après un rattrapage, l'ordre redonné rouvrait sans fermer).
    fermer = re.search(r'<IfCondition condition="\$scriptorium_activite ~= 15 &amp; \$formation_menee ~= \$__null"[^>]*>\s*'
                       r'<SuppressFailure>\s*<EndFormation FormationHandle="\$formation_menee" />', comportements)
    avant_d_ouvrir = re.search(r'<SuppressFailure>\s*<EndFormation FormationHandle="\$formation_menee" />\s*</SuppressFailure>\s*'
                               r'<SuppressFailure>\s*<MakeFormation FormationName="\$formation_nom"', comportements)
    if not fermer or not avant_d_ouvrir or comportements.count("<EndFormation") != 2 or "<FuseBox" in comportements:
        erreur("vie du camp : la formation se ferme quand le chef cesse de mener, et juste avant d'en rouvrir une (deux "
               "EndFormation, aucun FuseBox)")
    if "poser_l_activite(entite, 15)" not in liaison or "poser_l_activite(entite, 16)" not in liaison:
        erreur("vie du camp : la liaison doit donner les ordres 15 et 16")
    bloc_formations = re.search(r"hommes\.formations = \{(.*?)\n\}", hommes_lua, re.S)
    modeles = re.findall(r"^\s*([A-Za-z_0-9]+) = \d+", bloc_formations.group(1), re.M) if bloc_formations else []
    if not modeles:
        erreur("vie du camp : la table hommes.formations est introuvable ou vide")
    if os.path.exists(pak):
        with zipfile.ZipFile(pak) as archive:
            definitions = archive.read("AI/FormationDefinitions.xml").decode("utf-8", "replace")
        for modele in modeles:
            if '<Formation name="%s">' % modele not in definitions:
                erreur("vie du camp : la formation « %s » du catalogue n'existe plus dans le jeu" % modele)
    # Fiche 15, V73 f 2 a (la sonde à cheval) : la branche 17 monte le cheval du cerveau par la posture « horse » du jeu
    # (la forme de moveOnHorse), y attend que la monture se stabilise, compte « en selle » et suit son chef ; si la monte
    # échoue, elle le suit à pied (jamais figé).
    branche17 = comportements.split("$scriptorium_activite == 17", 1)
    selle = (r'<Expression expressions="\$selle_avant = \$scriptorium_en_selle" />\s*<Parallel successMode="Any" failureMode="Any">\s*'
             r'<SuppressFailure>\s*'
             r'<StanceElement smartObject="\$scriptorium_cheval" stance="horse"[^>]*>\s*<Sequence>\s*<WaitAction />\s*'
             r'<Expression expressions="\$scriptorium_en_selle = \$scriptorium_en_selle \+ 1" />\s*'
             r'<Function_followNpc leader="\$scriptorium_chef"[^>]*/>\s*</Sequence>\s*</StanceElement>\s*</SuppressFailure>\s*'
             r'<Sequence>\s*<Wait duration="\$monte_delai"[^>]*/>\s*'
             r'<While doFail="false" propagateChildFail="false" condition="\$scriptorium_en_selle &gt; \$selle_avant">[\s\S]*?</Parallel>\s*'
             r'<Function_followNpc leader="\$scriptorium_chef"')
    if len(branche17) != 2 or not re.search(selle, branche17[1]):
        erreur("vie du camp : la branche 17 doit monter le cheval par la posture horse, suivre en selle, et à pied si la monte échoue")
    if "poser_l_activite(entite, 17)" not in liaison or '"scriptorium_cheval", wuid_monture' not in liaison:
        erreur("vie du camp : la liaison doit écrire scriptorium_cheval avant l'ordre 17")
    # Relecture du pair (V73 f 2 a) : le cheval naît sur une âme de cheval du jeu (archétype 3, classe 7, relue dans
    # Tables.pak, lecture seule), hors de la sauvegarde.
    ame = re.search(r'liaison\.ame_de_cheval = "([0-9a-f-]{36})"', liaison)
    if not ame or "guidSharedSoulId = liaison.ame_de_cheval, bSaved_by_game = false" not in liaison:
        erreur("vie du camp : le cheval doit naître sur une âme de cheval du jeu (liaison.ame_de_cheval), hors de la sauvegarde")
    tables = os.path.join(JEU, "Data", "Tables.pak")
    if ame and os.path.exists(tables):
        with zipfile.ZipFile(tables) as archive:
            ames = archive.read("Libs/Tables/rpg/soul.xml").decode("utf-8", "replace")
        ligne = re.search(r'<soul [^>]*soul_id="%s"[^>]*/>' % ame.group(1), ames)
        if not ligne or 'soul_archetype_id="3"' not in ligne.group(0) or 'soul_class_id="7"' not in ligne.group(0):
            erreur("vie du camp : l'âme %s n'est pas une âme de cheval du jeu (archétype 3, classe 7)" % ame.group(1))
    if '<Variable name="ronde_pause" type="_string"' not in comportements:
        erreur("vie du camp : la variable de l'arbre ronde_pause (_string) n'est pas déclarée")
    for nom, texte in arbres.items():
        for code in re.findall(r'<ExecuteLua code="([^"]*)"', texte):
            if "--" in code or "&#10;" in code:
                erreur("vie du camp : %s : un appel au Lua avec un commentaire ou sur plusieurs lignes : %s" % (nom, code))
    return len(donnees), len(employees)


def principal(arguments):
    strict = "--strict" in arguments
    print("Vérification complète du socle (%s)" % ("mode strict" if strict else "mode suivi"))

    lua = runtime_lua()
    if lua is not None:
        print("1. syntaxe Lua : %d fichiers" % verifier_syntaxe(lua))
        if not erreurs:
            reussis, echecs, nb_fichiers = executer_banc(lua)
            print("2. banc Lua : %d fichiers d'essais, %d vérifications réussies, %d échecs" % (nb_fichiers, reussis, echecs))
            taille = lua.globals().Essais.taille_du_registre_plein
            if taille:
                print("   registre d'un camp plein (80 hommes, livre plein, enceinte, réserves) : %d octets, %d tranche(s) de 30 000"
                      % (taille, -(-taille // 30000)))
            print("2 bis. ordres par fichier : %d commandes, aller-retour avec la liaison vérifié" % verifier_ordres())
            verifier_identifiants()
            print("2 ter. liaison : entités désignées par leur nom, caps de boussole, pose au sol, registre par jeton, argent d'Henry sûr, vérifié")
            print("2 quater. réglages par fichier : %d valeurs réglables, outil, liaison et installateur vérifiés"
                  % verifier_reglages_par_fichier())
        else:
            print("2. banc Lua : non lancé (syntaxe en erreur)")

    print("2 quinquies. âmes : %d âmes des réserves, table et liaison accordées, notre cerveau et la Compagnie partout" % verifier_ames())
    print("2 sexies. équipement : %d préréglages dans la liaison, chaque règle trouve les siens" % verifier_equipement())
    print("2 septies. vie du camp : %d activités données par la liaison, chacune a sa branche ; %d variables du cerveau "
          "employées par nos arbres, toutes déclarées ; comportements lancés déclarés" % verifier_la_vie_du_camp())
    print("3. noms interdits : %d" % verifier_noms())
    print("3 bis. un seul nom par table : %d noms relevés, table posée par le seul noyau" % verifier_un_seul_nom())
    definies, employees = verifier_textes()
    print("4. textes : %d clés définies, %d employées" % (definies, employees))
    verifier_manifeste()
    print("5. manifeste : vérifié")
    resultats = controle_absence(strict)
    if resultats is None:
        print("6. contrôle d'absence : non fait (empreintes absentes)")
    else:
        print("6. contrôle d'absence — " + " · ".join("%s %d" % (nom, n) for nom, n in resultats.items()))

    for message in avertissements:
        print("Avertissement : " + message)
    for message in erreurs:
        print("ERREUR : " + message)
    if erreurs:
        print("\nVérification complète : ÉCHEC (%d erreur(s))" % len(erreurs))
        return 1
    print("\nVérification complète : tout passe")
    return 0


if __name__ == "__main__":
    sys.exit(principal(sys.argv[1:]))
