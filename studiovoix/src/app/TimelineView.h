#pragma once

#include <juce_gui_basics/juce_gui_basics.h>

#include "Session.h"

// Timeline : règle (mesures, sections, marqueurs, zones punch / boucle), pistes avec forme d'onde,
// tête de lecture. Molette = défilement vertical, Maj+molette = horizontal, Ctrl+molette = zoom.
namespace sv::app
{
class TrackHeader final : public juce::Component
{
public:
    TrackHeader (Session& session, int trackId);
    void refresh();
    void resized() override;
    void paint (juce::Graphics& g) override;
    void mouseDown (const juce::MouseEvent& e) override;
    int trackId() const { return id; }

private:
    Session& session;
    const int id;
    juce::Label name, info;
    juce::TextButton mute { "M" }, solo { "S" }, raw { "Brut" }, remove { "X" };
    juce::Slider volume, pan;
    bool updating = false;
};

class TimelineView final : public juce::Component
{
public:
    explicit TimelineView (Session& session);

    void refresh();             // structure des pistes modifiée
    void updatePlayhead();      // ~30 fois par seconde
    void paint (juce::Graphics& g) override;
    void resized() override;
    void mouseDown (const juce::MouseEvent& e) override;
    void mouseDrag (const juce::MouseEvent& e) override;
    void mouseUp (const juce::MouseEvent& e) override;
    void mouseDoubleClick (const juce::MouseEvent& e) override;
    void mouseWheelMove (const juce::MouseEvent& e, const juce::MouseWheelDetails& w) override;

    double punchInSec() const { return punchIn; }
    double punchOutSec() const { return punchOut; }
    double loopStartSec() const { return loopA; }
    double loopEndSec() const { return loopB; }
    std::function<void()> onRegionsChanged;

    static constexpr int kHeaderWidth = 260;
    static constexpr int kRulerHeight = 48;
    static constexpr int kTrackHeight = 78;

private:
    struct WaveCache
    {
        const void* key = nullptr;
        bool raw = false;
        std::vector<float> peaks;   // max abs par case de 10 ms
        long start = 0;
    };

    double xToSec (int x) const;
    int secToX (double s) const;
    int trackIndexAt (int y) const;
    const WaveCache* waveFor (const project::Track& t);
    void showTrackMenu (int trackId);
    void showSectionMenu (int sectionIndex);
    void clampView();

    Session& session;
    std::vector<std::unique_ptr<TrackHeader>> headers;
    std::map<int, WaveCache> waves;
    double pxPerSec = 40.0;
    double viewStart = 0.0;
    int scrollY = 0;
    double punchIn = 0.0, punchOut = 0.0, loopA = 0.0, loopB = 0.0;
    enum class Drag { None, Playhead, Punch, Loop } drag = Drag::None;
    double dragAnchor = 0.0;
    int lastPlayheadX = -1;
};
} // namespace sv::app
