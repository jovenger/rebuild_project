const express = require('express');
const path = require('path');
require('dotenv').config();
const { GoogleGenerativeAI } = require('@google/generative-ai');

const app = express();
const port = 8000;

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Initialisation de Google Gemini AI
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || 'MISSING_KEY');
const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

app.post('/api/generate-lyrics', async (req, res) => {
    try {
        const prompt = req.body.prompt;

        if (!process.env.GEMINI_API_KEY) {
            return res.status(400).json({ error: 'La clé API Gemini (GEMINI_API_KEY) n\'est pas configurée dans le fichier .env' });
        }

        if (!prompt) {
            return res.status(400).json({ error: 'Aucun texte fourni' });
        }

        const chatPrompt = `Tu es un parolier professionnel et un ghostwriter. Le client te demande ceci : "${prompt}".
Réponds directement avec des paroles créatives, structurées en couplets (Verset) et refrains. Sois productif et qualitatif. Ne mets pas de blabla au début ou à la fin.`;

        const result = await model.generateContent(chatPrompt);
        const response = await result.response;
        const text = response.text();

        res.json({ text: text });

    } catch (error) {
        console.error('Erreur API Gemini:', error);
        res.status(500).json({ error: 'Erreur lors de la génération avec l\'IA.' });
    }
});

app.listen(port, () => {
    console.log(`Le Mini Studio Web tourne sur http://localhost:${port}`);
});