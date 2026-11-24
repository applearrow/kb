#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEFAULT_HTTPS_URL="https://github.com/applearrow/kb.wiki.git"
DEFAULT_SSH_URL="git@github.com:applearrow/kb.wiki.git"
WIKI_URL="${DEFAULT_HTTPS_URL}"
TARGET_DIR="${HOME}/kb-wiki"
USE_GITIGNORE=false
WITH_TEMPLATES=false

usage() {
  cat <<EOF
Uso: $(basename "$0") [opciones]

Clona la GitHub Wiki y la deja preparada como vault de Obsidian 100% compatible.

Opciones:
  --dir <ruta>       Directorio local del vault (por defecto: ~/kb-wiki)
  --repo <url>       URL del repositorio .wiki.git (por defecto: ${DEFAULT_HTTPS_URL})
  --ssh              Usar URL SSH (${DEFAULT_SSH_URL})
  --use-gitignore    Añadir exclusiones también a .gitignore (además de .git/info/exclude)
  --with-templates   Copiar plantillas iniciales (Home.md, _Sidebar.md, _Footer.md) si no existen
  -h, --help         Mostrar esta ayuda
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      TARGET_DIR="$2"
      shift 2
      ;;
    --repo)
      WIKI_URL="$2"
      shift 2
      ;;
    --ssh)
      WIKI_URL="${DEFAULT_SSH_URL}"
      shift
      ;;
    --use-gitignore)
      USE_GITIGNORE=true
      shift
      ;;
    --with-templates)
      WITH_TEMPLATES=true
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

if ! command -v git >/dev/null 2>&1; then
  echo "Error: 'git' no está instalado o no está en el PATH." >&2
  exit 1
fi

echo "==> Preparando vault local en: ${TARGET_DIR}"

if [[ -d "${TARGET_DIR}" ]]; then
  if [[ -d "${TARGET_DIR}/.git" ]]; then
    echo "    El directorio ya es un repositorio Git. Se omite el clonado y se aplican los ajustes."
  else
    echo "Error: '${TARGET_DIR}' ya existe y no es un repositorio Git." >&2
    echo "Elige otra ruta con --dir o vacía/elimina esa carpeta." >&2
    exit 1
  fi
else
  echo "==> Clonando ${WIKI_URL}..."
  if ! git clone "${WIKI_URL}" "${TARGET_DIR}"; then
    cat >&2 <<EOF

Error al clonar la wiki. Causas habituales:
  1. La wiki aún no está inicializada en GitHub.
     Abre https://github.com/applearrow/kb/wiki y crea al menos la primera página ("Home").
  2. Problema de autenticación Git (HTTPS/SSH).
     Consulta docs/instalacion.md y docs/solucion-de-problemas.md.
EOF
    exit 1
  fi
fi

# 1. Configurar exclusiones locales (.git/info/exclude y opcionalmente .gitignore)
append_unique_lines() {
  local src_file="$1"
  local dst_file="$2"
  mkdir -p "$(dirname "${dst_file}")"
  touch "${dst_file}"
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ -z "${line}" ]] && continue
    if ! grep -Fxq "${line}" "${dst_file}"; then
      printf '%s\n' "${line}" >> "${dst_file}"
    fi
  done < "${src_file}"
}

EXCLUDE_TEMPLATE="${PROJECT_ROOT}/templates/git-exclude"
EXCLUDE_FILE="${TARGET_DIR}/.git/info/exclude"

echo "==> Configurando exclusión de .obsidian/ en ${EXCLUDE_FILE}"
append_unique_lines "${EXCLUDE_TEMPLATE}" "${EXCLUDE_FILE}"

if [[ "${USE_GITIGNORE}" == "true" ]]; then
  echo "==> Configurando exclusión también en ${TARGET_DIR}/.gitignore"
  append_unique_lines "${EXCLUDE_TEMPLATE}" "${TARGET_DIR}/.gitignore"
fi

# 2. Crear carpeta de imágenes recomendada
mkdir -p "${TARGET_DIR}/images"
echo "==> Carpeta de imágenes asegurada: ${TARGET_DIR}/images"

# 3. Preconfigurar Obsidian (.obsidian/app.json) si no existe aún
OBSIDIAN_DIR="${TARGET_DIR}/.obsidian"
OBSIDIAN_APP_JSON="${OBSIDIAN_DIR}/app.json"
mkdir -p "${OBSIDIAN_DIR}"

if [[ ! -f "${OBSIDIAN_APP_JSON}" ]]; then
  cp "${PROJECT_ROOT}/templates/obsidian/app.json" "${OBSIDIAN_APP_JSON}"
  echo "==> Configuración inicial de Obsidian creada en ${OBSIDIAN_APP_JSON}"
else
  echo "==> ${OBSIDIAN_APP_JSON} ya existe; no se sobrescribe."
  echo "    Verifica manualmente que tenga useMarkdownLinks=true y attachmentFolderPath=images."
fi

# 4. Copiar plantillas opcionales de wiki si se solicita
if [[ "${WITH_TEMPLATES}" == "true" ]]; then
  echo "==> Copiando plantillas iniciales de wiki (sin sobrescribir existentes)..."
  for tmpl in "${PROJECT_ROOT}/templates/wiki/"*.md; do
    base="$(basename "${tmpl}")"
    if [[ ! -f "${TARGET_DIR}/${base}" ]]; then
      cp "${tmpl}" "${TARGET_DIR}/${base}"
      echo "    Creado: ${base}"
    else
      echo "    Omitido (ya existe): ${base}"
    fi
  done
fi

cat <<EOF

Listo. Próximos pasos:
  1. Abre Obsidian -> "Open folder as vault" -> selecciona: ${TARGET_DIR}
  2. Comprueba en Settings -> Files and links:
     - Use [[Wikilinks]]: DESACTIVADO
     - New link format: Relative path to file
     - Default location for new attachments: In the folder specified below -> images
  3. (Opcional) Instala el plugin comunitario "Git" (Obsidian Git) para sincronizar desde Obsidian.
  4. O sincroniza desde terminal con:
     ./scripts/sync-wiki.sh --dir "${TARGET_DIR}"
EOF
