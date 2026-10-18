#include "TimelineView.h"

#include "NewTrackDialog.h"
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
    const auto red = juce::Colour (0xffe53935);
    g.setColour (on ? (down ? red.darker (0.3f) : red) : (down ? juce::Colour (0xff5a2a2a) : juce::Colour (0xff3a2a2a)));
    g.fillEllipse (c);
    g.setColour (on ? juce::Colours::white.withAlpha (0.85f) : red);
    g.drawEllipse (c.reduced (0.5f), highlighted ? 2.0f : 1.4f);
}

TrackHeader::TrackHeader (Session& s, int trackId) : session (s), id (trackId)
{
    for (auto* c : std::initializer_list<juce::Component*> { &arm, &name, &info, &mute, &solo, &raw, &remove, &volume, &pan })
        addAndMakeVisible (*c);

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
    if (! t->takes.empty())
        txt << " | " << juce::String ((int) t->takes.size()) << " prise(s)" << (t->comp == project::CompMode::Best ? " (meilleure auto)" : "");
    const auto st = session.trackStatus (id);
    if (st.isNotEmpty())
        txt << "\n" << st;
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

void TrackHeader::paint (juce::Graphics& g)
{
    const auto* t = session.project().findTrack (id);
    const bool selected = session.selectedTrack() == id;
    g.fillAll (selected ? juce::Colour (0xff2f3a48) : juce::Colour (0xff23282f));
    if (t != nullptr)
    {
        g.setColour (roleColour (t->role));
        g.fillRect (0, 0, 5, getHeight());
    }
    g.setColour (juce::Colours::black);
    g.drawRect (getLocalBounds());
    if (session.armedTrack() == id)
    {
        g.setColour (juce::Colour (0xffe53935));
        g.drawRect (getLocalBounds(), 2);
    }
}

void TrackHeader::mouseDown (const juce::MouseEvent& e)
{
    session.selectTrack (id);
    if (e.mods.isPopupMenu())
        if (auto* tv = findParentComponentOfClass<TimelineView>())
            tv->openTrackMenu (id);
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
    raw.setBounds (top.removeFromRight (40));
    top.removeFromRight (2);
    solo.setBounds (top.removeFromRight (22));
    top.removeFromRight (2);
    mute.setBounds (top.removeFromRight (22));
    name.setBounds (top);
    info.setBounds (r.removeFromTop (30));
    auto bottom = r.removeFromTop (20);
    pan.setBounds (bottom.removeFromRight (60));
    volume.setBounds (bottom);
}

// =============================================================================================
TimelineView::TimelineView (Session& s) : session (s)
{
    setWantsKeyboardFocus (false);
    refresh();
}

double TimelineView::xToSec (int x) const { return viewStart + (x - kHeaderWidth) / pxPerSec; }
int TimelineView::secToX (double s) const { return kHeaderWidth + static_cast<int> (std::round ((s - viewStart) * pxPerSec)); }

int TimelineView::trackIndexAt (int y) const
{
    if (y < kRulerHeight)
        return -1;
    const int idx = (y - kRulerHeight + scrollY) / kTrackHeight;
    return idx < static_cast<int> (session.project().tracks.size()) ? idx : -1;
}

void TimelineView::clampView()
{
    viewStart = std::max (0.0, viewStart);
    const int contentH = static_cast<int> (session.project().tracks.size()) * kTrackHeight;
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
        const int y = kRulerHeight + static_cast<int> (i) * kTrackHeight - scrollY;
        headers[i]->setBounds (0, y, kHeaderWidth, kTrackHeight);
        headers[i]->setVisible (y + kTrackHeight > kRulerHeight && y < getHeight());
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
    g.fillAll (juce::Colour (0xff15181c));
    const int w = getWidth();
    const auto clip = g.getClipBounds();   // tête de lecture : seule une bande étroite est à redessiner

    // Pistes
    g.saveState();
    g.reduceClipRegion (kHeaderWidth, kRulerHeight, w - kHeaderWidth, getHeight() - kRulerHeight);
    for (size_t i = 0; i < p.tracks.size(); ++i)
    {
        const auto& t = p.tracks[i];
        const int y = kRulerHeight + static_cast<int> (i) * kTrackHeight - scrollY;
        if (y + kTrackHeight < kRulerHeight || y > getHeight() || y + kTrackHeight < clip.getY() || y > clip.getBottom())
            continue;
        const bool selected = session.selectedTrack() == t.id;
        g.setColour (selected ? juce::Colour (0xff1f2630) : (i % 2 == 0 ? juce::Colour (0xff181c21) : juce::Colour (0xff1b1f25)));
        g.fillRect (kHeaderWidth, y, w - kHeaderWidth, kTrackHeight);

        // Zones des prises (vocal) en contour.
        g.setColour (roleColour (t.role).withAlpha (0.25f));
        for (const auto& tk : t.takes)
        {
            const int x1 = secToX (tk.regionStart / p.sampleRate), x2 = secToX (tk.regionEnd / p.sampleRate);
            g.drawRect (x1, y + 3, std::max (1, x2 - x1), kTrackHeight - 6);
        }

        if (const auto* wc = waveFor (t))
        {
            const auto col = roleColour (t.role);
            const double binSec = 0.01;
            const double startSec = wc->start / p.sampleRate;
            const int mid = y + kTrackHeight / 2;
            const float half = (kTrackHeight - 10) * 0.5f;
            const int xa = std::max ({ kHeaderWidth, clip.getX() - 1, secToX (startSec) });
            const int xb = std::min ({ w, clip.getRight() + 1, secToX (startSec + wc->peaks.size() * binSec) });
            g.setColour (col.withAlpha (0.15f));
            g.fillRect (xa, y + 4, std::max (0, xb - xa), kTrackHeight - 8);
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
                        kHeaderWidth + 10, y, 600, kTrackHeight, juce::Justification::centredLeft);
        }
        g.setColour (juce::Colours::black);
        g.drawHorizontalLine (y + kTrackHeight - 1, static_cast<float> (kHeaderWidth), static_cast<float> (w));
    }
    {
        const int yEnd = kRulerHeight + static_cast<int> (p.tracks.size()) * kTrackHeight - scrollY;
        if (yEnd + 30 < getHeight())
        {
            g.setColour (juce::Colours::grey);
            g.setFont (13.0f);
            g.drawText ("Clic droit : nouvelle piste (voix, back, doublage, harmonie, ad-libs, ambiance, instrument)"_u8,
                        kHeaderWidth + 10, yEnd + 8, 900, 20, juce::Justification::centredLeft);
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
    g.fillRect (kHeaderWidth, 0, w - kHeaderWidth, kRulerHeight);
    for (size_t i = 0; i < p.sections.size(); ++i)
    {
        const auto& s = p.sections[i];
        const int x1 = std::max (kHeaderWidth, secToX (s.startSec)), x2 = secToX (s.endSec);
        if (x2 <= kHeaderWidth || x1 > w)
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
        if (x < kHeaderWidth)
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
        if (x < kHeaderWidth)
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
    g.setColour (juce::Colour (0xff1e2228));
    g.fillRect (0, 0, kHeaderWidth, kRulerHeight);
    g.setColour (juce::Colours::grey);
    g.setFont (10.0f);
    g.drawFittedText ("Clic = position | Maj+glisser = punch | Alt+glisser = boucle\nDouble-clic section = copier | Ctrl+molette = zoom",
                      4, 2, kHeaderWidth - 8, kRulerHeight - 4, juce::Justification::topLeft, 3);

    // Tête de lecture
    const int px = secToX (session.positionSec());
    if (px >= kHeaderWidth && px <= w)
    {
        g.setColour (session.isRecording() ? juce::Colours::red : juce::Colours::white);
        g.drawVerticalLine (px, 0.0f, static_cast<float> (getHeight()));
    }
    lastPlayheadX = px;
}

void TimelineView::updatePlayhead()
{
    const double t = session.positionSec();
    const int px = secToX (t);
    // Défilement automatique pendant la lecture.
    if (session.engine().isPlaying() && (px > getWidth() - 40 || px < kHeaderWidth))
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
    if (e.x < kHeaderWidth)
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
        session.selectTrack (id);
        if (e.mods.isPopupMenu())
            showTrackMenu (id);
        else if (! session.isRecording())
            session.setPositionSec (t);
    }
}

void TimelineView::mouseDrag (const juce::MouseEvent& e)
{
    const double t = std::max (0.0, xToSec (e.x));
    switch (drag)
    {
        case Drag::Playhead: session.setPositionSec (t); break;
        case Drag::Punch:    punchIn = std::min (dragAnchor, t); punchOut = std::max (dragAnchor, t); break;
        case Drag::Loop:     loopA = std::min (dragAnchor, t); loopB = std::max (dragAnchor, t); break;
        case Drag::None:     break;
    }
    repaint();
}

void TimelineView::mouseUp (const juce::MouseEvent&)
{
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
    if (e.y >= 18 || e.x < kHeaderWidth)
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
        viewStart = anchor - (e.x - kHeaderWidth) / pxPerSec;
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

void TimelineView::showTrackMenu (int trackId)
{
    const auto* t = session.project().findTrack (trackId);
    if (t == nullptr)
        return;
    juce::PopupMenu m;
    m.addSectionHeader (t->name);
    m.addItem (10, "Nouvelle piste...");
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
    m.addItem (4, "Supprimer la piste");
    juce::WeakReference<Session> weak (&session);
    m.showMenuAsync (juce::PopupMenu::Options(), [weak, trackId] (int r)
    {
        auto* s = weak.get();
        if (s == nullptr || r == 0)
            return;
        if (r == 10)
            showNewTrackDialog (*s);
        else if (r == 11)
            s->armTrack (s->armedTrack() == trackId ? -1 : trackId);
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
