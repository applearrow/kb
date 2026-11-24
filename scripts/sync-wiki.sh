#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${HOME}/kb-wiki"
COMMIT_MSG="docs: sync wiki $(date '+%Y-%m-%d %H:%M')"
PULL_ONLY=false

usage() {
  cat <<EOF
Uso: $(basename "$0") [opciones]

Sincroniza el vault local de Obsidian con el repositorio remoto de GitHub Wiki.

Opciones:
  --dir <ruta>          Directorio local del vault (por defecto: ~/kb-wiki)
  -m, --message <msg>   Mensaje del commit (por defecto: timestamp actual)
  --pull-only           Solo traer cambios remotos (git pull --rebase)
  -h, --help            Mostrar esta ayuda
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      TARGET_DIR="$2"
      shift 2
      ;;
    -m|--message)
      COMMIT_MSG="$2"
      shift 2
      ;;
    --pull-only)
      PULL_ONLY=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: opción desconocida '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "${TARGET_DIR}/.git" ]]; then
  echo "Error: '${TARGET_DIR}' no existe o no es un repositorio Git." >&2
  echo "Ejecuta primero ./scripts/setup-wiki.sh --dir \"${TARGET_DIR}\"" >&2
  exit 1
fi

cd "${TARGET_DIR}"

# Comprobación de seguridad: evitar subir .obsidian/ por accidente
if [[ -n "$(git ls-files .obsidian)" ]]; then
  echo "Error: '.obsidian/' está siendo rastreada por Git." >&2
  echo "Ejecuta: git rm -r --cached .obsidian && git commit -m 'chore: remove .obsidian from tracking'" >&2
  exit 1
fi

if [[ "${PULL_ONLY}" == "true" ]]; then
  echo "==> Actualizando desde remoto (git pull --rebase)..."
  git pull --rebase
  echo "Sincronización de entrada completada."
  exit 0
fi

# Registrar cambios locales antes del rebase para no perder trabajo
if [[ -n "$(git status --porcelain)" ]]; then
  git add -A

  if git diff --cached --name-only | grep -q '^\.obsidian/'; then
    git reset -- .obsidian >/dev/null 2>&1 || true
    echo "Error: se detectaron archivos de '.obsidian/' en stage. Revisa .git/info/exclude." >&2
    exit 1
  fi

  echo "==> Creando commit: ${COMMIT_MSG}"
  git commit -m "${COMMIT_MSG}"
else
  echo "==> No hay cambios locales pendientes de commit."
fi

echo "==> Sincronizando con remoto (git pull --rebase)..."
git pull --rebase

echo "==> Subiendo cambios a GitHub Wiki..."
git push

echo "Sincronización completada correctamente."
