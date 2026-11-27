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
WITH_GIT_PLUGIN=false
OPEN_VAULT=false

# Versión pineada y checksums SHA-256 de Vinzent03/obsidian-git
OBSIDIAN_GIT_VERSION="2.44.0"
OBSIDIAN_GIT_SHA256_MAIN_JS="9551342c59faeae3b9b991227e5cbcf6c3e3bc8ddb8f6576fb54c9603af57d74"
OBSIDIAN_GIT_SHA256_MANIFEST_JSON="5e00a9693bb8d5b8d4f8f16f86192fdff82cb79f862db34615e59d1fe2bcb069"
OBSIDIAN_GIT_SHA256_STYLES_CSS="0cfd2d250ce97b289bc57cd58debceef4aaa8dd69a71ac9a6d6bf9b05362e81d"

usage() {
  cat <<EOF
Uso: $(basename "$0") [opciones]

Clona la GitHub Wiki y la deja preparada como vault de Obsidian 100% compatible.

Opciones:
  --dir <ruta>         Directorio local del vault (por defecto: ~/kb-wiki)
  --repo <url>         URL del repositorio .wiki.git (por defecto: ${DEFAULT_HTTPS_URL})
  --ssh                Usar URL SSH (${DEFAULT_SSH_URL})
  --use-gitignore      Añadir exclusiones también a .gitignore (además de .git/info/exclude)
  --with-templates     Copiar plantillas iniciales (Home.md, _Sidebar.md, _Footer.md) si no existen
  --with-git-plugin    Instalar y preconfigurar el plugin comunitario Obsidian Git
  --open               Abrir el vault en Obsidian al finalizar
  -h, --help           Mostrar esta ayuda
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
    --with-git-plugin)
      WITH_GIT_PLUGIN=true
      shift
      ;;
    --open)
      OPEN_VAULT=true
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

# Normalizar TARGET_DIR a ruta absoluta sin barra final
if command -v python3 >/dev/null 2>&1; then
  TARGET_DIR="$(python3 -c 'import os, sys; print(os.path.abspath(os.path.expanduser(sys.argv[1])))' "${TARGET_DIR}")"
else
  TARGET_DIR="${TARGET_DIR/#\~/${HOME}}"
  TARGET_DIR="${TARGET_DIR%/}"
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

# 3. Preconfigurar Obsidian (.obsidian/app.json), haciendo merge si ya existe
OBSIDIAN_DIR="${TARGET_DIR}/.obsidian"
OBSIDIAN_APP_JSON="${OBSIDIAN_DIR}/app.json"
APP_TEMPLATE="${PROJECT_ROOT}/templates/obsidian/app.json"
APP_JSON_CONFIGURED=false
mkdir -p "${OBSIDIAN_DIR}"

if [[ ! -f "${OBSIDIAN_APP_JSON}" ]]; then
  cp "${APP_TEMPLATE}" "${OBSIDIAN_APP_JSON}"
  APP_JSON_CONFIGURED=true
  echo "==> Configuración inicial de Obsidian creada en ${OBSIDIAN_APP_JSON}"
elif command -v python3 >/dev/null 2>&1; then
  python3 - "${APP_TEMPLATE}" "${OBSIDIAN_APP_JSON}" <<'PY'
import json
import sys

tmpl_path, dst_path = sys.argv[1], sys.argv[2]
with open(tmpl_path, "r", encoding="utf-8") as f:
    required = json.load(f)
try:
    with open(dst_path, "r", encoding="utf-8") as f:
        current = json.load(f)
    if not isinstance(current, dict):
        current = {}
except Exception:
    current = {}

current.update(required)
with open(dst_path, "w", encoding="utf-8") as f:
    json.dump(current, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
  APP_JSON_CONFIGURED=true
  echo "==> Ajustes de compatibilidad aplicados (merge) en ${OBSIDIAN_APP_JSON}"
else
  echo "==> ${OBSIDIAN_APP_JSON} ya existe y 'python3' no está disponible; no se sobrescribe."
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

# 5. Instalar y preconfigurar el plugin comunitario Obsidian Git si se solicita
sha256_file() {
  local file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${file}" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file}" | awk '{print $1}'
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "${file}"
  else
    echo "Error: se necesita 'shasum', 'sha256sum' o 'python3' para verificar SHA-256." >&2
    return 1
  fi
}

GIT_PLUGIN_INSTALLED=false
if [[ "${WITH_GIT_PLUGIN}" == "true" ]]; then
  if ! command -v curl >/dev/null 2>&1; then
    echo "Error: 'curl' es necesario para descargar Obsidian Git." >&2
    exit 1
  fi

  PLUGIN_ID="obsidian-git"
  PLUGIN_DIR="${OBSIDIAN_DIR}/plugins/${PLUGIN_ID}"
  PLUGIN_BASE_URL="https://github.com/Vinzent03/obsidian-git/releases/download/${OBSIDIAN_GIT_VERSION}"
  PLUGIN_DATA_TEMPLATE="${PROJECT_ROOT}/templates/obsidian/obsidian-git-data.json"
  COMMUNITY_PLUGINS_JSON="${OBSIDIAN_DIR}/community-plugins.json"

  echo "==> Instalando plugin comunitario Obsidian Git v${OBSIDIAN_GIT_VERSION} en ${PLUGIN_DIR}..."
  PLUGIN_TMP_DIR="$(mktemp -d)"

  verify_and_stage_asset() {
    local asset="$1"
    local expected_sha="$2"
    local dst="${PLUGIN_TMP_DIR}/${asset}"

    curl -fsSL "${PLUGIN_BASE_URL}/${asset}" -o "${dst}"
    local actual_sha
    actual_sha="$(sha256_file "${dst}")"
    if [[ "${actual_sha}" != "${expected_sha}" ]]; then
      rm -rf "${PLUGIN_TMP_DIR}"
      echo "Error de seguridad: checksum SHA-256 inválido para ${asset} (Obsidian Git v${OBSIDIAN_GIT_VERSION})." >&2
      echo "  Esperado: ${expected_sha}" >&2
      echo "  Obtenido: ${actual_sha}" >&2
      exit 1
    fi
  }

  verify_and_stage_asset "main.js" "${OBSIDIAN_GIT_SHA256_MAIN_JS}"
  verify_and_stage_asset "manifest.json" "${OBSIDIAN_GIT_SHA256_MANIFEST_JSON}"
  verify_and_stage_asset "styles.css" "${OBSIDIAN_GIT_SHA256_STYLES_CSS}"

  mkdir -p "${PLUGIN_DIR}"
  mv "${PLUGIN_TMP_DIR}/main.js" "${PLUGIN_TMP_DIR}/manifest.json" "${PLUGIN_TMP_DIR}/styles.css" "${PLUGIN_DIR}/"
  rm -rf "${PLUGIN_TMP_DIR}"
  echo "    Checksums SHA-256 verificados correctamente para v${OBSIDIAN_GIT_VERSION}"

  if [[ ! -f "${PLUGIN_DIR}/data.json" ]]; then
    cp "${PLUGIN_DATA_TEMPLATE}" "${PLUGIN_DIR}/data.json"
    echo "    Configuración recomendada aplicada en ${PLUGIN_DIR}/data.json"
  elif command -v python3 >/dev/null 2>&1; then
    python3 - "${PLUGIN_DATA_TEMPLATE}" "${PLUGIN_DIR}/data.json" <<'PY'
import json
import sys

tmpl_path, dst_path = sys.argv[1], sys.argv[2]
with open(tmpl_path, "r", encoding="utf-8") as f:
    defaults = json.load(f)
try:
    with open(dst_path, "r", encoding="utf-8") as f:
        current = json.load(f)
    if not isinstance(current, dict):
        current = {}
except Exception:
    current = {}

for key, val in defaults.items():
    current.setdefault(key, val)

with open(dst_path, "w", encoding="utf-8") as f:
    json.dump(current, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
    echo "    Configuración existente preservada (valores faltantes completados en ${PLUGIN_DIR}/data.json)"
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "${COMMUNITY_PLUGINS_JSON}" "${PLUGIN_ID}" <<'PY'
import json
import os
import sys

cfg_path, plugin_id = sys.argv[1], sys.argv[2]
plugins = []
if os.path.isfile(cfg_path):
    try:
        with open(cfg_path, "r", encoding="utf-8") as f:
            loaded = json.load(f)
        if isinstance(loaded, list):
            plugins = loaded
    except Exception:
        plugins = []

if plugin_id not in plugins:
    plugins.append(plugin_id)

with open(cfg_path, "w", encoding="utf-8") as f:
    json.dump(plugins, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
  elif [[ ! -f "${COMMUNITY_PLUGINS_JSON}" ]]; then
    printf '[\n  "%s"\n]\n' "${PLUGIN_ID}" > "${COMMUNITY_PLUGINS_JSON}"
  fi

  GIT_PLUGIN_INSTALLED=true
  echo "    Plugin '${PLUGIN_ID}' instalado y habilitado en ${COMMUNITY_PLUGINS_JSON}"
fi

# 6. Registrar el vault automáticamente en la configuración global de Obsidian
VAULT_REGISTERED=false
OBSIDIAN_RUNNING=false
OBSIDIAN_CONFIG_JSON=""

is_obsidian_running() {
  case "$(uname -s)" in
    Darwin) pgrep -x Obsidian >/dev/null 2>&1 ;;
    Linux)  pgrep -x obsidian >/dev/null 2>&1 ;;
    *)      return 1 ;;
  esac
}

case "$(uname -s)" in
  Darwin) OBSIDIAN_CONFIG_JSON="${HOME}/Library/Application Support/obsidian/obsidian.json" ;;
  Linux)  OBSIDIAN_CONFIG_JSON="${XDG_CONFIG_HOME:-${HOME}/.config}/obsidian/obsidian.json" ;;
esac

if is_obsidian_running; then
  OBSIDIAN_RUNNING=true
fi

if [[ -n "${OBSIDIAN_CONFIG_JSON}" ]] && command -v python3 >/dev/null 2>&1; then
  ALREADY_REGISTERED="$(python3 - "${OBSIDIAN_CONFIG_JSON}" "${TARGET_DIR}" <<'PY'
import json
import os
import sys

cfg_path, vault_path = sys.argv[1], os.path.abspath(sys.argv[2])
if os.path.isfile(cfg_path):
    try:
        with open(cfg_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        for info in data.get("vaults", {}).values():
            if isinstance(info, dict) and os.path.abspath(info.get("path", "")) == vault_path:
                print("yes")
                sys.exit(0)
    except Exception:
        pass
print("no")
PY
)"

  if [[ "${ALREADY_REGISTERED}" == "yes" ]]; then
    VAULT_REGISTERED=true
    echo "==> Vault ya registrado en Obsidian (${OBSIDIAN_CONFIG_JSON})"
  else
    # Si Obsidian está abierto, ignora y sobrescribe obsidian.json; reiniciarlo solo si se pidió --open
    if [[ "${OBSIDIAN_RUNNING}" == "true" && "${OPEN_VAULT}" == "true" && "$(uname -s)" == "Darwin" ]]; then
      echo "==> Obsidian está abierto; cerrándolo para registrar el nuevo vault..."
      osascript -e 'tell application "Obsidian" to quit' >/dev/null 2>&1 || true
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        if ! is_obsidian_running; then
          OBSIDIAN_RUNNING=false
          break
        fi
        sleep 0.5
      done
    fi

    if [[ "${OBSIDIAN_RUNNING}" == "true" ]]; then
      echo "==> Aviso: Obsidian está abierto y no recarga obsidian.json en caliente."
      echo "    Cierra Obsidian y ejecuta el script con --open, o abre '${TARGET_DIR}' desde Obsidian -> Open folder as vault."
    else
      python3 - "${OBSIDIAN_CONFIG_JSON}" "${TARGET_DIR}" "${OPEN_VAULT}" <<'PY'
import json
import os
import secrets
import sys
import time

cfg_path, vault_path, open_flag = sys.argv[1], os.path.abspath(sys.argv[2]), sys.argv[3] == "true"
os.makedirs(os.path.dirname(cfg_path), exist_ok=True)

data = {"vaults": {}}
if os.path.isfile(cfg_path):
    try:
        with open(cfg_path, "r", encoding="utf-8") as f:
            loaded = json.load(f)
        if isinstance(loaded, dict):
            data = loaded
    except Exception:
        data = {"vaults": {}}

vaults = data.setdefault("vaults", {})
vault_id = secrets.token_hex(8)
while vault_id in vaults:
    vault_id = secrets.token_hex(8)

entry = {
    "path": vault_path,
    "ts": int(time.time() * 1000),
}
if open_flag:
    entry["open"] = True

vaults[vault_id] = entry

with open(cfg_path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False)
PY
      VAULT_REGISTERED=true
      echo "==> Vault registrado automáticamente en Obsidian (${OBSIDIAN_CONFIG_JSON})"
    fi
  fi
fi

# 7. Abrir el vault directamente en Obsidian si se solicitó --open y está registrado
if [[ "${OPEN_VAULT}" == "true" && "${VAULT_REGISTERED}" == "true" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    VAULT_REF="$(python3 - "${OBSIDIAN_CONFIG_JSON}" "${TARGET_DIR}" <<'PY'
import json
import os
import sys
import urllib.parse

cfg_path, vault_path = sys.argv[1], os.path.abspath(sys.argv[2])
vault_id = None
if cfg_path and os.path.isfile(cfg_path):
    try:
        with open(cfg_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        for vid, info in data.get("vaults", {}).items():
            if isinstance(info, dict) and os.path.abspath(info.get("path", "")) == vault_path:
                vault_id = vid
                break
    except Exception:
        pass

target = vault_id if vault_id else os.path.basename(vault_path)
print(urllib.parse.quote(target, safe=""))
PY
)"
    OBSIDIAN_URI="obsidian://open?vault=${VAULT_REF}"
    echo "==> Abriendo vault en Obsidian (${OBSIDIAN_URI})..."
    case "$(uname -s)" in
      Darwin) open "${OBSIDIAN_URI}" ;;
      Linux)  xdg-open "${OBSIDIAN_URI}" >/dev/null 2>&1 & ;;
      *)      echo "    Abre manualmente: ${OBSIDIAN_URI}" ;;
    esac
  else
    echo "==> No se pudo generar la URI sin python3; abre Obsidian manualmente."
  fi
fi

# 8. Resumen final (solo los pasos que realmente quedan pendientes)
HAS_JUST=false
if command -v just >/dev/null 2>&1; then
  HAS_JUST=true
fi

echo ""
echo "Listo. Próximos pasos:"
step=1

if [[ "${VAULT_REGISTERED}" != "true" ]]; then
  echo "  ${step}. Abre Obsidian -> \"Open folder as vault\" -> selecciona: ${TARGET_DIR}"
  step=$((step + 1))
elif [[ "${OPEN_VAULT}" != "true" ]]; then
  if [[ "${HAS_JUST}" == "true" ]]; then
    echo "  ${step}. Abre el vault en Obsidian con: just open"
  else
    echo "  ${step}. Abre Obsidian (el vault '${TARGET_DIR}' ya aparece registrado)."
  fi
  step=$((step + 1))
fi

if [[ "${APP_JSON_CONFIGURED}" != "true" ]]; then
  echo "  ${step}. Comprueba en Settings -> Files and links:"
  echo "     - Use [[Wikilinks]]: DESACTIVADO"
  echo "     - New link format: Relative path to file"
  echo "     - Default location for new attachments: In the folder specified below -> images"
  step=$((step + 1))
fi

if [[ "${GIT_PLUGIN_INSTALLED}" == "true" ]]; then
  echo "  ${step}. La primera vez que abras el vault en Obsidian, pulsa \"Trust author and enable plugins\" para activar Obsidian Git."
  step=$((step + 1))
else
  if [[ "${HAS_JUST}" == "true" ]]; then
    echo "  ${step}. (Opcional) Instala y preconfigura Obsidian Git con: just install-git-plugin"
  else
    echo "  ${step}. (Opcional) Instala y preconfigura Obsidian Git con: ./scripts/setup-wiki.sh --dir \"${TARGET_DIR}\" --with-git-plugin"
  fi
  step=$((step + 1))
fi

if [[ "${HAS_JUST}" == "true" ]]; then
  echo "  ${step}. Sincroniza desde terminal en cualquier momento con: just sync"
else
  echo "  ${step}. Sincroniza desde terminal en cualquier momento con: ./scripts/sync-wiki.sh --dir \"${TARGET_DIR}\""
fi
