#include "RemixPanel.h"

#include <optional>

#include "GenerateDialog.h"
#include "PluginManager.h"
#include "StyleMenu.h"
#include "core/dsp/ProblemAnalyzer.h"
#include "core/dsp/VocalChain.h"
#include "core/plugins/ChainStages.h"
#if SV_EDITION_IA
 #include "core/ai/AiClean.h"
#endif
#include "Theme.h"
#include "core/Log.h"
#include "core/assistant/CommandParser.h"

namespace sv::app
{
RemixPanel::RemixPanel (Session& s) : session (s)
{
    for (auto* c : std::initializer_list<juce::Component*> { &title, &roleLabel, &report, &assistantResult, &roleBox, &compBox,
                                                             &cleaning, &referenceEq, &rawListen, &referenceBtn,
                                                             &resetBtn, &generateBtn, &assistantBtn, &assistantText })
        addAndMakeVisible (*c);
    // Retour de Yann : pas de curseurs abstraits (autotune / présence / espace / énergie / volume / recalage) ni de
    // « Mon son » par-dessus les vrais effets — la chaîne du style (niveleur, résonances, compresseur, de-esser,
    // saturation, réverb, délai…) est l'interface. Ces composants restent cachés : l'assistant texte agit encore dessus.
    for (auto* c : std::initializer_list<juce::Component*> { &timing, &timingL, &savePresetBtn, &loadPresetBtn })
        addChildComponent (*c);

    title.setFont (juce::FontOptions (16.0f, juce::Font::bold));
    report.setMultiLine (true, true);
    report.setReadOnly (true);
    report.setCaretVisible (false);
    report.setScrollbarsShown (true);
    report.setFont (juce::FontOptions (12.0f));
    report.setColour (juce::TextEditor::textColourId, juce::Colours::lightgrey);
    report.setColour (juce::TextEditor::backgroundColourId, juce::Colours::transparentBlack);
    report.setColour (juce::TextEditor::outlineColourId, juce::Colours::transparentBlack);
    report.setColour (juce::TextEditor::focusedOutlineColourId, juce::Colours::transparentBlack);
    assistantResult.setFont (juce::FontOptions (11.0f));
    assistantResult.setColour (juce::Label::textColourId, juce::Colours::lightgreen);
    roleLabel.setText ("Type", juce::dontSendNotification);
    addAndMakeVisible (treatmentLabel);
    addAndMakeVisible (treatmentBox);
    addAndMakeVisible (pluginsTitle);
    addAndMakeVisible (addPluginBtn);
    addAndMakeVisible (chainTitle);
    chainTitle.setText ("Effets du style, dans l'ordre (clic = régler, clic droit = désactiver / revenir au style)"_u8, juce::dontSendNotification);
    chainTitle.setFont (juce::FontOptions (13.0f, juce::Font::bold));
    for (const auto& st : plugins::chainStages())
    {
        auto c = std::make_unique<StageCase>();
        const juce::String id (st.id);
        c->onPress = [this, id] (bool popup)
        {
            ensureTreated ("case "_u8 + id);   // piste brute : cliquer une case de la chaîne la passe en traité
            if (popup)
                showStageMenu (id);
            else
                openStageEditor (id);
        };
        addAndMakeVisible (*c);
        stageCases.push_back (std::move (c));
    }
    pluginsTitle.setText ("Effets en plus", juce::dontSendNotification);
    pluginsTitle.setFont (juce::FontOptions (13.0f, juce::Font::bold));
    addPluginBtn.setTooltip ("Ajoute un effet intégré (égaliseur, compresseur, de-esser, saturation, réverb, délai, porte, limiteur, "
                             "largeur) ou un plugin VST3 installé sur ce PC, appliqué après les effets du style. Recherche des VST3 : Paramètres."_u8);
    addPluginBtn.onClick = [this]
    {
        PluginManager::instance().showAddMenu (&addPluginBtn, [this] (const plugins::PluginSlot& slot)
        {
            modifyPlugins ([slot] (std::vector<plugins::PluginSlot>& v) { v.push_back (slot); }, "Ajout de l'effet " + slot.name);
        });
    };
    treatmentLabel.setText ("Style", juce::dontSendNotification);
    treatmentLabel.setFont (juce::FontOptions (14.0f, juce::Font::bold));
    treatmentBox.setTooltip ("Aucun = le son tel quel, sans effet ni mix auto. Choisis un style : tous les réglages de ce style "
                             "(autotune, EQ, compresseurs, de-esser, saturation, réverb, délai) s'appliquent à cette piste."_u8);
    treatmentBox.onChange = [this]
    {
        if (updating || shownTrack < 0)
            return;
        const int id = treatmentBox.getSelectedId();
        if (id == 1)
            session.setTrackTreatment (shownTrack, true, {});
        else if (id == 2)
            session.setTrackTreatment (shownTrack, false, {});   // instru : creux sous la voix
        else if (id == 3)
            session.setTrackTreatment (shownTrack, false, dsp::kCorrectionStyleId);
        else if (id > 100)
            session.setTrackTreatment (shownTrack, false, style::styleId (static_cast<style::Style> (id - 101)));
    };
    roleBox.setTooltip ("Type de piste : les effets se règlent automatiquement selon le type et le style"_u8);

    setupMacro (autotune, autotuneL, "Autotune", "Gauche : naturel / droite : effet robot");
    setupMacro (presence, presenceL, "Présence"_u8, "Voix plus chaude <-> plus brillante, plus devant");
    setupMacro (space, spaceL, "Espace", "Quantité de réverb et de délai"_u8);
    setupMacro (energy, energyL, "Énergie"_u8, "Compression et saturation");
    setupMacro (level, levelL, "Volume", "Niveau de la piste (±12 dB autour du réglage du style)"_u8);
    autotune.setTooltip ("Quantité de correction de justesse : 0 = aucune, position de départ = celle du style, à droite = effet robot "
                         "(double-clic = position du style)"_u8);

    timing.setRange (0.0, 1.0, 0.05);
    timing.setTextBoxStyle (juce::Slider::TextBoxRight, false, 44, 18);
    timing.onDragEnd = [this] { commitMacros ("Recalage rythmique"); };
    timingL.setText ("Recalage rythmique", juce::dontSendNotification);
    timing.setTooltip ("0 = désactivé. Rapproche les attaques de syllabes de la grille (doubles croches)."_u8);

    // Type de piste (réglages automatiques) : identifiant d'élément = rôle + 1.
    for (const auto r : style::userTrackRoles())
        roleBox.addItem (style::roleName (r), static_cast<int> (r) + 1);
    roleBox.onChange = [this]
    {
        if (updating || roleBox.getSelectedId() <= 0)
            return;
        const auto role = static_cast<style::Role> (roleBox.getSelectedId() - 1);
        session.updateTrack (shownTrack, [role] (project::Track& t)
        {
            if (role == style::Role::Instrument && t.role != style::Role::Instrument)
                t.cleaning = false;   // nettoyage de voix inutile sur un instrument
            t.role = role;
        }, true, "Type de piste"_u8);
    };
    compBox.addItem ("Prises : la plus récente gagne"_u8, 1);
    compBox.addItem ("Prises : meilleure automatique", 2);
    compBox.onChange = [this]
    {
        if (! updating)
            session.updateTrack (shownTrack, [m = compBox.getSelectedId() == 2] (project::Track& t) { t.comp = m ? project::CompMode::Best : project::CompMode::Latest; },
                                 true, "Assemblage des prises");
    };

    cleaning.onClick = [this]
    {
        if (updating)
            return;
        ensureTreated ("Nettoyage");
        session.updateTrack (shownTrack, [v = cleaning.getToggleState()] (project::Track& t) { t.cleaning = v; }, true, "Nettoyage");
    };
#if SV_EDITION_IA
    addAndMakeVisible (aiClean);
    aiClean.setTooltip ("Réseau DeepFilterNet (gratuit, sur ce PC) appliqué à la prise brute avant les effets du style : souffle, bruit de pièce, "
                        "ronflement. Nécessite l'outil installé dans l'onglet IA locale ; résultat mis en cache dans le projet."_u8);
    aiClean.onClick = [this]
    {
        if (updating)
            return;
        const bool v = aiClean.getToggleState();
        ensureTreated ("Nettoyage IA");
        session.updateTrack (shownTrack, [v] (project::Track& t) { t.aiClean = v; }, true, "Nettoyage IA");
        if (v && ! ai::local::deepFilterAvailable())   // outil absent : téléchargé à la demande, puis les voix sont recalculées
        {
            juce::WeakReference<Session> weak (&session);
            session.ensureToolsThen ({ "deep-filter" }, "Nettoyage IA"_u8, [weak] { if (auto* ss = weak.get()) ss->updateProject ([] (project::Project&) {}, true, {}); });
        }
    };
#endif
    referenceEq.onClick = [this]
    {
        if (updating)
            return;
        if (referenceEq.getToggleState() && session.project().referenceFile.isEmpty())
            session.setStatus ("Choisis d'abord un morceau de référence (bouton ci-dessous)"_u8);
        ensureTreated ("EQ de référence"_u8);
        session.updateTrack (shownTrack, [v = referenceEq.getToggleState()] (project::Track& t) { t.referenceEq = v; }, true, "EQ de référence"_u8);
    };
    rawListen.onClick = [this] { if (! updating) session.updateTrack (shownTrack, [v = ! rawListen.getToggleState()] (project::Track& t) { t.processingEnabled = v; }, false, {}); };

    referenceBtn.onClick = [this]
    {
        chooser = std::make_unique<juce::FileChooser> ("Morceau de référence (un son que tu aimes)"_u8, juce::File(), "*.wav;*.mp3;*.flac;*.aif;*.aiff;*.ogg");
        juce::Component::SafePointer<RemixPanel> safe (this);
        chooser->launchAsync (juce::FileBrowserComponent::openMode | juce::FileBrowserComponent::canSelectFiles, [safe] (const juce::FileChooser& fc)
        {
            if (safe != nullptr && fc.getResult() != juce::File())
                safe->session.setReferenceTrack (fc.getResult());
        });
    };
    savePresetBtn.onClick = [this]
    {
        if (const auto* t = session.project().findTrack (shownTrack))
        {
            session.settings().setUserPreset (session.project().style, t->macros);
            session.setStatus ("\"Mon son\" enregistré pour le style "_u8 + style::styleName (session.project().style));
        }
    };
    loadPresetBtn.onClick = [this]
    {
        const auto st = session.project().style;
        if (! session.settings().hasUserPreset (st))
        {
            session.setStatus ("Aucun \"Mon son\" enregistré pour "_u8 + style::styleName (st));
            return;
        }
        session.updateTrack (shownTrack, [m = session.settings().userPreset (st)] (project::Track& t) { t.macros = m; }, true, "Charger mon son");
    };
    resetBtn.onClick = [this]
    {
        session.updateTrack (shownTrack, [] (project::Track& t) { t.macros = {}; t.timingStrength = 0.0f; t.stages.clear(); }, true, "Réglages du style"_u8);
    };
    generateBtn.onClick = [this]
    {
        if (shownTrack >= 0)
            GenerateDialog::show (session, shownTrack);
    };

    assistantText.setTextToShowWhenEmpty ("Ex. : plus de réverb, voix plus sombre, beaucoup moins d'autotune"_u8, juce::Colours::grey);
    assistantText.onReturnKey = [this] { applyAssistant(); };
    assistantBtn.onClick = [this] { applyAssistant(); };
    refresh();
}

void RemixPanel::setupMacro (juce::Slider& s, juce::Label& l, const juce::String& name, const juce::String& tip)
{
    addChildComponent (s);   // caché : la chaîne d'effets remplace les curseurs abstraits
    addChildComponent (l);
    s.setRange (0.0, 1.0, 0.01);
    s.setDoubleClickReturnValue (true, 0.5);
    s.setTextBoxStyle (juce::Slider::TextBoxRight, false, 44, 18);
    s.setTooltip (tip + " (double-clic = réglage du style)"_u8);
    s.onDragStart = [this] { dragging = true; };
    s.onDragEnd = [this, name]
    {
        dragging = false;
        commitMacros (name);   // une seule étape d'annulation par geste (glisser, clic ou cran de molette)
    };
    s.onValueChange = [this, name]
    {
        // Hors glisser (clavier, double-clic) : appliqué tout de suite.
        if (! updating && ! dragging)
            commitMacros (name);
    };
    l.setText (name, juce::dontSendNotification);
}

void RemixPanel::ensureTreated (const juce::String& why)
{
    const auto* t = session.project().findTrack (shownTrack);
    if (t == nullptr || ! t->raw || t->isGenerated())
        return;
    SV_LOG_INFO ("VoixIA", "Piste brute « "_u8 + t->name + " » passée en traité (" + why + ")");
    session.setTrackTreatment (shownTrack, false, t->styleId);
}

void RemixPanel::commitMacros (const juce::String& undoLabelText)
{
    if (updating || shownTrack < 0)
        return;
    ensureTreated (undoLabelText);
    style::Macros m;
    if (const auto* t = session.project().findTrack (shownTrack))
        m = t->macros;
    m.autotune = static_cast<float> (autotune.getValue());
    m.presence = static_cast<float> (presence.getValue());
    m.space = static_cast<float> (space.getValue());
    m.energy = static_cast<float> (energy.getValue());
    m.level = static_cast<float> (level.getValue());
    m.custom = true;
    const float tim = static_cast<float> (timing.getValue());
    session.updateTrack (shownTrack, [m, tim] (project::Track& t) { t.macros = m; t.timingStrength = tim; }, true, undoLabelText);
}

void RemixPanel::applyAssistant()
{
    const auto* t = session.project().findTrack (shownTrack);
    if (t == nullptr)
        return;
    const auto res = assistant::apply (assistantText.getText(), t->macros);
    if (! res.understood)
    {
        assistantResult.setColour (juce::Label::textColourId, juce::Colours::orange);
        assistantResult.setText ("Pas compris. Essaie : plus/moins de réverb, délai, autotune, présence, énergie ; voix plus sombre/brillante…"_u8,
                                 juce::dontSendNotification);
        return;
    }
    assistantResult.setColour (juce::Label::textColourId, juce::Colours::lightgreen);
    assistantResult.setText (res.changes.joinIntoString (" | "), juce::dontSendNotification);
    session.updateTrack (shownTrack, [m = res.macros] (project::Track& tr) { tr.macros = m; }, true, "Assistant : " + assistantText.getText());
    assistantText.clear();
}

void RemixPanel::modifyPlugins (const std::function<void (std::vector<plugins::PluginSlot>&)>& change, const juce::String& undoLabel)
{
    const auto* t = session.project().findTrack (shownTrack);
    if (t == nullptr)
        return;
    auto slots = t->plugins;
    change (slots);
    session.setTrackPlugins (shownTrack, std::move (slots), undoLabel);
}

void RemixPanel::rebuildPluginRows (const project::Track& t)
{
    if (pluginRows.size() != t.plugins.size())
    {
        pluginRows.clear();
        for (size_t i = 0; i < t.plugins.size(); ++i)
        {
            auto row = std::make_unique<PluginRow>();
            const int index = static_cast<int> (i);
            row->open.onClick = [this, index]
            {
                const auto* tr = session.project().findTrack (shownTrack);
                if (tr == nullptr || index >= static_cast<int> (tr->plugins.size()))
                    return;
                const int trackId = shownTrack;
                juce::WeakReference<Session> weak (&session);
                PluginManager::instance().openEditor (tr->plugins[static_cast<size_t> (index)], [weak, trackId, index] (const juce::MemoryBlock& state)
                {
                    auto* s = weak.get();
                    if (s == nullptr)
                        return;
                    const auto* tr2 = s->project().findTrack (trackId);
                    if (tr2 == nullptr || index >= static_cast<int> (tr2->plugins.size()))
                        return;
                    auto slots = tr2->plugins;
                    slots[static_cast<size_t> (index)].state = state;
                    s->setTrackPlugins (trackId, std::move (slots), "Réglage du plugin "_u8 + tr2->plugins[static_cast<size_t> (index)].name);
                });
            };
            row->bypass.setClickingTogglesState (true);
            row->bypass.setColour (juce::TextButton::buttonOnColourId, juce::Colours::orange);
            row->bypass.setTooltip ("Contourner ce plugin");
            row->bypass.onClick = [this, index]
            {
                if (updating) return;
                modifyPlugins ([index] (std::vector<plugins::PluginSlot>& v) { if (index < static_cast<int> (v.size())) v[static_cast<size_t> (index)].bypass = ! v[static_cast<size_t> (index)].bypass; },
                               "Contournement du plugin");
            };
            row->remove.setTooltip ("Retirer ce plugin");
            row->remove.onClick = [this, index]
            {
                modifyPlugins ([index] (std::vector<plugins::PluginSlot>& v) { if (index < static_cast<int> (v.size())) v.erase (v.begin() + index); },
                               "Retrait du plugin");
            };
            for (auto* b : { &row->open, &row->bypass, &row->remove })
                addAndMakeVisible (*b);
            pluginRows.push_back (std::move (row));
        }
        resized();
    }
    for (size_t i = 0; i < pluginRows.size(); ++i)
    {
        pluginRows[i]->open.setButtonText (juce::String (static_cast<int> (i) + 1) + ". " + t.plugins[i].name);
        pluginRows[i]->open.setTooltip ("Ouvrir la fenêtre du plugin (ses réglages sont repris à la fermeture)"_u8);
        pluginRows[i]->bypass.setToggleState (t.plugins[i].bypass, juce::dontSendNotification);
    }
}

void RemixPanel::fillTreatmentBox (bool instru)
{
    treatmentForInstru = instru;
    treatmentProjectStyle = static_cast<int> (session.project().style);
    treatmentBox.clear (juce::dontSendNotification);
    if (instru)
    {
        treatmentBox.addItem ("Brute : instru telle quelle"_u8, 1);
        treatmentBox.addItem ("Creux sous la voix (mix auto)", 2);
        treatmentBox.addItem ("Correction automatique (son propre : niveau régulier, bruit, résonances, écrêtage) + creux"_u8, 3);
        return;
    }
    treatmentBox.addItem ("Aucun (brut, aucun effet)", 1);
    treatmentBox.addItem ("Correction automatique (son propre : niveau régulier, bruit, résonances, EQ, sifflantes, justesse)"_u8, 3);
    // Styles par famille : identifiant = 101 + indice du style.
    for (const auto& g : style::styleGroups())
    {
        treatmentBox.addSectionHeading (juce::String (juce::CharPointer_UTF8 (g.name)));
        for (const auto st : g.styles)
            treatmentBox.addItem (style::styleName (st), 101 + static_cast<int> (st));
    }
}

void RemixPanel::refresh()
{
    const juce::ScopedValueSetter<bool> svs (updating, true);
    shownTrack = session.selectedTrack();
    const auto* t = session.project().findTrack (shownTrack);
    const bool vocal = t != nullptr && t->isVocal();
    // Brute ou traitée, tous les réglages restent actifs : sur une piste brute, le premier geste (curseur, case, chaîne)
    // la passe en traité par son style (ensureTreated), au lieu de curseurs grisés qui « ne font rien ».
    for (auto* c : std::initializer_list<juce::Component*> { &autotune, &presence, &space, &energy, &level, &timing, &cleaning, &referenceEq,
                                                             &rawListen, &savePresetBtn, &loadPresetBtn, &resetBtn, &assistantBtn, &assistantText })
        c->setEnabled (vocal);
    for (auto* c : std::initializer_list<juce::Component*> { &roleBox, &compBox })
        c->setEnabled (vocal);
    generateBtn.setEnabled (t != nullptr && t->role == style::Role::Lead);
    treatmentBox.setVisible (t != nullptr && ! t->isGenerated());
    treatmentLabel.setVisible (treatmentBox.isVisible());
    addPluginBtn.setEnabled (t != nullptr);
    if (t != nullptr)
        rebuildPluginRows (*t);
    else if (! pluginRows.empty())
    {
        pluginRows.clear();
        resized();
    }
    if (t == nullptr)
    {
        title.setText ("Aucune piste sélectionnée"_u8, juce::dontSendNotification);
        report.setText ({}, false);
        updateStageCases (nullptr);
        return;
    }
    const bool instru = t->role == style::Role::Instru;
    if (treatmentBox.getNumItems() == 0 || instru != treatmentForInstru || treatmentProjectStyle != static_cast<int> (session.project().style))
        fillTreatmentBox (instru);   // libellé « Style du projet (…) » à jour, sans tout reconstruire à chaque rafraîchissement
    treatmentBox.setSelectedId (t->raw ? 1 : t->isCorrection() ? 3 : (instru ? 2 : 101 + static_cast<int> (session.project().trackStyle (*t))),
                                juce::dontSendNotification);
    const auto trackStyleName = style::styleName (session.project().trackStyle (*t));
    title.setText (t->name + "  (" + style::roleName (t->role) + (t->raw ? juce::String (", brut") : ", style " + trackStyleName) + ")",
                   juce::dontSendNotification);
    updateStageCases (t);
    if (dragging)
        return;   // ne pas ramener le curseur à l'ancienne valeur pendant le geste
    // Brut : tout à 0 (aucun effet) ; sinon les curseurs du style (0,5 = réglage du style).
    // Positions réelles : celles du style de la piste tant que l'utilisateur n'a rien bougé (chaque style a les siennes).
    const auto base = style::makeParams (session.project().trackStyle (*t), t->role, {}, ! t->isGenerated());
    const auto stylePos = style::styleMacros (base);
    const auto cur = style::resolveMacros (t->macros, base);
    // Piste brute : les curseurs montrent les positions du style (ce qui s'appliquera au premier geste), pas des zéros.
    autotune.setValue (cur.autotune, juce::dontSendNotification);
    presence.setValue (cur.presence, juce::dontSendNotification);
    space.setValue (cur.space, juce::dontSendNotification);
    energy.setValue (cur.energy, juce::dontSendNotification);
    level.setValue (cur.level, juce::dontSendNotification);
    autotune.setDoubleClickReturnValue (true, stylePos.autotune);
    presence.setDoubleClickReturnValue (true, stylePos.presence);
    space.setDoubleClickReturnValue (true, stylePos.space);
    energy.setDoubleClickReturnValue (true, stylePos.energy);
    level.setDoubleClickReturnValue (true, 0.5);
    timing.setValue (t->timingStrength, juce::dontSendNotification);
    cleaning.setToggleState (t->cleaning, juce::dontSendNotification);
#if SV_EDITION_IA
    aiClean.setToggleState (t->aiClean, juce::dontSendNotification);
    aiClean.setEnabled (vocal);
    aiClean.setButtonText (ai::local::deepFilterAvailable() ? "Nettoyage IA (DeepFilterNet, avant la chaîne)"_u8
                                                            : "Nettoyage IA (DeepFilterNet) : téléchargé à la première utilisation"_u8);
#endif
    referenceEq.setToggleState (t->referenceEq, juce::dontSendNotification);
    rawListen.setToggleState (! t->processingEnabled, juce::dontSendNotification);
    roleBox.setVisible (! t->isGenerated() && vocal);
    roleLabel.setVisible (roleBox.isVisible());
    roleBox.setSelectedId (static_cast<int> (t->role) + 1, juce::dontSendNotification);
    compBox.setVisible (! t->isGenerated() && vocal);
    compBox.setSelectedId (t->comp == project::CompMode::Best ? 2 : 1, juce::dontSendNotification);

    juce::String txt = session.trackStatus (shownTrack);
    if (t->isGenerated())
        txt << "\nGénéré : "_u8 << t->detail;
    if (auto r = session.renderFor (shownTrack))
    {
        if (vocal)
        {
            txt << "\nPrise traitée : "_u8 << juce::String (r->report.clean.plosivesTreated) << " plosives, " << juce::String (r->report.clean.breathsTreated)
                << " respirations ; " << juce::String (r->report.phrases) << " phrases ; bruit -"_u8 << juce::String (r->report.clean.noiseReducedDb, 1) << " dB"
                << (r->report.clean.clippedRepaired > 0 ? " ; " + juce::String (r->report.clean.clippedRepaired) + " échantillons écrêtés reconstruits"_u8 : juce::String());
        }
    }
    if (session.project().referenceFile.isNotEmpty())
        txt << "\nRéférence : "_u8 << juce::File (session.project().referenceFile).getFileName();
    if (auto r = session.renderFor (shownTrack); r != nullptr && ! r->pluginNotes.isEmpty())
        txt << "\nPlugins : " << r->pluginNotes.joinIntoString (" > ");
    if (auto r = session.renderFor (shownTrack); r != nullptr && r->aiNote.isNotEmpty())
        txt << "\n" << r->aiNote;
    if (const float ag = session.autoTrackGainDb (shownTrack); std::abs (ag) >= 0.3f)
        txt << "\nOrchestre : gain auto " << (ag >= 0.0f ? "+" : "") << juce::String (ag, 1) << " dB (place de la piste par rapport à la voix principale, "_u8
            << juce::String (render::roleOffsetLu (t->role), 0) << " LU)";
    if (const auto corr = session.trackCorrections (shownTrack); corr.isNotEmpty())
        txt << "\nCorrigé automatiquement : "_u8 << corr;
    if (const auto warn = session.trackWarnings (shownTrack); warn.isNotEmpty())
        txt << "\nÀ faire : "_u8 << warn;
    if (vocal && t->raw)
    {
        txt << "\n\nBrute : le son tel quel, aucun effet (seul son niveau est équilibré avec les autres pistes). Pour la traiter : "
               "choisis un style dans « Style », ou clique un effet de la chaîne ci-dessus — la piste passe alors en style "
               << trackStyleName << " avec les réglages de ce style."_u8;
    }
    else if (t->isCorrection())
    {
        txt << (vocal ? "\n\nCorrection automatique : le son est analysé et remis propre (niveau régulier, bruit, résonances, équilibre, sifflantes, justesse), "
                        "sans effet de style.\n"_u8
                      : "\n\nCorrection automatique de l'instru : analysée puis réparée en stéréo liée (écrêtage, bruit, niveau régulier d'un passage à l'autre, "
                        "résonances, équilibre, limiteur), puis creux sous la voix (mix auto).\n"_u8);
        if (auto r = session.renderFor (shownTrack); r != nullptr && r->problemsReport.isNotEmpty())
            txt << r->problemsReport;
        else
            txt << "Analyse en cours…"_u8;
    }
    else if (vocal)
    {
        // Effets réglés automatiquement par le style (et les curseurs) : affichés même avant la première prise.
        const auto st = session.project().trackStyle (*t);
        txt << "\n\nEffets appliqués (style "_u8 << style::styleName (st) << ", " << style::roleName (t->role) << ") :\n"
            << dsp::describeChain (chainParams (*t, true));
        if (! t->stages.empty())
        {
            auto manual = chainParams (*t, false);
            txt << "\nChaîne réglée à la main : "_u8 << plugins::applyStageOverrides (t->stages, manual);
        }
        if (auto r = session.renderFor (shownTrack); r != nullptr && ! r->fitNotes.isEmpty())
            txt << "\nRéglé d'après la mesure de la prise : "_u8 << r->fitNotes.joinIntoString (" ; ");
        if (auto r = session.renderFor (shownTrack); r != nullptr && r->problemsReport.isNotEmpty())
            txt << "\n" << r->problemsReport;
    }
    else if (t->role == style::Role::Instru)
    {
        txt << (t->raw ? "\n\nInstru brute : jouée telle quelle."_u8
                       : "\n\nInstru : creux automatique sous la voix (mix auto, réglable dans Mix & Master)."_u8);
    }
    if (report.getText() != txt)
        report.setText (txt, false);   // pas de remise à zéro du défilement si rien n'a changé
}

void RemixPanel::paint (juce::Graphics& g)
{
    g.fillAll (theme::panel);
}

style::VocalParams RemixPanel::chainParams (const project::Track& t, bool withOverrides) const
{
    const auto st = session.project().trackStyle (t);
    auto p = style::makeParams (st, t.role, t.macros, ! t.isGenerated());
    p.timing.strength = t.timingStrength;
    p.clean.enabled = t.cleaning;
    // Piste rendue avec ce style : les valeurs affichées sont celles réellement utilisées (style ajusté à la mesure de la prise).
    if (auto r = session.renderFor (t.id); r != nullptr && r->ok() && ! t.raw && ! t.isCorrection() && r->paramsStyle == static_cast<int> (st))
        p = r->paramsUsed;
    if (withOverrides && ! t.stages.empty())
        plugins::applyStageOverrides (t.stages, p);
    return p;
}

void RemixPanel::updateStageCases (const project::Track* t)
{
    // Cases pour une piste voix hors correction automatique (dont une piste brute : les cases montrent la chaîne du style,
    // cliquer l'une d'elles passe la piste en traité). Correction automatique : réglages déduits de l'analyse, dans le rapport.
    const bool show = t != nullptr && t->isVocal() && ! t->isCorrection();
    if (show != chainVisible)
    {
        chainVisible = show;
        chainTitle.setVisible (show);
        for (auto& c : stageCases)
            c->setVisible (show);
        resized();
    }
    if (! show)
        return;
    const auto base = chainParams (*t, false);
    const auto& stages = plugins::chainStages();
    for (size_t i = 0; i < stages.size() && i < stageCases.size(); ++i)
    {
        const auto& st = stages[i];
        auto& c = *stageCases[i];
        const auto it = t->stages.find (juce::String (st.id));
        const bool bypassed = it != t->stages.end() && it->second.bypass;
        const bool manual = it != t->stages.end() && ! bypassed && it->second.state.getSize() > 0;
        auto p = base;
        if (it != t->stages.end())
            plugins::applyStageOverrides ({ { it->first, it->second } }, p);
        const bool active = ! bypassed && plugins::stageActive (st, p);
        const juce::String name (juce::CharPointer_UTF8 (st.name));
        c.setButtonText (name + (bypassed ? " (off)" : active ? " : " + plugins::stageSummary (st, p) : juce::String (" : off")));
        c.setColour (juce::TextButton::buttonColourId, bypassed ? juce::Colour (0xff5a3d1e) : active ? (manual ? juce::Colour (0xff2b5d8a) : juce::Colour (0xff2e6b3a))
                                                                                                    : juce::Colour (0xff2a2f36));
        c.setColour (juce::TextButton::textColourOffId, active || bypassed ? juce::Colours::white : juce::Colours::grey);
        c.setTooltip (name + " : " + (bypassed ? juce::String ("contourné (clic droit pour le rétablir)"_u8)
                                             : (manual ? juce::String ("réglé à la main — "_u8) : juce::String ("réglé par le style — "_u8)) + plugins::stageSummary (st, p))
                      + "\nClic : réglages. Clic droit : contourner / revenir au réglage du style."_u8);
    }
}

void RemixPanel::openStageEditor (const juce::String& stageId)
{
    const auto* t = session.project().findTrack (shownTrack);
    const auto* st = plugins::findStage (stageId);
    if (t == nullptr || st == nullptr)
        return;
    const auto it = t->stages.find (stageId);
    plugins::PluginSlot slot;
    slot.identifier = st->pluginId;
    slot.name = juce::String (juce::CharPointer_UTF8 (st->name));
    slot.state = it != t->stages.end() && it->second.state.getSize() > 0 ? it->second.state : plugins::stageState (*st, chainParams (*t, false));
    const int trackId = shownTrack;
    juce::WeakReference<Session> weak (&session);
    // Réglage de départ : remis en place à la fermeture avant l'étape d'annulation, pour que « Annuler » revienne au point initial.
    std::optional<plugins::StageOverride> original;
    if (it != t->stages.end())
        original = it->second;
    SV_LOG_INFO ("VoixIA", "Chaîne de « "_u8 + t->name + " » : réglages de l'étape "_u8 + stageId + " ouverts (en direct)"_u8);
    PluginManager::instance().openEditor (slot,
        [weak, trackId, stageId, original] (const juce::MemoryBlock& state)   // fermeture : une seule étape d'annulation
        {
            auto* s = weak.get();
            if (s == nullptr)
                return;
            s->setTrackStage (trackId, stageId, original.has_value() ? &*original : nullptr, {});
            plugins::StageOverride ov;
            ov.bypass = false;
            ov.state = state;
            s->setTrackStage (trackId, stageId, &ov, "Réglage de l'étape "_u8 + stageId);
        },
        [weak, trackId, stageId] (const juce::MemoryBlock& state)   // en direct : sans étape d'annulation
        {
            auto* s = weak.get();
            if (s == nullptr)
                return;
            plugins::StageOverride ov;
            ov.bypass = false;
            ov.state = state;
            s->setTrackStage (trackId, stageId, &ov, {});
        });
}

void RemixPanel::showStageMenu (const juce::String& stageId)
{
    const auto* t = session.project().findTrack (shownTrack);
    const auto* st = plugins::findStage (stageId);
    if (t == nullptr || st == nullptr)
        return;
    const auto it = t->stages.find (stageId);
    const bool bypassed = it != t->stages.end() && it->second.bypass;
    juce::PopupMenu m;
    m.addSectionHeader (juce::String (juce::CharPointer_UTF8 (st->name)));
    m.addItem (1, "Réglages..."_u8);
    m.addItem (2, "Contourner cette étape"_u8, true, bypassed);
    m.addItem (3, "Revenir au réglage du style"_u8, it != t->stages.end());
    const int trackId = shownTrack;
    juce::WeakReference<Session> weak (&session);
    juce::Component::SafePointer<RemixPanel> safe (this);
    m.showMenuAsync (juce::PopupMenu::Options(), [weak, safe, trackId, stageId, bypassed] (int r)
    {
        auto* s = weak.get();
        if (s == nullptr || r == 0)
            return;
        if (r == 1)
        {
            if (safe != nullptr)
                safe->openStageEditor (stageId);
        }
        else if (r == 2)
        {
            plugins::StageOverride ov;
            ov.bypass = ! bypassed;
            if (const auto* tr = s->project().findTrack (trackId))
                if (auto it2 = tr->stages.find (stageId); it2 != tr->stages.end())
                    ov.state = it2->second.state;   // les réglages manuels sont gardés derrière le contournement
            s->setTrackStage (trackId, stageId, &ov, ov.bypass ? "Contourner l'étape "_u8 + stageId : "Rétablir l'étape "_u8 + stageId);
        }
        else if (r == 3)
            s->setTrackStage (trackId, stageId, nullptr, "Étape "_u8 + stageId + " : réglage du style"_u8);
    });
}

void RemixPanel::resized()
{
    auto r = getLocalBounds().reduced (10);
    title.setBounds (r.removeFromTop (24));
    auto row = [&r] (int h = 24) { auto x = r.removeFromTop (h); r.removeFromTop (4); return x; };
    auto a = row (26);
    treatmentLabel.setBounds (a.removeFromLeft (60));
    treatmentBox.setBounds (a);
    a = row();
    roleLabel.setBounds (a.removeFromLeft (40));
    roleBox.setBounds (a.removeFromLeft (150));
    a.removeFromLeft (6);
    compBox.setBounds (a);
    r.removeFromTop (4);
    if (chainVisible)
    {
        chainTitle.setBounds (row (20));
        for (auto& c : stageCases)
            c->setBounds (row (24));   // une ligne par effet : nom + réglages lisibles
        r.removeFromTop (4);
    }
    cleaning.setBounds (row());
#if SV_EDITION_IA
    aiClean.setBounds (row());
#endif
    referenceEq.setBounds (row());
    rawListen.setBounds (row());
    a = row (28);
    referenceBtn.setBounds (a.removeFromLeft (a.getWidth() / 2 - 3));
    a.removeFromLeft (6);
    resetBtn.setBounds (a);
    generateBtn.setBounds (row (32));
    r.removeFromTop (4);
    a = row (24);
    pluginsTitle.setBounds (a.removeFromLeft (110));
    addPluginBtn.setBounds (a.removeFromLeft (150));
    for (auto& pr : pluginRows)
    {
        a = row (24);
        pr->remove.setBounds (a.removeFromRight (26));
        a.removeFromRight (3);
        pr->bypass.setBounds (a.removeFromRight (26));
        a.removeFromRight (3);
        pr->open.setBounds (a);
    }
    r.removeFromTop (6);
    a = row (26);
    assistantBtn.setBounds (a.removeFromRight (80));
    a.removeFromRight (4);
    assistantText.setBounds (a);
    assistantResult.setBounds (row (32));
    report.setBounds (r);
}
} // namespace sv::app
