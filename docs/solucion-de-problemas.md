# Solución de problemas

Recopilación de los incidentes más comunes al usar Obsidian con GitHub Wiki y cómo resolverlos.

---

## 1. Error `Repository not found` al clonar `kb.wiki.git`

**Síntoma:**
```text
fatal: repository 'https://github.com/applearrow/kb.wiki.git/' not found
```

**Causas y solución:**
1. **La Wiki no está inicializada todavía:** aunque hayas activado Wikis en Settings, GitHub no crea el repositorio `.wiki.git` hasta que creas la primera página desde la web.
   - Ve a `https://github.com/applearrow/kb/wiki` → **Create the first page** → **Save page**.
2. **Permisos / autenticación:** si el repositorio `applearrow/kb` es privado, necesitas estar autenticado con una cuenta que tenga acceso:
   - Con GitHub CLI: `gh auth login` y `gh auth setup-git`.
   - O con SSH: usa `./scripts/setup-wiki.sh --ssh` tras configurar tu clave SSH en GitHub.

---

## 2. Se subió la carpeta `.obsidian/` a GitHub Wiki por accidente

**Síntoma:** aparecen archivos de `.obsidian/` en `git status` o en el historial del repositorio remoto.

**Solución:**
1. Asegúrate de que `.obsidian/` está en `.git/info/exclude` (o `.gitignore`).
2. Quítala del índice de Git **sin borrarla de tu disco** (`--cached`):
   ```bash
   cd ~/kb-wiki
   git rm -r --cached .obsidian
   git commit -m "chore: dejar de versionar .obsidian"
   git push
   ```

---

## 3. Las imágenes se ven en Obsidian pero aparecen rotas en GitHub Wiki

**Causas más frecuentes:**
- **Sintaxis de wikilink:** estás usando `![[captura.png]]`. Cámbialo a Markdown estándar: `![captura](images/captura.png)`.
- **Ajuste activo en Obsidian:** revisa **Settings → Files and links → Use `[[Wikilinks]]`** y asegúrate de que está **desactivado**.
- **Espacios en el nombre de la imagen:** si una imagen se llama `Captura de pantalla 2026.png`, el enlace Markdown debe codificar espacios (`%20`) o, mejor aún, renombra el archivo con guiones (`captura-2026.png`).
- **Imagen no subida a Git:** ejecuta `git -C ~/kb-wiki status` y comprueba que el archivo dentro de `images/` se añadió al commit y se hizo `push`.

---

## 4. Los enlaces con alias llevan a una página inexistente en GitHub Wiki

**Síntoma:** un enlace como `[[Mi-pagina|Texto bonito]]` funciona en Obsidian pero en GitHub Wiki intenta abrir la página `Texto bonito`.

**Solución:**
GitHub Wiki y Obsidian invierten el orden de los wikilinks con alias. Reemplázalo por Markdown estándar:

```markdown
[Texto bonito](Mi-pagina.md)
```

Y mantén desactivada la opción **Use `[[Wikilinks]]`** en Obsidian.

---

## 5. El plugin Obsidian Git falla al autenticar o no encuentra `git` (macOS)

**Síntoma:** `git push` funciona en la terminal, pero desde el plugin **Git** dentro de Obsidian falla con `git not found`, `Authentication failed` o `Permission denied (publickey)`.

**Soluciones en macOS:**
1. **Ruta del binario `git`:** las apps GUI en macOS a veces no cargan el `PATH` de Homebrew.
   - Obtén la ruta en terminal con `which git` (normalmente `/usr/bin/git` o `/opt/homebrew/bin/git`).
   - En Obsidian ve a **Settings → Git → Advanced → Custom Git binary path** y pega esa ruta.
2. **Autenticación HTTPS:** configura el helper de credenciales para que macOS Keychain (o `gh`) responda sin pedir contraseña interactiva:
   ```bash
   gh auth setup-git
   ```
   O verifica `git config --global credential.helper` (en macOS suele ser `osxkeychain`).
3. **Autenticación SSH con passphrase:** añade la clave al Keychain de macOS y en `~/.ssh/config`:
   ```sshconfig
   Host github.com
     AddKeysToAgent yes
     UseKeychain yes
     IdentityFile ~/.ssh/id_ed25519
   ```
   Y ejecuta una vez:
   ```bash
   ssh-add --apple-use-keychain ~/.ssh/id_ed25519
   ```

---

## 6. Conflictos de fusión (`merge` / `rebase conflict`)

**Síntoma:** editaste la misma nota en la web de GitHub y en Obsidian antes de sincronizar, y `git pull --rebase` se detiene avisando de un conflicto.

**Solución:**
1. Revisa qué archivos están en conflicto:
   ```bash
   cd ~/kb-wiki
   git status
   ```
2. Abre los archivos marcados (puedes abrirlos en el editor o en el propio Obsidian) y resuelve las marcas `<<<<<<<`, `=======`, `>>>>>>>`.
3. Marca como resuelto y continúa el rebase:
   ```bash
   git add <archivo-resuelto.md>
   git rebase --continue
   git push
   ```
4. Si prefieres cancelar el rebase para revisar con calma:
   ```bash
   git rebase --abort
   ```
