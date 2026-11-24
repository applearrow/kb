# Guía de instalación y configuración

Esta guía explica cómo preparar tu entorno paso a paso para editar tu base de conocimiento en **Obsidian** y usar **GitHub Wiki** (`applearrow/kb.wiki.git`) como respaldo y visor web.

---

## Requisitos previos

- **Git** instalado (`git --version`).
- **Obsidian** instalado ([obsidian.md](https://obsidian.md/)). En **macOS** puedes instalarlo directamente con Homebrew:
  ```bash
  brew install --cask obsidian
  ```
- Acceso de escritura al repositorio `https://github.com/applearrow/kb` mediante **HTTPS** (token/GitHub CLI `gh auth login`) o **SSH** (clave configurada en GitHub).

---

## Paso 1: Activar e inicializar la Wiki en GitHub

GitHub **no crea el repositorio `kb.wiki.git`** hasta que exista al menos una página creada desde la interfaz web.

1. Abre `https://github.com/applearrow/kb`.
2. Ve a **Settings → General → Features** y asegúrate de que **Wikis** está activado.
3. Entra en la pestaña **Wiki** del repositorio.
4. Haz clic en **Create the first page**, guarda la página inicial `Home` (con cualquier texto temporal) y pulsa **Save page**.

A partir de este momento ya existe el repositorio Git `https://github.com/applearrow/kb.wiki.git`.

---

## Paso 2: Clonar la Wiki y preparar el vault local

### Método automático (recomendado)

Desde la raíz de este proyecto, ejecuta:

```bash
# Por HTTPS en ~/kb-wiki (por defecto)
./scripts/setup-wiki.sh

# Por SSH en una ruta personalizada, copiando plantillas si faltan
./scripts/setup-wiki.sh --ssh --dir ~/kb-wiki --with-templates
```

Opciones disponibles en `scripts/setup-wiki.sh`:

| Opción | Descripción |
| :--- | :--- |
| `--dir <ruta>` | Ruta local del vault (por defecto `~/kb-wiki`). |
| `--repo <url>` | URL personalizada del repositorio `.wiki.git`. |
| `--ssh` | Usa `git@github.com:applearrow/kb.wiki.git`. |
| `--use-gitignore` | Además de `.git/info/exclude`, escribe las exclusiones en `.gitignore` del vault (útil si clonas la wiki en varios equipos). |
| `--with-templates` | Copia `Home.md`, `_Sidebar.md` y `_Footer.md` desde `templates/wiki/` si no existen. |

### Método manual

Si prefieres hacerlo sin el script:

```bash
git clone https://github.com/applearrow/kb.wiki.git ~/kb-wiki
mkdir -p ~/kb-wiki/images
```

---

## Paso 3: Abrir la carpeta como vault en Obsidian

1. Abre **Obsidian**.
2. Selecciona **Open folder as vault** (Abrir carpeta como bóveda).
3. Elige la carpeta `~/kb-wiki` (o la ruta que hayas indicado en `--dir`).

---

## Paso 4: Los 4 ajustes clave para compatibilidad 100%

Si usaste `scripts/setup-wiki.sh`, los ajustes **1, 2 y 3** ya quedan aplicados automáticamente. Aun así, conviene conocerlos y verificarlos en Obsidian.

### 1. No subir la carpeta `.obsidian/`

Obsidian guarda sus preferencias, tema, estado del workspace y plugins dentro de `.obsidian/`. No debe subirse a GitHub Wiki.

Añade estas líneas en `~/kb-wiki/.git/info/exclude`:

```gitignore
.obsidian/
.trash/
.DS_Store
```

> **`.git/info/exclude` vs `.gitignore`:**
> - **`.git/info/exclude`** (por defecto): mantiene el repositorio de la wiki completamente limpio sin archivos ocultos versionados. Es local a cada clon; si clonas la wiki en otro ordenador, vuelve a ejecutar `setup-wiki.sh` o añade las líneas de nuevo.
> - **`.gitignore`** (`--use-gitignore`): se versiona con la wiki y protege automáticamente todos los equipos donde clones. GitHub Wiki oculta los archivos que empiezan por punto en su índice de páginas.

### 2. Enlaces compatibles en ambos lados

Este es el detalle más importante entre Obsidian y GitHub Wiki:

- Los `[[wikilinks]]` sin alias (`[[Home]]`, `[[Pagina-de-prueba]]`) funcionan en ambos.
- Los `[[wikilinks]]` **con alias van al revés**:
  - **GitHub Wiki** interpreta `[[Texto visible|Pagina-de-prueba]]`.
  - **Obsidian** interpreta `[[Pagina-de-prueba|Texto visible]]`.

**Solución limpia:** usar siempre enlaces Markdown estándar `[Texto visible](Pagina-de-prueba.md)`, que funcionan exactamente igual en Obsidian y en GitHub Wiki.

En Obsidian ve a **Settings → Files and links**:
- **Use `[[Wikilinks]]`:** **DESACTIVADO** (`"useMarkdownLinks": true`).
- **New link format:** **Relative path to file** (`"newLinkFormat": "relative"`).
- **Automatically update internal links:** **ACTIVADO** (`"alwaysUpdateLinks": true`).
- **Default location for new notes:** **Vault folder** (`"newFileLocation": "root"`).

### 3. Imágenes en `images/` con sintaxis Markdown estándar

GitHub Wiki **no entiende** `![[imagen.png]]` de Obsidian, pero sí el Markdown estándar `![alt](images/imagen.png)`.

- Al tener desactivado **Use `[[Wikilinks]]`** (ajuste 2), cuando pegues o arrastres una imagen en Obsidian se insertará automáticamente en formato Markdown estándar `![](images/imagen.png)`.
- En **Settings → Files and links**:
  - **Default location for new attachments:** **In the folder specified below**
  - **Attachment folder path:** `images` (`"attachmentFolderPath": "images"`).

### 4. Sincronización desde la UI de Obsidian (opcional)

Puedes sincronizar usando el terminal (`./scripts/sync-wiki.sh`) o directamente desde dentro de Obsidian con el plugin comunitario **Git** (*Obsidian Git*).

#### Instalar y configurar Obsidian Git

1. En Obsidian ve a **Settings → Community plugins** y activa **Community plugins**.
2. Pulsa **Browse**, busca **Git** (autor: *Vinzent / Denis Olehov*), instálalo y actívalo.
3. Abre **Settings → Git** y aplica esta configuración recomendada:

| Ajuste | Valor recomendado | Motivo |
| :--- | :--- | :--- |
| **Auto commit-and-sync interval (minutes)** | `10` o `15` (o `0` si prefieres manual) | Respaldo periódico automático sin interferir mientras escribes. |
| **Auto pull interval (minutes)** | `10` o `15` | Trae cambios hechos desde la web u otro equipo. |
| **Pull on startup** | **Activado** | Evita editar sobre una versión desactualizada al abrir Obsidian. |
| **Push on commit-and-sync** | **Activado** | Sube el commit automáticamente a GitHub Wiki. |
| **Pull before push** | **Activado** | Reduce conflictos si hubo cambios remotos. |
| **Commit message** | `docs: backup {{date}}` | Historial limpio y legible en Git. |

4. *(Opcional)* Asigna un atajo de teclado en **Settings → Hotkeys** al comando **Git: Commit-and-sync** (por ejemplo `Cmd+Shift+S`) para sincronizar al instante cuando termines una nota.

---

## Verificación rápida tras instalar

1. Crea una página de prueba en Obsidian llamada `Pagina-de-prueba.md`.
2. Añade un enlace desde `Home.md` hacia `Pagina-de-prueba.md` y comprueba que Obsidian genere `[Pagina-de-prueba](Pagina-de-prueba.md)`.
3. Pega una captura de pantalla y comprueba que:
   - El archivo se guarda dentro de `~/kb-wiki/images/`.
   - El enlace insertado tiene el formato `![](images/...)` y **no** `![[...]]`.
4. Ejecuta `git -C ~/kb-wiki status` y comprueba que **no aparece `.obsidian/`** en la lista de archivos sin seguimiento.
5. Sincroniza con `./scripts/sync-wiki.sh` (o desde Obsidian Git) y abre `https://github.com/applearrow/kb/wiki` para verificar que tanto los enlaces como la imagen se ven correctamente.
