let tracks = [];
let audioContext;
let selectedTrackIndex = null;
let isRecording = false;
let mediaRecorder;
let recordedChunks = [];
let stream;

const timeline = document.getElementById('timeline');
const addTrackBtn = document.getElementById('add-track-btn');
const recordBtn = document.getElementById('record-btn');
const stopBtn = document.getElementById('stop-btn');

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
        audioChunks: []
    };
    tracks.push(trackObj);

    // Créer le DOM
    const trackEl = document.createElement('div');
    trackEl.className = 'track';

    const headerEl = document.createElement('div');
    headerEl.className = 'track-header';
    headerEl.innerHTML = `<h3 class="track-title">${trackObj.name}</h3>`;

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
    timeline.appendChild(trackEl);

    // Initialiser le canvas
    trackObj.canvas = canvas;
    trackObj.canvasCtx = canvas.getContext('2d');

    // Resize observateur pour le canvas
    const resizeObserver = new ResizeObserver(() => {
        canvas.width = contentEl.clientWidth;
        canvas.height = contentEl.clientHeight;
        drawEmpty(trackObj.canvas, trackObj.canvasCtx);
    });
    resizeObserver.observe(contentEl);
}

function selectTrack(index) {
    selectedTrackIndex = index;
    document.querySelectorAll('.track-controls button').forEach((btn, i) => {
        btn.classList.toggle('active', i === index);
        btn.textContent = i === index ? 'Sélectionnée (Rec)' : 'Sélectionner';
    });
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
});

// Analyseur pour dessiner pendant l'enregistrement
let animationId;
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

        // Dessine la forme d'onde
        canvasCtx.fillStyle = 'rgba(30, 30, 30, 0.1)';
        canvasCtx.fillRect(x, 0, 2, canvas.height);

        canvasCtx.lineWidth = 2;
        canvasCtx.strokeStyle = '#4caf50';
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
        x += 1;
        if (x > canvas.width) {
            x = 0;
            drawEmpty(canvas, canvasCtx);
        }
    }
    drawEmpty(canvas, canvasCtx);
    draw();
}

async function visualizeBlob(blob, track) {
    // Une fois l'enregistrement terminé, on redessine le blob de manière statique
    const arrayBuffer = await blob.arrayBuffer();
    const audioBuffer = await audioContext.decodeAudioData(arrayBuffer);

    const canvas = track.canvas;
    const ctx = track.canvasCtx;

    drawEmpty(canvas, ctx);

    const data = audioBuffer.getChannelData(0);
    const step = Math.ceil(data.length / canvas.width);
    const amp = canvas.height / 2;

    ctx.fillStyle = '#4caf50';

    for (let i = 0; i < canvas.width; i++) {
        let min = 1.0;
        let max = -1.0;
        for (let j = 0; j < step; j++) {
            const datum = data[(i * step) + j];
            if (datum < min) min = datum;
            if (datum > max) max = datum;
        }
        ctx.fillRect(i, (1 + min) * amp, 1, Math.max(1, (max - min) * amp));
    }
}