document.addEventListener('DOMContentLoaded', () => {

    // --- Gestion de l'accès (Simulation) ---
    const keys = ['text', 'image', 'video', 'audio'];

    // Vérifier si un email est déjà enregistré
    const savedEmail = localStorage.getItem('user_email');
    if(savedEmail) {
        document.getElementById('user-email').value = savedEmail;
        document.getElementById('config-status').textContent = "Accès actif pour " + savedEmail;
        document.getElementById('config-status').style.color = "lightgreen";
    }

    document.getElementById('generate-access').addEventListener('click', () => {
        const email = document.getElementById('user-email').value;
        const status = document.getElementById('config-status');

        if (!email || !email.includes('@')) {
            status.textContent = "Veuillez entrer une adresse email valide.";
            status.style.color = "red";
            return;
        }

        // Sauvegarde de l'email
        localStorage.setItem('user_email', email);

        // Génération de clés fictives pour la simulation
        keys.forEach(key => {
            localStorage.setItem(`api_${key}`, `auto-gen-key-${key}-${Math.random().toString(36).substr(2, 9)}`);
        });

        status.textContent = `Accès généré avec succès pour ${email}. Les modules sont prêts.`;
        status.style.color = "lightgreen";
    });

    // --- Fonctions utilitaires ---
    const getApiKey = (type) => {
        const key = localStorage.getItem(`api_${type}`);
        if (!key) {
            alert(`Veuillez d'abord générer votre accès avec votre adresse email.`);
            return null;
        }
        return key;
    };

    const simulateLoading = (outputElement) => {
        outputElement.innerHTML = '<em>Génération en cours (Simulation via API externe requise)...</em>';
    };

    // --- Module Texte ---
    document.getElementById('btn-text').addEventListener('click', async () => {
        const key = getApiKey('text');
        if (!key) return;
        const prompt = document.getElementById('prompt-text').value;
        const output = document.getElementById('output-text');
        simulateLoading(output);

        // Exemple d'intégration (fictive ici, nécessite une vraie requête fetch vers OpenAI/Anthropic)
        setTimeout(() => {
            output.innerHTML = `<p><strong>Résultat (Simulation):</strong> Ceci est le texte généré pour le prompt: "${prompt}". L'API avec la clé configurée devrait être appelée ici.</p>`;
        }, 1500);
    });

    // --- Module Image / Modélisme ---
    document.getElementById('btn-image').addEventListener('click', () => {
        const key = getApiKey('image');
        if (!key) return;
        const prompt = document.getElementById('prompt-image').value;
        const output = document.getElementById('output-image');
        simulateLoading(output);

        setTimeout(() => {
            output.innerHTML = `<p><strong>Résultat Image (Simulation):</strong> Modèle/Image généré pour: "${prompt}".</p><div style="width:100%; height:150px; background:#333; display:flex; align-items:center; justify-content:center; color:#666;">[Image / Modèle 3D rendu]</div>`;
        }, 2000);
    });

    // --- Module Vidéo (Visage) ---
    document.getElementById('btn-video').addEventListener('click', () => {
        const key = getApiKey('video');
        if (!key) return;
        const prompt = document.getElementById('prompt-video').value;
        const fileInput = document.getElementById('input-face');
        const output = document.getElementById('output-video');

        let hasFile = fileInput.files && fileInput.files.length > 0;
        simulateLoading(output);

        setTimeout(() => {
            output.innerHTML = `<p><strong>Résultat Vidéo (Simulation):</strong> Film généré pour: "${prompt}". <br>Visage source fourni: ${hasFile ? 'Oui' : 'Non'}</p><div style="width:100%; height:200px; background:#222; display:flex; align-items:center; justify-content:center; color:#666;">[Lecteur Vidéo Rendu]</div>`;
        }, 2500);
    });

    // --- Module Musique Contextualisée ---
    document.getElementById('btn-audio').addEventListener('click', () => {
        const key = getApiKey('audio');
        if (!key) return;
        const prompt = document.getElementById('prompt-audio').value;
        const output = document.getElementById('output-audio');
        simulateLoading(output);

        setTimeout(() => {
            output.innerHTML = `<p><strong>Résultat Audio (Simulation):</strong> Musique générée en fonction du décor et thème: "${prompt}".</p><audio controls style="width:100%;"><source src="#" type="audio/mpeg">Votre navigateur ne supporte pas l'élément audio.</audio>`;
        }, 2000);
    });
});
