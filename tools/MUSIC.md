# Musiques d'entrée

Le site utilise uniquement le lecteur audio natif du navigateur, sans barre
supplémentaire, iframe ou requête YouTube. Ouvrir `index.html` normalement.
Les boutons musique existants et la touche M gardent leur fonctionnement.

## Sources

- `themes-local.js` associe 86 personnages à des MP3 de 30 secondes dans `audio/`.
  Les fichiers locaux sont prioritaires et lisibles hors connexion. Le titre de
  Liv Morgan est **Trouble** ; l'ancien ajout **Livin' Large** a été remplacé.
- `themes.js` conserve les extraits audio directs existants. Il contient aussi
  **Girl Power — Fabien Colella** pour Amale, trouvé avec le nom du compositeur.
  La source de cet extrait est consignée dans `amale-source.json`.
- `local-music-report.json` conserve la page source, le titre déclaré, l'artiste,
  la taille et le SHA-256 de chaque MP3 local. Les fichiers proviennent des liens
  de téléchargement publics consultés sur MP3.pm ; aucune extraction YouTube.
  Certains thèmes correspondent à une période antérieure ou à une équipe.
- Aucun morceau arbitraire ou ambiance générique n'est affecté à Michel Bojolé
  Prime, Samantha Irvin et Renee Paquette, sans thème identifié. Dans un duel,
  le thème disponible de l'autre personnage peut jouer.

## Reconstruction et vérification

`build-local-music.py` utilise une sélection relue de `direct-candidates.json`.
Il prépare les extraits avec FFmpeg : 30 secondes, MP3 128 kbit/s, 44,1 kHz,
stéréo, volume harmonisé et fondu final. Il réutilise les fichiers déjà validés.
Ne pas régénérer les candidats sans revoir les indices de sélection.
L'outil de préparation nécessite `imageio-ffmpeg` ; le jeu n'a aucune dépendance
Python ou FFmpeg à l'exécution.

`node tools/test-music.cjs` vérifie la priorité locale, le titre de Liv Morgan,
l'arrêt/reprise, les échecs, les callbacks périmés, les délais de chargement,
les refus d'autoplay et l'absence de l'interface ajoutée précédemment.
`audio-validation.json` consigne le décodage intégral des 86 extraits par FFmpeg,
leur durée et leur niveau moyen. Un fichier cassé passe à l'extrait distant du
même personnage, puis à un autre thème disponible, sans substitution générique.
