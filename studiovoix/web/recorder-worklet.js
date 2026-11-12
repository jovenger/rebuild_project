// StudioVoix Web : capture du micro dans le même graphe audio que l'instru (AudioWorklet).
// Chaque paquet envoyé porte le numéro d'échantillon du graphe (currentFrame) de son premier échantillon : la place de
// la prise par rapport à l'instru est donc connue à l'échantillon près, sans dépendre du démarrage de MediaRecorder.
class StudioVoixRecorder extends AudioWorkletProcessor {
    constructor() {
        super();
        this.size = 8192;
        this.buf = new Float32Array(this.size);
        this.fill = 0;
        this.chunkFrame = -1;
        this.running = true;
        this.port.onmessage = (e) => {
            if (e.data === 'stop') {
                this.flush();
                this.running = false;
                this.port.postMessage({ type: 'done' });
            }
        };
    }
    flush() {
        if (this.fill > 0) {
            this.port.postMessage({ type: 'chunk', frame: this.chunkFrame, data: this.buf.slice(0, this.fill) });
            this.fill = 0;
            this.chunkFrame = -1;
        }
    }
    process(inputs) {
        if (!this.running) return false;
        const input = inputs[0];
        if (input && input.length > 0 && input[0]) {
            const n = input[0].length;
            for (let i = 0; i < n; ++i) {
                if (this.fill === 0) this.chunkFrame = currentFrame + i;
                let s = 0;
                for (let c = 0; c < input.length; ++c) s += input[c][i];
                this.buf[this.fill++] = s / input.length;
                if (this.fill === this.size) this.flush();
            }
        }
        return true;
    }
}
registerProcessor('studiovoix-recorder', StudioVoixRecorder);
