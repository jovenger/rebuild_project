cmake_minimum_required(VERSION 3.22)

project(StudioVoix VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(SV_BUILD_APP "Construire l'application graphique" ON)
option(SV_BUILD_CLI "Construire l'outil en ligne de commande (inclut les tests)" ON)
# Numéro de build (CI : numéro d'exécution GitHub Actions) ; sert à détecter les mises à jour. 0 = compilation locale.
set(SV_BUILD_NUMBER 0 CACHE STRING "Numéro de build de StudioVoix")

# ---------------------------------------------------------------------------
# JUCE : version épinglée 9.0.4 (licence AGPLv3 ou licence commerciale JUCE 9).
# Pour éviter un téléchargement : -DFETCHCONTENT_SOURCE_DIR_JUCE=/chemin/vers/JUCE
# ---------------------------------------------------------------------------
include(FetchContent)
FetchContent_Declare(JUCE
    GIT_REPOSITORY https://github.com/juce-framework/JUCE.git
    GIT_TAG        9.0.4
    GIT_SHALLOW    TRUE)
FetchContent_MakeAvailable(JUCE)

# Sources du coeur (sans interface graphique), compilées dans chaque exécutable
# pour éviter les doublons de symboles des modules JUCE.
set(SV_CORE_SOURCES
    src/core/Log.cpp
    src/core/AudioIO.cpp
    src/core/Loudness.cpp
    src/core/analysis/PitchDetector.cpp
    src/core/analysis/KeyDetector.cpp
    src/core/analysis/TempoDetector.cpp
    src/core/analysis/StructureDetector.cpp
    src/core/analysis/VoiceActivity.cpp
    src/core/analysis/SpectrumAnalyzer.cpp
    src/core/analysis/BeatLibrary.cpp
    src/core/analysis/ContentClassifier.cpp
    src/core/dsp/PitchShifter.cpp
    src/core/dsp/PitchCorrector.cpp
    src/core/dsp/Processors.cpp
    src/core/dsp/TimingCorrector.cpp
    src/core/dsp/VocalChain.cpp
    src/core/dsp/ProblemAnalyzer.cpp
    src/core/dsp/Denoiser.cpp
    src/core/plugins/PluginChain.cpp
    src/core/plugins/InternalPlugins.cpp
    src/core/dsp/MasterChain.cpp
    src/core/style/StyleProfiles.cpp
    src/core/gen/BackingGenerator.cpp
    src/core/gen/TakeComper.cpp
    src/core/mix/AutoMixer.cpp
    src/core/assistant/CommandParser.cpp
    src/core/ai/AiClient.cpp
    src/core/ai/AiFeatures.cpp
    src/core/project/Project.cpp
    src/core/project/Renderer.cpp
    src/core/update/Updater.cpp)

set(SV_COMMON_DEFINITIONS
    JUCE_WEB_BROWSER=0
    JUCE_USE_CURL=0
    JUCE_JACK=0
    JUCE_USE_MP3AUDIOFORMAT=1
    JUCE_USE_LAME_AUDIO_FORMAT=1
    JUCE_USE_FLAC=1
    JUCE_USE_OGGVORBIS=1
    JUCE_PLUGINHOST_LADSPA=0
    JUCE_STRICT_REFCOUNTEDPOINTER=1
    JUCE_DISPLAY_SPLASH_SCREEN=0
    SV_BUILD_NUMBER=${SV_BUILD_NUMBER})

set(SV_CORE_MODULES
    juce::juce_core
    juce::juce_data_structures
    juce::juce_events
    juce::juce_audio_basics
    juce::juce_audio_formats
    juce::juce_audio_processors_headless
    juce::juce_cryptography
    juce::juce_dsp)

if(SV_BUILD_CLI)
    juce_add_console_app(studiovoix_cli
        PRODUCT_NAME "studiovoix_cli"
        NEEDS_WEB_BROWSER FALSE
        NEEDS_CURL FALSE)

    target_sources(studiovoix_cli PRIVATE
        ${SV_CORE_SOURCES}
        src/cli/CliMain.cpp
        src/tests/TestSignals.cpp
        src/tests/CoreTests.cpp)

    target_include_directories(studiovoix_cli PRIVATE src)
    target_compile_definitions(studiovoix_cli PRIVATE ${SV_COMMON_DEFINITIONS} JUCE_PLUGINHOST_VST3=0)
    target_link_libraries(studiovoix_cli
        PRIVATE
            ${SV_CORE_MODULES}
        PUBLIC
            juce::juce_recommended_config_flags
            juce::juce_recommended_warning_flags)

    enable_testing()
    add_test(NAME studiovoix_unit_tests COMMAND studiovoix_cli test)
endif()

if(SV_BUILD_APP)
    juce_add_gui_app(StudioVoix
        PRODUCT_NAME "StudioVoix"
        COMPANY_NAME "StudioVoix"
        NEEDS_WEB_BROWSER FALSE
        NEEDS_CURL FALSE
        MICROPHONE_PERMISSION_ENABLED TRUE
        MICROPHONE_PERMISSION_TEXT "StudioVoix enregistre ta voix depuis le micro.")

    target_sources(StudioVoix PRIVATE
        ${SV_CORE_SOURCES}
        src/app/Main.cpp
        src/app/AppSettings.cpp
        src/app/AudioEngine.cpp
        src/app/Session.cpp
        src/app/MainComponent.cpp
        src/app/TransportBar.cpp
        src/app/TimelineView.cpp
        src/app/RemixPanel.cpp
        src/app/LyricsPanel.cpp
        src/app/MixPanel.cpp
        src/app/GenerateDialog.cpp
        src/app/SettingsDialog.cpp
        src/app/ExportDialog.cpp
        src/app/AiPanel.cpp
        src/app/UpdateManager.cpp
        src/app/NewTrackDialog.cpp
        src/app/PluginManager.cpp)

    target_include_directories(StudioVoix PRIVATE src)
    target_compile_definitions(StudioVoix PRIVATE
        ${SV_COMMON_DEFINITIONS}
        JUCE_PLUGINHOST_VST3=1
        JUCE_APPLICATION_NAME_STRING="$<TARGET_PROPERTY:StudioVoix,JUCE_PRODUCT_NAME>"
        JUCE_APPLICATION_VERSION_STRING="$<TARGET_PROPERTY:StudioVoix,JUCE_VERSION>")
    target_link_libraries(StudioVoix
        PRIVATE
            ${SV_CORE_MODULES}
            juce::juce_audio_devices
            juce::juce_audio_processors
            juce::juce_audio_utils
            juce::juce_gui_basics
            juce::juce_gui_extra
        PUBLIC
            juce::juce_recommended_config_flags
            juce::juce_recommended_lto_flags
            juce::juce_recommended_warning_flags)
endif()
