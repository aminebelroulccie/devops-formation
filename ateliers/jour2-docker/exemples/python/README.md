# Exemple Python — FastAPI, venv copié entre étapes

_English version: [`README.en.md`](README.en.md)_

**Ce que montre cet exemple** : le multi-stage appliqué à un langage interprété. Le gain de
taille est modeste (on garde l'interpréteur), mais l'image finale ne contient ni pip, ni
caches, ni outils de compilation : c'est surtout un gain de **propreté et de sécurité**.
Même structure que le `Dockerfile.multistage` du fil rouge Formini Tasks, avec un venv au lieu
de `--prefix`.

```bash
docker build -t formini-hello-python .
docker run --rm -p 8000:8000 formini-hello-python
curl -s localhost:8000/        # {"service":"formini-hello-python","message":"Bonjour Formini",...}
curl -s localhost:8000/health  # {"status":"ok"}
open http://localhost:8000/docs   # documentation interactive générée par FastAPI
docker images formini-hello-python
```

## Points à observer

- Le venv est créé dans l'étape de build et copié tel quel : `PATH="/venv/bin:$PATH"` suffit
  pour que `uvicorn` et `python` pointent dessus.
- `PIP_NO_CACHE_DIR=1` évite d'embarquer le cache pip dans la couche.
- `--workers 2` : uvicorn gère plusieurs processus, comme gunicorn dans le fil rouge.
- Comparez avec une image mono-étape `FROM python:3.12` (non slim) : `docker images` montre
  ≈ 1 Go contre ≈ 150 Mo, et `trivy image` plusieurs dizaines de CVE en plus.

## Exercice

Ajoutez une dépendance lourde (`pandas==2.2.3`) dans `requirements.txt`, reconstruisez et
observez quelle couche est reconstruite et combien l'image grossit. Puis retirez-la : le cache
de la couche précédente est-il retrouvé ?
