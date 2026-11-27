# Banc de mesure de l'instru séparée (chantier B, 16/11/2026)

Matériel de recherche, pas un essai de la CI. Il mesure, sur des extraits à vérité connue (instru seule et voix seule
séparées à la source), les quatre défauts entendus dans l'instru de « Séparer une chanson » : restes de voix, sons
métalliques, volume qui bouge, aigus étouffés — et l'effet de traitements candidats.

- `sep.mjs`, `fidelity.mjs` : chaîne du produit hors navigateur (copies de `web/isolate.js` et `web/resample.js`
  attendues dans `../frozen/`, modèles dans `web/models/`, `onnxruntime-node` 1.22.0 installé avec
  `npm install --ignore-scripts`). `fidelity.mjs <song.wav> <truth_instru.wav>` doit redonner les chiffres du produit
  (16,25 dB et 6,28 dB à 48 kHz sur la chanson d'essai de la CI) : revérifié le 16/11.
- `lib.py` : définition des mesures ; `selftest.py` : cas fabriqués ; `run_bench.py`, `report.py` : candidats et
  tableaux ; `diag_*.py` : diagnostics ; `make_items.py`, `scan_musdb.py` : fabrication des extraits.
- Extraits utilisés : 12 extraits de l'échantillon MUSDB18 de 7 s (archive `MUSDB18-7-STEMS.zip` de la version v0.4.0
  de `sigsep/sigsep-mus-db` sur GitHub). Licences non commerciales ou de recherche : ces sons ne doivent pas entrer
  dans le dépôt.
- `RESULTATS-2026-11-16.txt` : tableaux complets de cette campagne.
- Ces scripts ont tourné dans un dossier de travail hors dépôt ; ils n'ont pas été rejoués depuis cet emplacement
  (chemins à adapter : `run_all.sh`).
