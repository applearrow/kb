# KB — Wiki local en Obsidian respaldada en GitHub Wiki

Este repositorio contiene la **documentación, scripts y plantillas** para usar la **GitHub Wiki** de [`applearrow/kb`](https://github.com/applearrow/kb) como respaldo versionado y sincronizado de un vault local de **Obsidian**.

## Arquitectura de la solución

En GitHub, la Wiki de un repositorio vive en un **repositorio Git independiente** terminado en `.wiki.git`:

```text
GitHub:
├── applearrow/kb.git         ← Este proyecto (documentación, scripts y plantillas)
└── applearrow/kb.wiki.git    ← Repositorio real de páginas .md de la Wiki
                                      ▲
                                      │ git pull / push (manual o Obsidian Git)
                                      ▼
Local:
└── ~/kb-wiki/                ← Carpeta clonada abierta como Vault en Obsidian
    ├── .git/info/exclude     ← Ignora .obsidian/ para no contaminar la wiki
    ├── .obsidian/            ← Configuración local de Obsidian (no versionada)
    ├── images/               ← Carpeta de imágenes y adjuntos
    ├── Home.md               ← Página principal de la Wiki
    ├── _Sidebar.md           ← Barra lateral de navegación (opcional)
    └── *.md                  ← Tus notas en Markdown estándar
```

## Inicio rápido

> **Requisitos previos:**
> - **Obsidian** instalado (en macOS: `brew install --cask obsidian`).
> - La wiki debe estar activada en `Settings → Features → Wikis` y debes haber creado al menos la primera página (`Home`) desde la pestaña **Wiki** de GitHub para que `kb.wiki.git` exista.

### Opción A — Instalación automática (recomendada)

```bash
./scripts/setup-wiki.sh --with-git-plugin --open
# O usando just:
just install --with-git-plugin --open
```

El script:
1. Clona `https://github.com/applearrow/kb.wiki.git` en `~/kb-wiki` (puedes cambiar la ruta con `--dir` o usar SSH con `--ssh`).
2. Añade `.obsidian/` y archivos del sistema operativo a `.git/info/exclude`.
3. Crea la carpeta `images/`.
4. Genera o actualiza (merge) `.obsidian/app.json` con enlaces Markdown estándar y carpeta de adjuntos `images`.
5. Registra el vault automáticamente en Obsidian (y lo abre directamente si pasas `--open`).
6. Con `--with-git-plugin`, instala y preconfigura el plugin comunitario **Obsidian Git** (solo tendrás que pulsar **"Trust author and enable plugins"** la primera vez que abras el vault).

> Si quieres inicializar además páginas base (`Home.md`, `_Sidebar.md`, `_Footer.md`) cuando aún no existan, añade `--with-templates`:
> ```bash
> ./scripts/setup-wiki.sh --with-templates --with-git-plugin --open
> ```

### Opción B — Instalación manual

```bash
git clone https://github.com/applearrow/kb.wiki.git ~/kb-wiki
```

Y aplica los 4 ajustes detallados en [docs/instalacion.md](docs/instalacion.md).

## Documentación

- **[Guía de instalación y configuración](docs/instalacion.md)** — Activación de la Wiki en GitHub, clonado, los 4 ajustes clave entre Obsidian y GitHub Wiki, y configuración del plugin **Obsidian Git**.
- **[Guía de uso y buenas prácticas](docs/uso-y-buenas-practicas.md)** — Flujo diario, chuleta de compatibilidad Markdown (enlaces, alias, imágenes, carpetas, `_Sidebar.md`, `_Footer.md`) y sincronización.
- **[Solución de problemas](docs/solucion-de-problemas.md)** — Errores frecuentes (`kb.wiki.git` no encontrado, `.obsidian/` rastreada por error, imágenes rotas, conflictos Git y autenticación en macOS).

## Estructura del repositorio

```text
.
├── README.md
├── docs/
│   ├── instalacion.md
│   ├── uso-y-buenas-practicas.md
│   └── solucion-de-problemas.md
├── scripts/
│   ├── setup-wiki.sh          # Clona y deja listo el vault local
│   └── sync-wiki.sh           # Sincronización rápida (commit + pull --rebase + push)
└── templates/
    ├── git-exclude            # Reglas de exclusión para .git/info/exclude
    ├── obsidian/
    │   └── app.json           # Ajustes recomendados de Obsidian
    └── wiki/
        ├── Home.md            # Plantilla de página inicial
        ├── _Sidebar.md        # Plantilla de barra lateral de GitHub Wiki
        └── _Footer.md         # Plantilla de pie de página de GitHub Wiki
```
