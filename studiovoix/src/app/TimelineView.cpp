#include "TimelineView.h"

#if SV_EDITION_IA
 #include "core/ai/AiClean.h"
#endif

#include "NewTrackDialog.h"
#include "Theme.h"
#include "core/Log.h"

namespace sv::app
{
namespace
{
    juce::Colour roleColour (style::Role r)
    {
        switch (r)
        {
            case style::Role::Instru:      return juce::Colour (0xff5b6b7a);
            case style::Role::Lead:        return juce::Colour (0xff3fa7ff);
            case style::Role::Double:      return juce::Colour (0xff59c3c3);
            case style::Role::Harmony:     return juce::Colour (0xffb38cff);
            case style::Role::KeywordBack: return juce::Colour (0xffffb347);
            case style::Role::AdLib:       return juce::Colour (0xffff6f91);
            case style::Role::Ambiance:    return juce::Colour (0xff8bc34a);
            case style::Role::ManualBack:  return juce::Colour (0xfff0d264);
            case style::Role::Instrument:  return juce::Colour (0xffd98c5f);
            case style::Role::Count:       break;
        }
        return juce::Colours::grey;
    }

    juce::Colour sectionColour (const juce::String& kind)
    {
        if (kind == "refrain") return juce::Colour (0xffc0392b);
        if (kind == "couplet") return juce::Colour (0xff2c7fb8);
        if (kind == "pont")    return juce::Colour (0xff8e44ad);
        return juce::Colour (0xff566573);
    }
}

// =============================================================================================
void RecArmButton::paintButton (juce::Graphics& g, bool highlighted, bool down)
{
    const auto r = getLocalBounds().toFloat().reduced (2.0f);
    const float d = std::min (r.getWidth(), r.getHeight());
    const auto c = r.withSizeKeepingCentre (d, d);
    const bool on = getToggleState();
    const auto red = theme::danger;
    g.setColour (on ? (down ? red.darker (0.3f) : red) : (down ? juce::Colour (0xff5a2a2a) : juce::Colour (0xff3a2a2a)));
    g.fillEllipse (c);
    g.setColour (on ? juce::Colours::white.withAlpha (0.85f) : red);
    g.drawEllipse (c.reduced (0.5f), highlighted ? 2.0f : 1.4f);
}

TrackHeader::TrackHeader (Session& s, int trackId) : session (s), id (trackId)
{
    for (auto* c : std::initializer_list<juce::Component*> { &arm, &name, &info, &mute, &solo, &raw, &remove, &more, &volume, &pan })
        addAndMakeVisible (*c);
    more.setButtonText ("\xE2\x8B\xAF"_u8);   // ⋯ (U+22EF) en octets UTF-8 : MSVC sans /utf-8 casserait l'échappement \u
    more.setTooltip ("Tout ce qui concerne cette piste : importer, style et effets, IA, découpe, ordre, suppression (ou clic droit)"_u8);
    more.onClick = [this]
    {
        session.selectTrack (id, false, false);
        if (auto* tv = findParentComponentOfClass<TimelineView>())
            tv->openTrackMenu (id);
    };

    arm.setTooltip ("Armer la piste : le micro enregistrera sur cette piste (puis R ou REC)"_u8);
    arm.onClick = [this]
    {
        if (! updating)
            session.armTrack (session.armedTrack() == id ? -1 : id);
    };

    name.setFont (juce::FontOptions (14.0f, juce::Font::bold));
    name.setEditable (false, true);
    name.onTextChange = [this]
    {
        const auto txt = name.getText().trim();
        if (txt.isNotEmpty())
            session.updateTrack (id, [txt] (project::Track& t) { t.name = txt; }, false, "Renommer la piste");
    };
    info.setFont (juce::FontOptions (11.0f));
    info.setColour (juce::Label::textColourId, juce::Colours::lightgrey);
    info.setInterceptsMouseClicks (false, false);
    meter.setCompact (true);
    meter.setInterceptsMouseClicks (false, false);
    addAndMakeVisible (meter);

    mute.setClickingTogglesState (true);
    solo.setClickingTogglesState (true);
    raw.setClickingTogglesState (true);
    mute.setColour (juce::TextButton::buttonOnColourId, juce::Colours::orange);
    solo.setColour (juce::TextButton::buttonOnColourId, juce::Colours::yellow.darker());
    raw.setColour (juce::TextButton::buttonOnColourId, juce::Colours::purple);
    raw.setTooltip ("A/B : écouter la voix brute (sans traitement)"_u8);
    remove.setTooltip ("Supprimer la piste");
    mute.onClick = [this] { if (! updating) session.updateTrack (id, [v = mute.getToggleState()] (project::Track& t) { t.mute = v; }, false, {}); };
    solo.onClick = [this] { if (! updating) session.updateTrack (id, [v = solo.getToggleState()] (project::Track& t) { t.solo = v; }, false, {}); };
    raw.onClick = [this] { if (! updating) session.updateTrack (id, [v = ! raw.getToggleState()] (project::Track& t) { t.processingEnabled = v; }, false, {}); };
    remove.onClick = [this]
    {
        juce::WeakReference<Session> weak (&session);
        const int tid = id;
        juce::AlertWindow::showAsync (juce::MessageBoxOptions().withIconType (juce::MessageBoxIconType::QuestionIcon)
                                          .withTitle ("Supprimer la piste")
                                          .withMessage ("Supprimer cette piste ? (Annuler permet de revenir en arrière)"_u8)
                                          .withButton ("Supprimer")
                                          .withButton ("Garder"),
                                      [weak, tid] (int result)
                                      {
                                          if (result == 1)
                                              if (auto* sess = weak.get())
                                                  sess->removeTrack (tid);
                                      });
    };

    volume.setSliderStyle (juce::Slider::LinearHorizontal);
    volume.setTextBoxStyle (juce::Slider::TextBoxRight, false, 52, 18);
    volume.setRange (-30.0, 12.0, 0.1);
    volume.setTextValueSuffix (" dB");
    volume.setDoubleClickReturnValue (true, 0.0);
    volume.setScrollWheelEnabled (false);   // la molette fait défiler la liste des pistes
    volume.onValueChange = [this]
    {
        if (! updating)
            session.updateTrack (id, [v = static_cast<float> (volume.getValue())] (project::Track& t) { t.volumeDb = v; }, false, {});
    };
    pan.setSliderStyle (juce::Slider::LinearHorizontal);
    pan.setTextBoxStyle (juce::Slider::NoTextBox, false, 0, 0);
    pan.setRange (-1.0, 1.0, 0.01);
    pan.setDoubleClickReturnValue (true, 0.0);
    pan.setScrollWheelEnabled (false);
    pan.setTooltip ("Panoramique (double-clic = centre)");
    pan.onValueChange = [this]
    {
        if (! updating)
            session.updateTrack (id, [v = static_cast<float> (pan.getValue())] (project::Track& t) { t.pan = v; }, false, {});
    };
    refresh();
}

void TrackHeader::refresh()
{
    const juce::ScopedValueSetter<bool> svs (updating, true);
    const auto* t = session.project().findTrack (id);
    if (t == nullptr)
        return;
    if (! name.isBeingEdited())   // setText fermerait l'éditeur pendant un renommage
        name.setText (t->name, juce::dontSendNotification);
    juce::String txt = style::roleName (t->role);
    if (t->raw)
        txt << " | brut";
    else if (t->styleId.isNotEmpty())
        txt << " | " << style::styleName (style::styleFromId (t->styleId));
    if (! t->takes.empty())
        txt << " | " << juce::String ((int) t->takes.size()) << " prise(s)" << (t->comp == project::CompMode::Best ? " (meilleure auto)" : "");
    auto st = session.trackStatus (id);
    if (st.startsWith ("Prêt — "_u8))   // le détail des prises est dans le panneau ; l'en-tête reste sur deux lignes
        st = "Prêt"_u8 + st.fromFirstOccurrenceOf (" | ", true, false);
    if (st.isNotEmpty())
        txt << "\n" << st;
    const auto warn = session.trackWarnings (id);
    if (warn.isNotEmpty())
        txt << "\n" << juce::String (juce::CharPointer_UTF8 ("\xe2\x9a\xa0 ")) << warn;
    info.setColour (juce::Label::textColourId, warn.isNotEmpty() ? juce::Colour (0xffff8a65) : juce::Colours::lightgrey);
    info.setText (txt, juce::dontSendNotification);
    arm.setVisible (t->isRecordable());
    arm.setToggleState (session.armedTrack() == id, juce::dontSendNotification);
    mute.setToggleState (t->mute, juce::dontSendNotification);
    solo.setToggleState (t->solo, juce::dontSendNotification);
    raw.setToggleState (! t->processingEnabled, juce::dontSendNotification);
    raw.setVisible (t->isVocal());
    volume.setValue (t->volumeDb, juce::dontSendNotification);
    pan.setValue (t->pan, juce::dontSendNotification);
    repaint();
}

void TrackHeader::updateMeter()
{
    const float now = session.trackPeakNow (id);
    meterLevel = std::max (now, meterLevel * 0.82f);   // retombée douce
    if (meterLevel < 1.0e-4f)
        meterLevel = 0.0f;
    meter.setLevel (meterLevel, false);
}

void TrackHeader::paint (juce::Graphics& g)
{
    const auto* t = session.project().findTrack (id);
    const bool selected = session.isTrackSelected (id);
    const auto r = getLocalBounds().toFloat().reduced (1.0f);
    g.setColour (selected ? theme::selection : theme::card);
    g.fillRoundedRectangle (r, theme::radius);
    if (t != nullptr)
    {
        g.setColour (roleColour (t->role));
        g.fillRoundedRectangle (r.withWidth (10.0f), theme::radius);
        g.fillRect (r.withWidth (5.0f).withX (r.getX() + 5.0f));
    }
    g.setColour (session.armedTrack() == id ? theme::danger : (selected ? theme::accent.withAlpha (0.7f) : theme::line));
    g.drawRoundedRectangle (r, theme::radius, session.armedTrack() == id ? 2.0f : 1.0f);
}

void TrackHeader::mouseDown (const juce::MouseEvent& e)
{
    // Ctrl + clic : ajoute à la sélection ; Maj + clic : étend ; clic droit sur une piste déjà sélectionnée : garde la sélection.
    if (! (e.mods.isPopupMenu() && session.isTrackSelected (id)))
        session.selectTrack (id, e.mods.isCtrlDown() || e.mods.isCommandDown(), e.mods.isShiftDown());
    if (e.mods.isPopupMenu())
        if (auto* tv = findParentComponentOfClass<TimelineView>())
            tv->openTrackMenu (id);
}

void TrackHeader::mouseDrag (const juce::MouseEvent& e)
{
    if (e.mods.isPopupMenu() || session.isRecording())
        return;
    if (! reordering && std::abs (e.getDistanceFromDragStartY()) < 8)
        return;
    if (auto* tv = findParentComponentOfClass<TimelineView>())
    {
        const bool first = ! reordering;
        reordering = true;
        setMouseCursor (juce::MouseCursor::UpDownResizeCursor);
        tv->dragTrackHeader (id, e.getEventRelativeTo (tv).y, first);
    }
}

void TrackHeader::mouseUp (const juce::MouseEvent&)
{
    if (reordering)
    {
        reordering = false;
        setMouseCursor (juce::MouseCursor::NormalCursor);
        session.setStatus ("Ordre des pistes modifié (Ctrl+Z pour annuler)"_u8);
    }
}

void TrackHeader::resized()
{
    auto r = getLocalBounds().reduced (8, 3);
    r.removeFromLeft (2);
    auto top = r.removeFromTop (20);
    arm.setBounds (top.removeFromLeft (20));
    top.removeFromLeft (4);
    remove.setBounds (top.removeFromRight (22));
    top.removeFromRight (2);
    more.setBounds (top.removeFromRight (24));
    top.removeFromRight (2);
    raw.setBounds (top.removeFromRight (40));
    top.removeFromRight (2);
    solo.setBounds (top.removeFromRight (22));
    top.removeFromRight (2);
    mute.setBounds (top.removeFromRight (22));
    name.setBounds (top);
    meter.setBounds (r.removeFromTop (6).reduced (0, 1));
    const bool faders = getHeight() >= 64;   // piste trop basse : seuls le nom et l'état restent
    if (faders)
    {
        auto bottom = r.removeFromBottom (20);
        pan.setBounds (bottom.removeFromRight (std::min (60, bottom.getWidth() / 3)));
        volume.setBounds (bottom);
    }
    pan.setVisible (faders);
    volume.setVisible (faders);
    info.setBounds (r);
}

// =============================================================================================
TimelineView::TimelineView (Session& s) : session (s)
{
    setWantsKeyboardFocus (false);
    headerWidth = juce::jlimit (150, 600, session.settings().props().getIntValue ("timelineHeaderWidth", kDefaultHeaderWidth));
    trackHeight = juce::jlimit (40, 260, session.settings().props().getIntValue ("timelineTrackHeight", kDefaultTrackHeight));
    SV_LOG_INFO ("Timeline", "Disposition : en-têtes "_u8 + juce::String (headerWidth) + " px, pistes " + juce::String (trackHeight) + " px");
    refresh();
}

void TimelineView::dragTrackHeader (int trackId, int yInTimeline, bool first)
{
    const auto& tracks = session.project().tracks;
    int current = -1;
    for (size_t i = 0; i < tracks.size(); ++i)
        if (tracks[i].id == trackId)
            current = static_cast<int> (i);
    if (current < 0)
        return;
    const int target = juce::jlimit (0, static_cast<int> (tracks.size()) - 1, (yInTimeline - kRulerHeight + scrollY) / std::max (1, trackHeight));
    if (target != current)
        session.moveTrack (trackId, target, first ? juce::String ("Ordre des pistes"_u8) : juce::String());
    else if (first)
        session.moveTrack (trackId, current, juce::String());   // rien à faire : aucune étape d'annulation
}

void TimelineView::clearSelection()
{
    if (selTrack < 0 && selTake < 0)
        return;
    selTrack = -1;
    selTake = -1;
    selA = selB = 0.0;
    repaint();
}

void TimelineView::editSplit()
{
    const int trackId = selTrack >= 0 ? selTrack : session.selectedTrack();
    if (trackId < 0)
        return;
    if (selTrack >= 0 && selB > selA)
    {
        // Zone sélectionnée : coupe aux deux bords (le milieu devient un bloc à part).
        session.splitTrackAt (trackId, selA);
        session.splitTrackAt (trackId, selB);
        SV_LOG_INFO ("Timeline", "Coupe aux bords de la zone "_u8 + juce::String (selA, 2) + "-" + juce::String (selB, 2) + " s");
        return;
    }
    session.splitTrackAt (trackId, session.positionSec());
}

void TimelineView::editDelete()
{
    if (selTrack < 0)
        return;
    if (selB > selA)
        session.cutRange (selTrack, selA, selB, false);
    else if (selTake >= 0)
        session.removeTake (selTrack, selTake);
    clearSelection();
}

void TimelineView::editCopy()
{
    if (selTrack < 0)
        return;
    if (selB > selA)
        session.copyRange (selTrack, selA, selB);
    else if (selTake >= 0)
    {
        if (const auto* t = session.project().findTrack (selTrack))
            if (const auto* tk = project::findTake (const_cast<project::Track&> (*t), selTake))
                session.copyRange (selTrack, tk->regionStart / session.project().sampleRate, tk->regionEnd / session.project().sampleRate);
    }
}

void TimelineView::editCut()
{
    if (selTrack < 0)
        return;
    if (selB > selA)
        session.cutRange (selTrack, selA, selB, true);
    else if (selTake >= 0)
    {
        editCopy();
        session.removeTake (selTrack, selTake);
    }
    clearSelection();
}

void TimelineView::editPaste()
{
    const int trackId = selTrack >= 0 ? selTrack : session.selectedTrack();
    if (trackId < 0)
    {
        session.setStatus ("Coller : sélectionne d'abord une piste"_u8);
        return;
    }
    // À la tête de lecture, ou au début de la zone sélectionnée si elle existe.
    session.pasteClipboard (trackId, selTrack >= 0 && selB > selA ? selA : session.positionSec());
}

bool TimelineView::overRowEdge (juce::Point<int> p, int& rowTop) const
{
    if (p.x >= headerWidth || p.y < kRulerHeight)
        return false;
    const int rel = (p.y - kRulerHeight + scrollY) % trackHeight;
    const int idx = (p.y - kRulerHeight + scrollY) / trackHeight;
    if (idx < 0 || idx >= static_cast<int> (session.project().tracks.size()) || rel < trackHeight - 6)
        return false;
    rowTop = p.y - rel;
    return true;
}

void TimelineView::mouseMove (const juce::MouseEvent& e)
{
    int top = 0;
    if (overHeaderEdge (e.getPosition()))
        setMouseCursor (juce::MouseCursor::LeftRightResizeCursor);
    else if (overRowEdge (e.getPosition(), top))
        setMouseCursor (juce::MouseCursor::UpDownResizeCursor);
    else if (drag == Drag::None)
    {
        int handle = 0, takeId = -1;
        if (const int idx = trackIndexAt (e.y); idx >= 0 && e.x >= headerWidth)
            handle = clipHandleAt (session.project().tracks[static_cast<size_t> (idx)], e.getPosition(), kRulerHeight + idx * trackHeight - scrollY, takeId);
        setMouseCursor (handle == 1 || handle == 2 ? juce::MouseCursor::LeftRightResizeCursor
                        : handle != 0                ? juce::MouseCursor::PointingHandCursor
                                                     : juce::MouseCursor::NormalCursor);
    }
}

int TimelineView::clipHandleAt (const project::Track& t, juce::Point<int> p, int rowY, int& takeId) const
{
    const double sr = session.project().sampleRate;
    for (const auto& tk : t.takes)
    {
        const int x1 = secToX (tk.regionStart / sr), x2 = secToX (tk.regionEnd / sr);
        if (p.x < x1 - 5 || p.x > x2 + 5)
            continue;
        takeId = tk.id;
        // Bande du haut : poignées de fondu (carrés) ; ailleurs près d'un bord : rognage.
        if (p.y <= rowY + 3 + kHandle + 3)
        {
            if (std::abs (p.x - secToX ((tk.regionStart + tk.fadeIn) / sr)) <= kHandle)
                return 3;
            if (std::abs (p.x - secToX ((tk.regionEnd - tk.fadeOut) / sr)) <= kHandle)
                return 4;
        }
        if (std::abs (p.x - x1) <= 5)
            return 1;
        if (std::abs (p.x - x2) <= 5)
            return 2;
    }
    takeId = -1;
    return 0;
}

double TimelineView::xToSec (int x) const { return viewStart + (x - headerWidth) / pxPerSec; }
int TimelineView::secToX (double s) const { return headerWidth + static_cast<int> (std::round ((s - viewStart) * pxPerSec)); }

int TimelineView::trackIndexAt (int y) const
{
    if (y < kRulerHeight)
        return -1;
    const int idx = (y - kRulerHeight + scrollY) / trackHeight;
    return idx < static_cast<int> (session.project().tracks.size()) ? idx : -1;
}

void TimelineView::clampView()
{
    viewStart = std::max (0.0, viewStart);
    const int contentH = static_cast<int> (session.project().tracks.size()) * trackHeight;
    scrollY = juce::jlimit (0, std::max (0, contentH - (getHeight() - kRulerHeight)), scrollY);
}

void TimelineView::refresh()
{
    const auto& tracks = session.project().tracks;
    bool same = headers.size() == tracks.size();
    for (size_t i = 0; same && i < tracks.size(); ++i)
        same = headers[i]->trackId() == tracks[i].id;
    if (! same)
    {
        headers.clear();
        for (const auto& t : tracks)
        {
            headers.push_back (std::make_unique<TrackHeader> (session, t.id));
            addAndMakeVisible (*headers.back());
        }
        resized();
    }
    for (auto& h : headers)
        h->refresh();
    repaint();
}

void TimelineView::resized()
{
    clampView();
    for (size_t i = 0; i < headers.size(); ++i)
    {
        const int y = kRulerHeight + static_cast<int> (i) * trackHeight - scrollY;
        headers[i]->setBounds (0, y, headerWidth - 6, trackHeight - 6);   // bandes de 6 px à droite et en bas : poignées de redimensionnement
        headers[i]->setVisible (y + trackHeight > kRulerHeight && y < getHeight());
    }
}

const TimelineView::WaveCache* TimelineView::waveFor (const project::Track& t)
{
    auto r = session.renderFor (t.id);
    if (r == nullptr || ! r->ok())
        return nullptr;
    const bool useRaw = t.isVocal() && ! t.processingEnabled;
    const Stereo& buf = useRaw ? r->raw : r->processed;
    auto& w = waves[t.id];
    if (w.key == &buf && w.raw == useRaw)
        return &w;
    w.key = &buf;
    w.raw = useRaw;
    w.start = r->startSample;
    const int bin = std::max (1, static_cast<int> (session.project().sampleRate * 0.01));
    const int n = buf.getNumSamples();
    w.peaks.assign (static_cast<size_t> (n / bin + 1), 0.0f);
    for (int c = 0; c < buf.getNumChannels(); ++c)
    {
        const float* d = buf.getReadPointer (c);
        for (int i = 0; i < n; ++i)
        {
            auto& p = w.peaks[static_cast<size_t> (i / bin)];
            p = std::max (p, std::abs (d[i]));
        }
    }
    return &w;
}

void TimelineView::paint (juce::Graphics& g)
{
    const auto& p = session.project();
    g.fillAll (theme::bg);
    const int w = getWidth();
    const auto clip = g.getClipBounds();   // tête de lecture : seule une bande étroite est à redessiner

    // Pistes
    g.saveState();
    g.reduceClipRegion (headerWidth, kRulerHeight, w - headerWidth, getHeight() - kRulerHeight);
    for (size_t i = 0; i < p.tracks.size(); ++i)
    {
        const auto& t = p.tracks[i];
        const int y = kRulerHeight + static_cast<int> (i) * trackHeight - scrollY;
        if (y + trackHeight < kRulerHeight || y > getHeight() || y + trackHeight < clip.getY() || y > clip.getBottom())
            continue;
        const bool selected = session.isTrackSelected (t.id);
        g.setColour (selected ? theme::selection.withAlpha (0.55f) : (i % 2 == 0 ? theme::bg.brighter (0.035f) : theme::bg.brighter (0.06f)));
        g.fillRect (headerWidth, y, w - headerWidth, trackHeight);

        // Bloc en cours de déplacement : dessiné décalé (le projet n'est modifié qu'au relâchement).
        const bool moving = drag == Drag::Clip && clipTrack == t.id;
        const double shiftSec = moving ? clipOffsetSec : 0.0;
        // Zones des prises (vocal) en contour, fondus en triangle, poignées de fondu en haut.
        const bool editing = (drag == Drag::ClipEdgeL || drag == Drag::ClipEdgeR || drag == Drag::FadeIn || drag == Drag::FadeOut) && clipTrack == t.id;
        for (const auto& tk : t.takes)
        {
            const double tkShift = moving && (clipTake == tk.id || clipTake < 0) ? shiftSec : 0.0;
            const bool thisEdit = editing && clipTake == tk.id;
            const long rs = thisEdit ? editStart : tk.regionStart, re = thisEdit ? editEnd : tk.regionEnd;
            const long fi = thisEdit ? editFadeIn : tk.fadeIn, fo = thisEdit ? editFadeOut : tk.fadeOut;
            const int x1 = secToX (rs / p.sampleRate + tkShift), x2 = secToX (re / p.sampleRate + tkShift);
            const int yTop = y + 3, yBot = y + trackHeight - 3;
            const auto col = roleColour (t.role);
            g.setColour (col.withAlpha (thisEdit ? 0.8f : 0.25f));
            g.drawRect (x1, yTop, std::max (1, x2 - x1), yBot - yTop);
            const int xFi = secToX ((rs + fi) / p.sampleRate + tkShift), xFo = secToX ((re - fo) / p.sampleRate + tkShift);
            if (fi > 0)
            {
                juce::Path f;
                f.addTriangle ((float) x1, (float) yBot, (float) xFi, (float) yTop, (float) x1, (float) yTop);
                g.setColour (juce::Colours::black.withAlpha (0.35f));
                g.fillPath (f);
                g.setColour (col.withAlpha (0.9f));
                g.drawLine ((float) x1, (float) yBot, (float) xFi, (float) yTop, 1.5f);
            }
            if (fo > 0)
            {
                juce::Path f;
                f.addTriangle ((float) x2, (float) yBot, (float) xFo, (float) yTop, (float) x2, (float) yTop);
                g.setColour (juce::Colours::black.withAlpha (0.35f));
                g.fillPath (f);
                g.setColour (col.withAlpha (0.9f));
                g.drawLine ((float) x2, (float) yBot, (float) xFo, (float) yTop, 1.5f);
            }
            if (selected || thisEdit)
            {
                g.setColour (juce::Colours::white.withAlpha (0.85f));
                g.fillRect (xFi - kHandle / 2, yTop, kHandle, kHandle);
                g.fillRect (xFo - kHandle / 2, yTop, kHandle, kHandle);
            }
        }

        if (const auto* wc = waveFor (t))
        {
            const auto col = roleColour (t.role);
            const double binSec = 0.01;
            const double startSec = wc->start / p.sampleRate + shiftSec;
            const int mid = y + trackHeight / 2;
            const float half = (trackHeight - 10) * 0.5f;
            const int xa = std::max ({ headerWidth, clip.getX() - 1, secToX (startSec) });
            const int xb = std::min ({ w, clip.getRight() + 1, secToX (startSec + wc->peaks.size() * binSec) });
            g.setColour (col.withAlpha (0.15f));
            g.fillRect (xa, y + 4, std::max (0, xb - xa), trackHeight - 8);
            g.setColour (t.mute ? col.withAlpha (0.3f) : col);
            for (int x = xa; x < xb; ++x)
            {
                const double s0 = xToSec (x) - startSec, s1 = xToSec (x + 1) - startSec;
                const int b0 = std::max (0, static_cast<int> (s0 / binSec));
                const int b1 = std::min (static_cast<int> (wc->peaks.size()), std::max (b0 + 1, static_cast<int> (s1 / binSec)));
                float pk = 0.0f;
                for (int b = b0; b < b1; ++b)
                    pk = std::max (pk, wc->peaks[static_cast<size_t> (b)]);
                const float hgt = std::min (1.0f, pk) * half;
                g.drawVerticalLine (x, static_cast<float> (mid) - hgt, static_cast<float> (mid) + hgt + 1.0f);
            }
        }
        else
        {
            g.setColour (juce::Colours::grey);
            g.setFont (12.0f);
            const auto st = session.trackStatus (t.id);
            g.drawText (st.isNotEmpty() ? st : juce::String ("Vide — arme la piste (rond rouge) et appuie sur REC"_u8),
                        headerWidth + 10, y, 600, trackHeight, juce::Justification::centredLeft);
        }
        if (! t.words.empty() && pxPerSec >= 30.0)
        {
            // Mots reconnus et calés : affichés sous la forme d'onde, le mot en cours en accent.
            const double now = session.positionSec();
            g.setFont (juce::FontOptions (10.5f));
            int lastRight = -1000;
            for (const auto& wd : t.words)
            {
                const int x1 = secToX (wd.startSec), x2 = secToX (wd.endSec);
                if (x2 < headerWidth || x1 > w || x1 < lastRight + 2)
                    continue;
                const bool current = now >= wd.startSec && now < wd.endSec;
                g.setColour (current ? theme::accent2 : theme::text.withAlpha (0.75f));
                const int width = juce::jmax (12, juce::GlyphArrangement::getStringWidthInt (g.getCurrentFont(), wd.text) + 4);
                g.drawText (wd.text, x1, y + trackHeight - 16, width, 14, juce::Justification::centredLeft);
                lastRight = x1 + width;
            }
        }
        if (selTrack == t.id)
        {
            if (selB > selA)
            {
                const int x1 = secToX (selA), x2 = secToX (selB);
                g.setColour (juce::Colours::white.withAlpha (0.18f));
                g.fillRect (x1, y, std::max (1, x2 - x1), trackHeight);
                g.setColour (juce::Colours::white.withAlpha (0.7f));
                g.drawRect (x1, y, std::max (1, x2 - x1), trackHeight);
            }
            else if (selTake >= 0)
                for (const auto& tk : t.takes)
                    if (tk.id == selTake)
                    {
                        const int x1 = secToX (tk.regionStart / p.sampleRate), x2 = secToX (tk.regionEnd / p.sampleRate);
                        g.setColour (juce::Colours::white.withAlpha (0.9f));
                        g.drawRect (x1, y + 2, std::max (1, x2 - x1), trackHeight - 4, 2);
                    }
        }
        g.setColour (juce::Colours::black);
        g.drawHorizontalLine (y + trackHeight - 1, static_cast<float> (headerWidth), static_cast<float> (w));
    }
    {
        const int yEnd = kRulerHeight + static_cast<int> (p.tracks.size()) * trackHeight - scrollY;
        if (yEnd + 30 < getHeight())
        {
            g.setColour (juce::Colours::grey);
            g.setFont (13.0f);
            g.drawText ("Clic droit : nouvelle piste | Ctrl / Maj + clic : sélection multiple | Suppr : supprimer la sélection"_u8,
                        headerWidth + 10, yEnd + 8, 900, 20, juce::Justification::centredLeft);
        }
    }

    // Zones punch / boucle sur toute la hauteur.
    if (punchOut > punchIn)
    {
        g.setColour (juce::Colours::red.withAlpha (0.12f));
        g.fillRect (secToX (punchIn), kRulerHeight, secToX (punchOut) - secToX (punchIn), getHeight() - kRulerHeight);
    }
    if (loopB > loopA)
    {
        g.setColour (juce::Colours::green.withAlpha (0.10f));
        g.fillRect (secToX (loopA), kRulerHeight, secToX (loopB) - secToX (loopA), getHeight() - kRulerHeight);
    }
    // Marqueurs
    g.setColour (juce::Colours::yellow.withAlpha (0.6f));
    for (const auto& m : p.markers)
        g.drawVerticalLine (secToX (m.timeSec), static_cast<float> (kRulerHeight), static_cast<float> (getHeight()));
    g.restoreState();

    // Règle
    g.setColour (juce::Colour (0xff20252c));
    g.fillRect (headerWidth, 0, w - headerWidth, kRulerHeight);
    for (size_t i = 0; i < p.sections.size(); ++i)
    {
        const auto& s = p.sections[i];
        const int x1 = std::max (headerWidth, secToX (s.startSec)), x2 = secToX (s.endSec);
        if (x2 <= headerWidth || x1 > w)
            continue;
        g.setColour (sectionColour (s.kind).withAlpha (0.7f));
        g.fillRect (x1, 0, x2 - x1, 18);
        g.setColour (juce::Colours::white);
        g.setFont (11.0f);
        g.drawText (s.label, x1 + 3, 0, std::max (0, x2 - x1 - 4), 18, juce::Justification::centredLeft, true);
    }
    const double barSec = p.tempo.barSec();
    const int barStep = pxPerSec * barSec < 30 ? (pxPerSec * barSec < 8 ? 16 : 4) : 1;
    g.setFont (10.0f);
    for (int bar = 0;; bar += barStep)
    {
        const double t = p.tempo.firstBeatSec + bar * barSec;
        const int x = secToX (t);
        if (x > w)
            break;
        if (x < headerWidth)
            continue;
        g.setColour (juce::Colours::grey);
        g.drawVerticalLine (x, 18.0f, static_cast<float> (kRulerHeight));
        g.setColour (juce::Colours::lightgrey);
        g.drawText (juce::String (bar + 1), x + 2, 20, 40, 12, juce::Justification::left);
    }
    // Secondes
    const int secStep = pxPerSec < 15 ? 10 : (pxPerSec < 60 ? 5 : 1);
    for (int sec = static_cast<int> (viewStart) / secStep * secStep;; sec += secStep)
    {
        const int x = secToX (sec);
        if (x > w)
            break;
        if (x < headerWidth)
            continue;
        g.setColour (juce::Colours::darkgrey);
        g.drawText (juce::String (sec / 60) + ":" + juce::String (sec % 60).paddedLeft ('0', 2), x + 2, 34, 50, 12, juce::Justification::left);
    }
    if (punchOut > punchIn)
    {
        g.setColour (juce::Colours::red);
        g.fillRect (secToX (punchIn), kRulerHeight - 4, secToX (punchOut) - secToX (punchIn), 4);
    }
    if (loopB > loopA)
    {
        g.setColour (juce::Colours::limegreen);
        g.fillRect (secToX (loopA), kRulerHeight - 8, secToX (loopB) - secToX (loopA), 4);
    }

    // Coin haut gauche : aide
    g.setColour (theme::panel);
    g.fillRect (0, 0, headerWidth, kRulerHeight);
    g.setColour (juce::Colours::grey);
    g.setFont (10.0f);
    g.drawFittedText ("Clic = position | Glisser = zone | Maj+glisser = punch | Alt+glisser = boucle\n"
                      "S = couper | Suppr = effacer | Ctrl+C / X / V | Ctrl+molette = zoom | En-tête : glisser = ordre"_u8,
                      4, 2, headerWidth - 8, kRulerHeight - 4, juce::Justification::topLeft, 3);

    // Projet encore vide : les deux premières étapes, en clair, dans la zone des pistes.
    {
        const auto& pr = session.project();
        const auto* instru = pr.instruTrack();
        const bool noInstru = instru == nullptr || instru->sourceFile.isEmpty();
        bool anyTake = false;
        for (const auto& t : pr.tracks)
            anyTake = anyTake || ! t.takes.empty();
        if ((noInstru || ! anyTake) && ! session.isRecording())
        {
            juce::String hint = noInstru ? "1. Dépose ton instru ici (ou bouton « Instru... » en haut)"_u8
                                         : "2. Arme une piste voix (rond rouge) puis REC — ou dépose un fichier voix"_u8;
            hint << "\nClic droit ou « \xE2\x8B\xAF » sur une piste : tout ce qui la concerne (style, effets, IA, découpe, ordre)"_u8;
            const auto area = juce::Rectangle<int> (headerWidth, getHeight() - 72, w - headerWidth, 60).reduced (24, 0);
            g.setColour (theme::panel.withAlpha (0.85f));
            g.fillRoundedRectangle (area.toFloat(), theme::radius);
            g.setColour (theme::text);
            g.setFont (14.0f);
            g.drawFittedText (hint, area.reduced (12, 4), juce::Justification::centred, 3);
        }
    }

    // Tête de lecture
    const int px = secToX (session.positionSec());
    if (px >= headerWidth && px <= w)
    {
        g.setColour (session.isRecording() ? juce::Colours::red : juce::Colours::white);
        g.drawVerticalLine (px, 0.0f, static_cast<float> (getHeight()));
    }
    lastPlayheadX = px;
}

void TimelineView::updatePlayhead()
{
    for (auto& h : headers)
        if (h->isVisible())
            h->updateMeter();
    const double t = session.positionSec();
    const int px = secToX (t);
    // Défilement automatique pendant la lecture.
    if (session.engine().isPlaying() && (px > getWidth() - 40 || px < headerWidth))
    {
        viewStart = std::max (0.0, t - 2.0);
        repaint();
        return;
    }
    if (px != lastPlayheadX)
    {
        repaint (std::min (px, lastPlayheadX) - 2, 0, std::abs (px - lastPlayheadX) + 5, getHeight());
    }
}

void TimelineView::mouseDown (const juce::MouseEvent& e)
{
    if (e.mods.isPopupMenu() && e.y >= kRulerHeight && trackIndexAt (e.y) < 0)
    {
        // Zone vide sous les pistes (en-têtes compris) : nouvelle piste.
        juce::PopupMenu m;
        m.addItem (1, "Nouvelle piste...");
        juce::WeakReference<Session> weak (&session);
        m.showMenuAsync (juce::PopupMenu::Options(), [weak] (int r)
        {
            if (auto* s = weak.get(); s != nullptr && r == 1)
                showNewTrackDialog (*s);
        });
        return;
    }
    if (! e.mods.isPopupMenu())
    {
        // Poignées : bord droit des en-têtes (largeur), bord bas d'une piste (hauteur de toutes les pistes).
        int top = 0;
        if (overHeaderEdge (e.getPosition()))
        {
            drag = Drag::HeaderEdge;
            return;
        }
        if (overRowEdge (e.getPosition(), top))
        {
            drag = Drag::RowEdge;
            rowEdgeTop = top;
            return;
        }
    }
    if (e.x < headerWidth)
        return;
    const double t = std::max (0.0, xToSec (e.x));
    if (e.y < kRulerHeight)
    {
        if (e.mods.isShiftDown())
        {
            drag = Drag::Punch;
            punchIn = punchOut = t;
        }
        else if (e.mods.isAltDown())
        {
            drag = Drag::Loop;
            loopA = loopB = t;
        }
        else
        {
            drag = Drag::Playhead;
            session.setPositionSec (t);
        }
        dragAnchor = t;
        repaint();
        return;
    }
    const int idx = trackIndexAt (e.y);
    if (idx >= 0)
    {
        const int id = session.project().tracks[static_cast<size_t> (idx)].id;
        if (! (e.mods.isPopupMenu() && session.isTrackSelected (id)))
            session.selectTrack (id, e.mods.isCtrlDown() || e.mods.isCommandDown(), e.mods.isShiftDown());
        if (e.mods.isPopupMenu())
        {
            int menuTake = -1;
            clipAt (session.project().tracks[static_cast<size_t> (idx)], t, menuTake);
            showTrackMenu (id, menuTake, t);
            return;
        }
        // Poignées d'un bloc : bords (rogner) et fondus ; puis glisser un bloc pour le déplacer ; clic ailleurs = tête de lecture.
        int takeId = -1;
        const auto& track = session.project().tracks[static_cast<size_t> (idx)];
        if (const int h = session.isRecording() || e.mods.isAnyModifierKeyDown() ? 0 : clipHandleAt (track, e.getPosition(), kRulerHeight + idx * trackHeight - scrollY, takeId); h != 0)
        {
            const auto* tk = project::findTake (const_cast<project::Track&> (track), takeId);
            if (tk != nullptr)
            {
                drag = h == 1 ? Drag::ClipEdgeL : h == 2 ? Drag::ClipEdgeR : h == 3 ? Drag::FadeIn : Drag::FadeOut;
                clipTrack = id;
                clipTake = takeId;
                editStart = tk->regionStart;
                editEnd = tk->regionEnd;
                editFadeIn = tk->fadeIn;
                editFadeOut = tk->fadeOut;
                editFileLen = (h == 2) ? session.takeFileLength (id, takeId) : 0;
                dragAnchor = xToSec (e.x);
                repaint();
                return;
            }
        }
        if (! session.isRecording() && (e.mods.isCtrlDown() || e.mods.isCommandDown()))
        {
            drag = Drag::Range;
            selTrack = id;
            selTake = -1;
            selA = selB = std::max (0.0, t);
            rangeStart = e.getPosition();
            rangeMoved = false;
            repaint();
            return;
        }
        if (! session.isRecording() && ! e.mods.isAnyModifierKeyDown() && clipAt (track, t, takeId))
        {
            drag = Drag::Clip;
            clipTrack = id;
            clipTake = takeId;
            clipOffsetSec = 0.0;
            dragAnchor = xToSec (e.x);
            setMouseCursor (juce::MouseCursor::DraggingHandCursor);
            selTrack = id;      // le bloc cliqué devient le bloc sélectionné (Suppr, Ctrl+C / X)
            selTake = takeId;
            selA = selB = 0.0;
            repaint();
            return;
        }
        if (! session.isRecording() && ! e.mods.isAnyModifierKeyDown())
        {
            // Glisser dans le vide = sélection d'une zone ; clic sans glisser = tête de lecture (au relâchement).
            drag = Drag::Range;
            selTrack = id;
            selTake = -1;
            selA = selB = std::max (0.0, t);
            rangeStart = e.getPosition();
            rangeMoved = false;
            repaint();
            return;
        }
    }
}

double TimelineView::clipStartSec (const project::Track& t, int takeId) const
{
    const double sr = session.project().sampleRate;
    if (takeId >= 0)
    {
        for (const auto& tk : t.takes)
            if (tk.id == takeId)
                return tk.regionStart / sr;
        return 0.0;
    }
    auto r = session.renderFor (t.id);
    return r != nullptr ? r->startSample / sr : t.sourceStart / sr;
}

bool TimelineView::clipAt (const project::Track& t, double sec, int& takeId) const
{
    const double sr = session.project().sampleRate;
    for (const auto& tk : t.takes)
        if (sec >= tk.regionStart / sr && sec <= tk.regionEnd / sr)
        {
            takeId = tk.id;
            return true;
        }
    if (t.takes.empty() && t.sourceFile.isNotEmpty())
    {
        auto r = session.renderFor (t.id);
        if (r != nullptr && r->ok())
        {
            const double a = r->startSample / sr, b = a + r->processed.getNumSamples() / sr;
            if (sec >= a && sec <= b)
            {
                takeId = -1;
                return true;
            }
        }
    }
    return false;
}

void TimelineView::mouseDrag (const juce::MouseEvent& e)
{
    const double t = std::max (0.0, xToSec (e.x));
    switch (drag)
    {
        case Drag::Playhead: session.setPositionSec (t); break;
        case Drag::Punch:    punchIn = std::min (dragAnchor, t); punchOut = std::max (dragAnchor, t); break;
        case Drag::Loop:     loopA = std::min (dragAnchor, t); loopB = std::max (dragAnchor, t); break;
        case Drag::Clip:
        {
            double off = xToSec (e.x) - dragAnchor;
            double clipStart = 0.0;
            if (const auto* tr = session.project().findTrack (clipTrack))
                clipStart = clipStartSec (*tr, clipTake);
            off = std::max (off, -clipStart);                       // jamais avant le début du morceau
            const double newStart = clipStart + off;
            const double snapPx = 8.0 / pxPerSec;                   // aimant : 8 pixels
            if (newStart < snapPx * 2.0)
                off = -clipStart;                                   // au début exactement
            else if (const auto& tempo = session.project().tempo; tempo.bpm > 0.0)
            {
                const double beat = 60.0 / tempo.bpm;
                const double nearest = tempo.firstBeatSec + std::round ((newStart - tempo.firstBeatSec) / beat) * beat;
                if (std::abs (nearest - newStart) < snapPx && nearest >= 0.0)
                    off = nearest - clipStart;
            }
            clipOffsetSec = off;
            break;
        }
        case Drag::Range:
        {
            if (! rangeMoved && std::abs (e.x - rangeStart.x) < 4)
                break;
            rangeMoved = true;
            const double a = std::max (0.0, xToSec (rangeStart.x)), b = std::max (0.0, t);
            selA = std::min (a, b);
            selB = std::max (a, b);
            // Aimant aux temps de la grille et aux bords des blocs (8 px).
            const double snapSec = 8.0 / pxPerSec;
            if (const auto* tr = session.project().findTrack (selTrack))
            {
                const double sr = session.project().sampleRate;
                for (double* edge : { &selA, &selB })
                    for (const auto& tk : tr->takes)
                        for (const double cand : { tk.regionStart / sr, tk.regionEnd / sr })
                            if (std::abs (cand - *edge) < snapSec)
                                *edge = cand;
            }
            break;
        }
        case Drag::ClipEdgeL:
        case Drag::ClipEdgeR:
        case Drag::FadeIn:
        case Drag::FadeOut:
        {
            const auto* tr = session.project().findTrack (clipTrack);
            const auto* tk = tr != nullptr ? project::findTake (const_cast<project::Track&> (*tr), clipTake) : nullptr;
            if (tk == nullptr)
                break;
            const double sr = session.project().sampleRate;
            const long cursor = static_cast<long> (std::llround (std::max (0.0, xToSec (e.x)) * sr));
            const long minLen = static_cast<long> (sr * 0.05);
            if (drag == Drag::ClipEdgeL)
                editStart = juce::jlimit (std::max (0L, tk->startSample), tk->regionEnd - minLen, cursor);
            else if (drag == Drag::ClipEdgeR)
                editEnd = juce::jlimit (tk->regionStart + minLen, editFileLen > 0 ? tk->startSample + editFileLen : std::numeric_limits<long>::max(), cursor);
            else if (drag == Drag::FadeIn)
                editFadeIn = juce::jlimit (0L, tk->regionEnd - tk->regionStart - tk->fadeOut, cursor - tk->regionStart);
            else
                editFadeOut = juce::jlimit (0L, tk->regionEnd - tk->regionStart - tk->fadeIn, tk->regionEnd - cursor);
            break;
        }
        case Drag::HeaderEdge:
            headerWidth = juce::jlimit (150, 600, e.x);
            resized();
            break;
        case Drag::RowEdge:
            trackHeight = juce::jlimit (40, 260, e.y - rowEdgeTop);
            resized();
            break;
        case Drag::None:     break;
    }
    repaint();
}

void TimelineView::mouseUp (const juce::MouseEvent&)
{
    if (drag == Drag::HeaderEdge || drag == Drag::RowEdge)
    {
        session.settings().props().setValue ("timelineHeaderWidth", headerWidth);
        session.settings().props().setValue ("timelineTrackHeight", trackHeight);
        SV_LOG_INFO ("Timeline", "Disposition mémorisée : en-têtes "_u8 + juce::String (headerWidth) + " px, pistes " + juce::String (trackHeight) + " px");
        drag = Drag::None;
        setMouseCursor (juce::MouseCursor::NormalCursor);
        return;
    }
    if (drag == Drag::Range)
    {
        drag = Drag::None;
        if (! rangeMoved)
        {
            // Clic simple : tête de lecture, sélection effacée.
            const double t = std::max (0.0, xToSec (rangeStart.x));
            clearSelection();
            if (! session.isRecording())
                session.setPositionSec (t);
            return;
        }
        if (selB - selA < 0.001)
            clearSelection();
        else
        {
            SV_LOG_INFO ("Timeline", "Zone sélectionnée "_u8 + juce::String (selA, 2) + "-" + juce::String (selB, 2) + " s sur la piste #" + juce::String (selTrack));
            session.setStatus ("Zone "_u8 + juce::String (selB - selA, 2) + " s : S = couper aux bords, Suppr = effacer, Ctrl+C / X = copier / couper, Ctrl+V = coller"_u8);
        }
        repaint();
        return;
    }
    if (drag == Drag::ClipEdgeL || drag == Drag::ClipEdgeR || drag == Drag::FadeIn || drag == Drag::FadeOut)
    {
        const auto kind = drag;
        const int trackId = clipTrack, takeId = clipTake;
        const double sr = session.project().sampleRate;
        drag = Drag::None;
        clipTrack = -1;
        setMouseCursor (juce::MouseCursor::NormalCursor);
        if (const auto* tr = session.project().findTrack (trackId); tr != nullptr)
            if (const auto* tk = project::findTake (const_cast<project::Track&> (*tr), takeId); tk != nullptr)
            {
                if ((kind == Drag::ClipEdgeL || kind == Drag::ClipEdgeR) && (editStart != tk->regionStart || editEnd != tk->regionEnd))
                    session.trimTake (trackId, takeId, editStart / sr, editEnd / sr);
                else if ((kind == Drag::FadeIn || kind == Drag::FadeOut) && (editFadeIn != tk->fadeIn || editFadeOut != tk->fadeOut))
                    session.setTakeFades (trackId, takeId, editFadeIn / sr, editFadeOut / sr);
            }
        repaint();
        return;
    }
    if (drag == Drag::Clip)
    {
        const double delta = clipOffsetSec;
        const int trackId = clipTrack, takeId = clipTake;
        clipTrack = -1;
        clipOffsetSec = 0.0;
        drag = Drag::None;
        setMouseCursor (juce::MouseCursor::NormalCursor);
        if (std::abs (delta) >= 0.01)
            session.moveTrackAudio (trackId, takeId, delta);
        repaint();
        return;
    }
    if (drag == Drag::Punch || drag == Drag::Loop)
    {
        SV_LOG_INFO ("Timeline", drag == Drag::Punch ? "Zone de punch-in : " + juce::String (punchIn, 2) + "-" + juce::String (punchOut, 2) + " s"
                                                      : "Zone de boucle : " + juce::String (loopA, 2) + "-" + juce::String (loopB, 2) + " s");
        if (onRegionsChanged)
            onRegionsChanged();
    }
    drag = Drag::None;
}

void TimelineView::mouseDoubleClick (const juce::MouseEvent& e)
{
    if (e.y >= 18 || e.x < headerWidth)
        return;
    const double t = xToSec (e.x);
    const auto& secs = session.project().sections;
    for (size_t i = 0; i < secs.size(); ++i)
        if (t >= secs[i].startSec && t < secs[i].endSec)
        {
            showSectionMenu (static_cast<int> (i));
            return;
        }
}

void TimelineView::mouseWheelMove (const juce::MouseEvent& e, const juce::MouseWheelDetails& w)
{
    if (e.mods.isCtrlDown() || e.mods.isCommandDown())
    {
        const double anchor = xToSec (e.x);
        pxPerSec = juce::jlimit (2.0, 800.0, pxPerSec * (w.deltaY > 0 ? 1.25 : 0.8));
        viewStart = anchor - (e.x - headerWidth) / pxPerSec;
    }
    else if (e.mods.isShiftDown() || std::abs (w.deltaX) > std::abs (w.deltaY))
    {
        const float d = std::abs (w.deltaX) > 0.0f ? w.deltaX : w.deltaY;
        viewStart -= d * 400.0 / pxPerSec;
    }
    else
    {
        scrollY -= static_cast<int> (w.deltaY * 200.0f);
    }
    clampView();
    resized();
    repaint();
}

void TimelineView::showTrackMenu (int trackId, int takeId, double atSec)
{
    const auto* t = session.project().findTrack (trackId);
    if (t == nullptr)
        return;
    juce::PopupMenu m;
    m.addSectionHeader (t->name);
    if (takeId >= 0 && atSec >= 0.0)
    {
        m.addItem (20, "Couper le bloc ici ("_u8 + juce::String (atSec, 2) + " s)");
        m.addItem (21, "Couper le bloc à la tête de lecture"_u8);
        m.addItem (22, "Fondus de 10 ms sur le bloc"_u8);
        m.addItem (23, "Retirer les fondus du bloc"_u8);
        m.addItem (24, "Supprimer le bloc"_u8);
        m.addSeparator();
    }
    // Tout ce qui concerne cette piste, au même endroit.
    if (t->role == style::Role::Instru)
    {
        m.addItem (30, "Remplacer l'instru..."_u8);
#if SV_EDITION_IA
        m.addItem (31, "Séparer l'instru en 4 pistes : batterie, basse, autres, voix (IA)"_u8, t->sourceFile.isNotEmpty());
#endif
    }
    else if (t->isRecordable())
    {
        m.addItem (32, "Importer un fichier audio dans cette piste..."_u8);
        m.addItem (35, "Style et effets de cette piste... (panneau de droite)"_u8);
#if SV_EDITION_IA
        if (t->isVoice())
        {
            m.addItem (33, "Reconnaître les paroles de cette piste (IA)"_u8, ! t->takes.empty());
            m.addItem (34, "Nettoyage IA de la voix (DeepFilterNet)"_u8, true, t->aiClean);
        }
#endif
    }
    m.addItem (36, "Renommer la piste"_u8);
    m.addSeparator();
    m.addItem (10, "Nouvelle piste...");
    if (! t->takes.empty() || t->sourceFile.isNotEmpty())
        m.addItem (12, "Caler l'audio au début du morceau (0 s)"_u8);
    m.addItem (13, "Monter la piste"_u8);
    m.addItem (14, "Descendre la piste"_u8);
    if (t->isRecordable())
        m.addItem (11, session.armedTrack() == trackId ? juce::String ("Désarmer la piste"_u8)
                                                       : juce::String ("Armer la piste (le micro enregistre ici)"_u8));
    m.addSeparator();
    if (t->isVocal() && ! t->isGenerated())
    {
        m.addItem (1, "Prises : la plus récente gagne (punch-in)"_u8, true, t->comp == project::CompMode::Latest);
        m.addItem (2, "Prises : meilleure prise automatique (phrase par phrase)", true, t->comp == project::CompMode::Best);
        m.addItem (3, "Effacer toutes les prises de cette piste", ! t->takes.empty());
    }
    const int nSel = static_cast<int> (session.selectedTrackIds().size());
    if (nSel > 1 && session.isTrackSelected (trackId))
        m.addItem (5, "Supprimer les " + juce::String (nSel) + " pistes sélectionnées (Suppr)"_u8);
    else
        m.addItem (4, "Supprimer la piste (Suppr)");
    juce::WeakReference<Session> weak (&session);
    juce::Component::SafePointer<TimelineView> safe (this);
    m.showMenuAsync (juce::PopupMenu::Options(), [weak, safe, trackId, takeId, atSec] (int r)
    {
        auto* s = weak.get();
        if (s == nullptr || r == 0)
            return;
        if (r == 30 || r == 32)
        {
            if (safe == nullptr)
                return;
            const bool instru = r == 30;
            safe->chooser = std::make_unique<juce::FileChooser> (instru ? juce::String ("Remplacer l'instru"_u8) : juce::String ("Fichier audio pour cette piste"_u8),
                                                                 juce::File::getSpecialLocation (juce::File::userMusicDirectory), "*.wav;*.mp3;*.flac;*.aif;*.aiff;*.ogg");
            safe->chooser->launchAsync (juce::FileBrowserComponent::openMode | juce::FileBrowserComponent::canSelectFiles, [weak, instru, trackId] (const juce::FileChooser& fc)
            {
                auto* s2 = weak.get();
                if (s2 == nullptr || fc.getResult() == juce::File())
                    return;
                if (instru)
                    s2->importInstru (fc.getResult());
                else
                    s2->importVoice (fc.getResult(), trackId);
            });
            return;
        }
#if SV_EDITION_IA
        if (r == 31) { s->separateInstru(); return; }
        if (r == 33) { s->recognizeLyrics (trackId); return; }
        if (r == 34)
        {
            const auto* tr0 = s->project().findTrack (trackId);
            const bool enable = tr0 != nullptr && ! tr0->aiClean;
            s->updateTrack (trackId, [enable] (project::Track& tr) { tr.aiClean = enable; }, true, "Nettoyage IA");
            if (enable && ! ai::local::deepFilterAvailable())
                s->ensureToolsThen ({ "deep-filter" }, "Nettoyage IA"_u8, [weak] { if (auto* s3 = weak.get()) s3->updateProject ([] (project::Project&) {}, true, {}); });
            return;
        }
#endif
        if (r == 35)
        {
            s->selectTrack (trackId, false, false);
            if (safe != nullptr && safe->onOpenTrackPanel)
                safe->onOpenTrackPanel (trackId);
            return;
        }
        if (r == 36)
        {
            if (safe != nullptr)
                for (auto& h : safe->headers)
                    if (h->trackId() == trackId)
                        h->startRename();
            return;
        }
        if (r == 20)
            s->splitTake (trackId, takeId, atSec);
        else if (r == 21)
            s->splitTake (trackId, takeId, s->positionSec());
        else if (r == 22)
            s->setTakeFades (trackId, takeId, 0.010, 0.010);
        else if (r == 23)
            s->setTakeFades (trackId, takeId, 0.0, 0.0);
        else if (r == 24)
            s->removeTake (trackId, takeId);
        if (r >= 20 && r <= 24)
            return;
        if (r == 5)
        {
            s->removeTracks (std::vector<int> (s->selectedTrackIds().begin(), s->selectedTrackIds().end()));
            return;
        }
        if (r == 10)
            showNewTrackDialog (*s);
        else if (r == 11)
            s->armTrack (s->armedTrack() == trackId ? -1 : trackId);
        else if (r == 12)
            s->moveTrackAudioToStart (trackId);
        else if (r == 13 || r == 14)
        {
            const auto& tracks = s->project().tracks;
            for (size_t i = 0; i < tracks.size(); ++i)
                if (tracks[i].id == trackId)
                    s->moveTrack (trackId, static_cast<int> (i) + (r == 13 ? -1 : 1), "Ordre des pistes"_u8);
        }
        else if (r == 1 || r == 2)
            s->updateTrack (trackId, [r] (project::Track& tr) { tr.comp = r == 2 ? project::CompMode::Best : project::CompMode::Latest; }, true,
                            "Mode d'assemblage des prises");
        else if (r == 3)
            s->updateTrack (trackId, [] (project::Track& tr) { tr.takes.clear(); }, true, "Effacer les prises");
        else if (r == 4)
            s->removeTrack (trackId);
    });
}

void TimelineView::showSectionMenu (int sectionIndex)
{
    const auto& p = session.project();
    const auto& sec = p.sections[static_cast<size_t> (sectionIndex)];
    juce::PopupMenu m;
    m.addSectionHeader (sec.label + " (" + juce::String (sec.startSec, 1) + " - " + juce::String (sec.endSec, 1) + " s)");
    const auto* t = p.findTrack (session.selectedTrack());
    const bool can = t != nullptr && t->isVocal() && ! t->isGenerated();
    m.addItem (1, "Copier la voix de cette section vers les sections semblables" + (can ? " (" + t->name + ")" : juce::String()), can);
    m.addItem (2, "Placer la tête de lecture au début"_u8);
    m.addItem (3, "Punch-in sur cette section");
    juce::WeakReference<Session> weak (&session);
    juce::Component::SafePointer<TimelineView> safe (this);
    const int trackId = session.selectedTrack();
    const double a = sec.startSec, b = sec.endSec;
    m.showMenuAsync (juce::PopupMenu::Options(), [weak, safe, trackId, sectionIndex, a, b] (int r)
    {
        auto* s = weak.get();
        if (s == nullptr)
            return;
        if (r == 1)
            s->copySectionToSimilar (trackId, sectionIndex);
        else if (r == 2)
            s->setPositionSec (a);
        else if (r == 3 && safe != nullptr)
        {
            safe->punchIn = a;
            safe->punchOut = b;
            safe->repaint();
            if (safe->onRegionsChanged)
                safe->onRegionsChanged();
        }
    });
}
} // namespace sv::app
