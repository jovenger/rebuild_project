let tracks = [];
let audioContext;
let selectedTrackIndex = null;
let isRecording = false;
let mediaRecorder;
let recordedChunks = [];
let stream;

const tracksContainer = document.getElementById('tracks-container');
const timeline = document.getElementById('timeline');
const addTrackBtn = document.getElementById('add-track-btn');
const recordBtn = document.getElementById('record-btn');
const stopBtn = document.getElementById('stop-btn');
const playBtn = document.getElementById('play-btn');
const playhead = document.getElementById('playhead');

// Zoom temporel
const PIXELS_PER_SECOND = 50;

// Initialiser l'audio context sur la première interaction
function initAudioContext() {
    if (!audioContext) {
        audioContext = new (window.AudioContext || window.webkitAudioContext)();
    }
}

addTrackBtn.addEventListener('click', () => {
    initAudioContext();
    addTrack();
});

function addTrack() {
    const trackIndex = tracks.length;
    const trackObj = {
        id: trackIndex,
        name: `Piste ${trackIndex + 1}`,
        canvas: null,
        canvasCtx: null,
        audioChunks: [],
        audioBuffer: null,
        isMuted: false,
        isSolo: false,
        volume: 1.0,
        gainNode: null
    };
    tracks.push(trackObj);

    // Créer le DOM
    const trackEl = document.createElement('div');
    trackEl.className = 'track';

    const headerEl = document.createElement('div');
    headerEl.className = 'track-header';
    headerEl.innerHTML = `<h3 class="track-title">${trackObj.name}</h3>`;

    // Contrôles de Mix (Mute, Solo, Vol)
    const mixControls = document.createElement('div');
    mixControls.className = 'mix-controls';

    const muteBtn = document.createElement('button');
    muteBtn.className = 'mute';
    muteBtn.textContent = 'M';
    muteBtn.onclick = () => toggleMute(trackIndex, muteBtn);

    const soloBtn = document.createElement('button');
    soloBtn.className = 'solo';
    soloBtn.textContent = 'S';
    soloBtn.onclick = () => toggleSolo(trackIndex, soloBtn);

    mixControls.appendChild(muteBtn);
    mixControls.appendChild(soloBtn);
    headerEl.appendChild(mixControls);

    const volControl = document.createElement('div');
    volControl.className = 'vol-control';
    volControl.innerHTML = `<span>Vol</span><input type="range" min="0" max="2" step="0.1" value="1">`;
    const volInput = volControl.querySelector('input');
    volInput.oninput = (e) => setVolume(trackIndex, e.target.value);
    headerEl.appendChild(volControl);

    // Bouton de sélection (Record Arm)
    const controlsEl = document.createElement('div');
    controlsEl.className = 'track-controls';

    const selectBtn = document.createElement('button');
    selectBtn.textContent = 'Sélectionner';
    selectBtn.onclick = () => selectTrack(trackIndex);
    if (tracks.length === 1) selectTrack(0); // Auto-sélectionne la première piste

    controlsEl.appendChild(selectBtn);
    headerEl.appendChild(controlsEl);

    const contentEl = document.createElement('div');
    contentEl.className = 'track-content';

    const canvas = document.createElement('canvas');
    contentEl.appendChild(canvas);

    trackEl.appendChild(headerEl);
    trackEl.appendChild(contentEl);
    tracksContainer.appendChild(trackEl);

    // Initialiser le canvas
    trackObj.canvas = canvas;
    trackObj.canvasCtx = canvas.getContext('2d');

    // On force une grande largeur pour scroller
    canvas.width = PIXELS_PER_SECOND * 300; // 5 minutes max par défaut

    const resizeObserver = new ResizeObserver(() => {
        canvas.height = contentEl.clientHeight;
        drawEmpty(trackObj.canvas, trackObj.canvasCtx);
        if (trackObj.audioBuffer) {
            redrawBuffer(trackObj);
        }
    });
    resizeObserver.observe(contentEl);

    // Logique de sélection sur le canvas
    setupCanvasSelection(canvas, trackIndex);
}

// Fonction utilitaire pour "silencer" une portion du buffer audio
function deleteSelectedAudio() {
    if (selectedTrackForEdit === null || selectionStartPx === null || selectionEndPx === null) return;

    const track = tracks[selectedTrackForEdit];
    if (!track.audioBuffer) return;

    // Convertir les pixels en temps (secondes)
    const startTime = selectionStartPx / PIXELS_PER_SECOND;
    const endTime = selectionEndPx / PIXELS_PER_SECOND;

    if (startTime >= track.audioBuffer.duration) return;

    const sampleRate = track.audioBuffer.sampleRate;
    const startSample = Math.floor(startTime * sampleRate);
    const endSample = Math.floor(endTime * sampleRate);

    // Mettre à zéro (silence) les échantillons dans la zone sélectionnée
    for (let channel = 0; channel < track.audioBuffer.numberOfChannels; channel++) {
        const channelData = track.audioBuffer.getChannelData(channel);
        for (let i = startSample; i < endSample && i < channelData.length; i++) {
            channelData[i] = 0;
        }
    }

    // Annuler la sélection et redessiner
    selectionStartPx = null;
    selectionEndPx = null;
    redrawBuffer(track);
}

// Écouter la touche "Suppr" ou "Backspace" au niveau du document
document.addEventListener('keydown', (e) => {
    if (e.key === 'Delete' || e.key === 'Backspace') {
        deleteSelectedAudio();
    }
});

let selectionStartPx = null;
let selectionEndPx = null;
let selectedTrackForEdit = null;

function setupCanvasSelection(canvas, trackIndex) {
    let isSelecting = false;
    let startX = 0;

    canvas.addEventListener('mousedown', (e) => {
        if (isRecording || isPlaying) return;
        const rect = canvas.getBoundingClientRect();
        startX = e.clientX - rect.left;
        selectionStartPx = startX;
        selectionEndPx = startX;
        selectedTrackForEdit = trackIndex;
        isSelecting = true;
        redrawBuffer(tracks[trackIndex]); // Redessine pour montrer le début de sélection
    });

    canvas.addEventListener('mousemove', (e) => {
        if (!isSelecting) return;
        const rect = canvas.getBoundingClientRect();
        selectionEndPx = e.clientX - rect.left;
        redrawBuffer(tracks[trackIndex]);
    });

    canvas.addEventListener('mouseup', () => {
        if (!isSelecting) return;
        isSelecting = false;
        if (Math.abs(selectionEndPx - selectionStartPx) < 5) {
            // Clic simple = annuler la sélection
            selectionStartPx = null;
            selectionEndPx = null;
            selectedTrackForEdit = null;
        } else {
            // S'assurer que start est toujours < end
            if (selectionStartPx > selectionEndPx) {
                let temp = selectionStartPx;
                selectionStartPx = selectionEndPx;
                selectionEndPx = temp;
            }
        }
        redrawBuffer(tracks[trackIndex]);
        updateAllCanvasesSelectionState(); // Nettoie la sélection sur les autres pistes
    });
}

function updateAllCanvasesSelectionState() {
    tracks.forEach((track, i) => {
        if (i !== selectedTrackForEdit && track.audioBuffer) {
            redrawBuffer(track);
        }
    });
}

function selectTrack(index) {
    selectedTrackIndex = index;
    document.querySelectorAll('.track-controls button').forEach((btn, i) => {
        btn.classList.toggle('active', i === index);
        btn.textContent = i === index ? 'Sélectionnée (Rec)' : 'Sélectionner';
    });
}

function toggleMute(index, btn) {
    tracks[index].isMuted = !tracks[index].isMuted;
    btn.classList.toggle('active', tracks[index].isMuted);
    updateTrackNodes(index);
}

function toggleSolo(index, btn) {
    tracks[index].isSolo = !tracks[index].isSolo;
    btn.classList.toggle('active', tracks[index].isSolo);
    updateAllTracksSoloState();
}

function setVolume(index, value) {
    tracks[index].volume = parseFloat(value);
    if (tracks[index].gainNode) {
        tracks[index].gainNode.gain.value = getTrackEffectiveGain(index);
    }
}

function updateAllTracksSoloState() {
    tracks.forEach((t, i) => updateTrackNodes(i));
}

function getTrackEffectiveGain(index) {
    const track = tracks[index];
    if (track.isMuted) return 0;

    const anyTrackSoloed = tracks.some(t => t.isSolo);
    if (anyTrackSoloed && !track.isSolo) return 0;

    return track.volume;
}

function updateTrackNodes(index) {
    const track = tracks[index];
    if (track.gainNode) {
        track.gainNode.gain.value = getTrackEffectiveGain(index);
    }
}

function drawEmpty(canvas, ctx) {
    ctx.fillStyle = '#1e1e1e';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.lineWidth = 1;
    ctx.strokeStyle = '#444';
    ctx.beginPath();
    ctx.moveTo(0, canvas.height / 2);
    ctx.lineTo(canvas.width, canvas.height / 2);
    ctx.stroke();
}

recordBtn.addEventListener('click', async () => {
    if (isRecording) return;
    if (selectedTrackIndex === null) {
        alert("Veuillez d'abord ajouter et sélectionner une piste.");
        return;
    }

    initAudioContext();

    try {
        stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        startRecording(stream);
    } catch (err) {
        console.error("Erreur d'accès au micro: ", err);
        alert("Impossible d'accéder au microphone.");
    }
});

function startRecording(stream) {
    isRecording = true;
    recordedChunks = [];
    recordBtn.textContent = 'Enregistrement...';
    recordBtn.classList.replace('record', 'recording');

    mediaRecorder = new MediaRecorder(stream);

    mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) {
            recordedChunks.push(e.data);
        }
    };

    mediaRecorder.onstop = () => {
        const track = tracks[selectedTrackIndex];
        const blob = new Blob(recordedChunks, { type: 'audio/webm' });
        track.audioChunks.push(blob);

        visualizeBlob(blob, track);
    };

    if (isPlaying) stopPlayback();
    recordStartTime = audioContext.currentTime;
    playhead.style.display = 'block';
    animatePlayhead();

    mediaRecorder.start();

    // Visualisation en temps réel (Ondulation pendant l'enregistrement)
    visualizeRealTime(stream, tracks[selectedTrackIndex]);
}

stopBtn.addEventListener('click', () => {
    if (!isRecording) return;

    mediaRecorder.stop();
    stream.getTracks().forEach(track => track.stop());

    isRecording = false;
    recordBtn.textContent = 'Enregistrer';
    recordBtn.classList.replace('recording', 'record');

    cancelAnimationFrame(cursorAnimationId);
    playhead.style.display = 'none';
    playhead.style.left = '0px';
});

let isPlaying = false;
let playStartTime = 0;
let animationId;
let sourceNodes = [];
let cursorAnimationId;

playBtn.addEventListener('click', () => {
    initAudioContext();
    if (isPlaying) {
        stopPlayback();
    } else {
        startPlayback();
    }
});

function startPlayback() {
    if (isRecording || tracks.length === 0) return;

    isPlaying = true;
    playBtn.textContent = 'Pause';
    playBtn.classList.replace('play', 'playing');
    playhead.style.display = 'block';

    playStartTime = audioContext.currentTime;

    tracks.forEach((track, index) => {
        if (track.audioBuffer) {
            const source = audioContext.createBufferSource();
            source.buffer = track.audioBuffer;

            const gainNode = audioContext.createGain();
            track.gainNode = gainNode;
            gainNode.gain.value = getTrackEffectiveGain(index);

            source.connect(gainNode);
            gainNode.connect(audioContext.destination);

            source.start(0);
            sourceNodes.push(source);
        }
    });

    animatePlayhead();
}

function stopPlayback() {
    if (!isPlaying) return;

    isPlaying = false;
    playBtn.textContent = 'Jouer (Play)';
    playBtn.classList.replace('playing', 'play');
    playhead.style.display = 'none';

    sourceNodes.forEach(source => {
        try { source.stop(); } catch(e) {}
    });
    sourceNodes = [];
    cancelAnimationFrame(cursorAnimationId);
    playhead.style.left = '0px';
}

function animatePlayhead() {
    if (!isPlaying && !isRecording) return;

    const elapsedTime = isPlaying ? (audioContext.currentTime - playStartTime) : (audioContext.currentTime - recordStartTime);

    const xPos = elapsedTime * PIXELS_PER_SECOND;

    playhead.style.left = `${xPos}px`;

    // Scroll auto si le curseur sort de la vue
    if (xPos > timeline.scrollLeft + timeline.clientWidth - 50) {
        timeline.scrollLeft = xPos - timeline.clientWidth / 2;
    }

    cursorAnimationId = requestAnimationFrame(animatePlayhead);
}

let recordStartTime = 0;

// Analyseur pour dessiner pendant l'enregistrement
function visualizeRealTime(stream, track) {
    const source = audioContext.createMediaStreamSource(stream);
    const analyser = audioContext.createAnalyser();
    analyser.fftSize = 2048;
    source.connect(analyser);

    const bufferLength = analyser.frequencyBinCount;
    const dataArray = new Uint8Array(bufferLength);
    const canvas = track.canvas;
    const canvasCtx = track.canvasCtx;

    let x = 0;

    function draw() {
        if (!isRecording) {
            cancelAnimationFrame(animationId);
            return;
        }

        animationId = requestAnimationFrame(draw);
        analyser.getByteTimeDomainData(dataArray);

        const elapsedTime = audioContext.currentTime - recordStartTime;
        x = elapsedTime * PIXELS_PER_SECOND;

        // Dessine la forme d'onde (nettoyage autour du curseur)
        canvasCtx.fillStyle = 'rgba(30, 30, 30, 0.1)';
        canvasCtx.fillRect(x - 2, 0, 4, canvas.height);

        canvasCtx.lineWidth = 2;
        canvasCtx.strokeStyle = '#f44336';
        canvasCtx.beginPath();

        let v = dataArray[0] / 128.0;
        let y = v * canvas.height / 2;
        canvasCtx.moveTo(x, y);

        for(let i = 1; i < bufferLength; i += 100) {
            v = dataArray[i] / 128.0;
            y = v * canvas.height / 2;
            canvasCtx.lineTo(x, y);
        }
        canvasCtx.stroke();
    }
    drawEmpty(canvas, canvasCtx);
    draw();
}

async function visualizeBlob(blob, track) {
    const arrayBuffer = await blob.arrayBuffer();
    const audioBuffer = await audioContext.decodeAudioData(arrayBuffer);

    track.audioBuffer = audioBuffer;
    redrawBuffer(track);
}

function redrawBuffer(track) {
    if (!track.audioBuffer) return;
    const canvas = track.canvas;
    const ctx = track.canvasCtx;

    drawEmpty(canvas, ctx);

    const duration = track.audioBuffer.duration;
    const widthInPx = duration * PIXELS_PER_SECOND;

    const data = track.audioBuffer.getChannelData(0);
    const step = Math.max(1, Math.ceil(data.length / widthInPx));
    const amp = canvas.height / 2;

    ctx.fillStyle = '#4caf50';

    for (let i = 0; i < widthInPx; i++) {
        let min = 1.0;
        let max = -1.0;
        for (let j = 0; j < step; j++) {
            const index = (i * step) + j;
            if (index < data.length) {
                const datum = data[index];
                if (datum < min) min = datum;
                if (datum > max) max = datum;
            }
        }
        ctx.fillRect(i, (1 + min) * amp, 1, Math.max(1, (max - min) * amp));
    }

    // Dessiner la zone de sélection si elle appartient à cette piste
    if (selectedTrackForEdit === track.id && selectionStartPx !== null && selectionEndPx !== null) {
        ctx.fillStyle = 'rgba(255, 255, 255, 0.3)';
        const selWidth = selectionEndPx - selectionStartPx;
        ctx.fillRect(selectionStartPx, 0, selWidth, canvas.height);

        ctx.strokeStyle = '#fff';
        ctx.lineWidth = 1;
        ctx.strokeRect(selectionStartPx, 0, selWidth, canvas.height);
    }
}