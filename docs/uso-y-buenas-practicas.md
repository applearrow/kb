# Guía de uso y buenas prácticas

Esta guía resume el flujo de trabajo diario y las convenciones para que todo lo que escribas en Obsidian se renderice correctamente en GitHub Wiki.

---

## Flujo de trabajo diario

### Opción 1: Desde Obsidian (con plugin Obsidian Git)

1. Abre el vault `~/kb-wiki` (si activaste **Pull on startup**, traerá los últimos cambios automáticamente).
2. Edita o crea tus notas en Markdown.
3. Usa el atajo o comando **Git: Commit-and-sync** (o deja que actúe el intervalo automático).

### Opción 2: Desde terminal (con `sync-wiki.sh` o `git`)

Con el script incluido en este proyecto:

```bash
# Sincronizar cambios (commit + pull --rebase + push)
./scripts/sync-wiki.sh

# Con mensaje de commit personalizado
./scripts/sync-wiki.sh -m "docs: añadir guía de Docker"

# Solo bajar cambios remotos sin subir nada
./scripts/sync-wiki.sh --pull-only
```

O manualmente con Git:

```bash
cd ~/kb-wiki
git status
git add -A
git commit -m "docs: actualizar notas"
git pull --rebase
git push
```

> **Consejo:** antes de empezar una sesión de edición larga (especialmente si editaste algo desde la interfaz web de GitHub o desde otro equipo), haz siempre `pull` primero para evitar conflictos.

---

## Chuleta de compatibilidad: Obsidian ↔ GitHub Wiki

| Elemento | Recomendado (funciona en ambos) | Evitar |
| :--- | :--- | :--- |
| **Enlace simple** | `[Mi página](Mi-pagina.md)` (o `[[Mi-pagina]]`) | Rutas absolutas del equipo |
| **Enlace con alias** | `[Ver guía rápida](Guia-rapida.md)` | `[[Guia-rapida\|Ver guía rápida]]` (GitHub invierte texto y destino) |
| **Enlace a sección** | `[Instalación](Guia-rapida.md#instalacion)` | `[[Guia-rapida#Instalación\|...]]` |
| **Imagen** | `![Diagrama](images/diagrama.png)` | `![[diagrama.png]]` (no renderiza en GitHub Wiki) |
| **Nombres de archivo** | `Guia-de-docker.md` (guiones, sin tildes ni espacios) | `Guía de docker.md` (espacios codificados como `%20` vs `-` en URLs de GitHub) |
| **Callouts / alertas** | Alertas GFM (`> [!NOTE]`, `> [!TIP]`, `> [!WARNING]`) | Callouts propietarios de plugins externos |
| **Diagramas** | Bloques ```` ```mermaid ```` | Plugins de diagramas exclusivos de Obsidian |

### Ejemplo de alertas compatibles en ambos

Tanto Obsidian como GitHub renderizan los bloques de alerta estándar:

```markdown
> [!NOTE]
> Nota informativa visible en Obsidian y en GitHub Wiki.

> [!TIP]
> Consejo práctico.

> [!WARNING]
> Aviso importante.
```

---

## Organización de carpetas y nombres de páginas

GitHub Wiki tiene una particularidad importante con las subcarpetas:

- **Estructura plana (recomendada):** guarda todas las páginas `.md` en la raíz del vault (`~/kb-wiki/`) y las imágenes en `~/kb-wiki/images/`. Así, todos los nombres de página son únicos y fáciles de enlazar tanto en Obsidian como en la barra lateral de GitHub Wiki.
- **Si usas subcarpetas:**
  1. Evita anidar muchos niveles (máximo 1 nivel, por ejemplo `linux/comandos.md`).
  2. Usa siempre **rutas relativas explícitas** en los enlaces: `[Comandos](linux/comandos.md)` o `[Inicio](../Home.md)`.
  3. **No repitas nombres de archivo** entre carpetas distintas (por ejemplo `aws/notas.md` y `gcp/notas.md`), ya que GitHub Wiki indexa las páginas de forma plana por nombre y puede producir colisiones en sus URLs.
- **Imágenes:** guárdalas todas en `images/` (o subcarpetas dentro de `images/` como `images/docker/arq.png`) usando rutas relativas desde la nota actual.

---

## Páginas especiales de GitHub Wiki

GitHub Wiki reconoce automáticamente estos archivos especiales en la raíz del repositorio:

| Archivo | Función en GitHub Wiki | En Obsidian |
| :--- | :--- | :--- |
| `Home.md` | Página principal al abrir la pestaña Wiki. | Nota normal (útil como índice / MOC). |
| `_Sidebar.md` | Sustituye el índice automático lateral por tu menú personalizado. | Nota normal (editable como cualquier `.md`). |
| `_Footer.md` | Pie de página mostrado al final de todas las páginas. | Nota normal. |

En `templates/wiki/` tienes plantillas listas para los tres archivos.

---

## Limpieza de imágenes huérfanas

Si eliminas una imagen de una nota en Obsidian, el archivo sigue existiendo dentro de `images/`. De vez en cuando puedes revisar imágenes no referenciadas o usar el plugin comunitario **Clear Unused Images** en Obsidian para mantener el repositorio ligero.

> Recuerda que GitHub Wiki es un repositorio Git: evita subir vídeos, binarios grandes o capturas sin comprimir para no inflar el historial.
