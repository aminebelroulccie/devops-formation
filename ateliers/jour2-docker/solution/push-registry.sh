#!/usr/bin/env bash
# Construit, tague et publie l'image Formini Tasks dans le registre Gitea.
# Usage : ./push-registry.sh [version]        (ex. ./push-registry.sh 0.2.0)
# Prérequis : docker login gitea.formini.local:3000 déjà effectué.
set -euo pipefail

REGISTRY="${REGISTRY:-gitea.formini.local:3000}"
ORG="${ORG:-equipe-a}"
IMAGE="${IMAGE:-formini-tasks}"
VERSION="${1:-0.2.0}"
SHA="$(git rev-parse --short HEAD)"
FULL="${REGISTRY}/${ORG}/${IMAGE}"

echo "→ build ${FULL}:${VERSION} (${SHA})"
docker build -t "${FULL}:${VERSION}" -t "${FULL}:${SHA}" .

echo "→ push"
docker push "${FULL}:${VERSION}"
docker push "${FULL}:${SHA}"

echo "✓ publié : ${FULL}:${VERSION} et ${FULL}:${SHA}"
echo "  vérifier : http://${REGISTRY}/${ORG}/-/packages"
