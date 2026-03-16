# 🚀 Guía Rápida de Git - OdontoShop

Este documento es una referencia rápida para el manejo de versiones del proyecto.

---

## 🛠️ 1. Configuración Inicial (Solo una vez)
Si Git no reconoce quién eres o es un PC nuevo:
```powershell
# Identidad
git config --global user.name "GikoCode"
git config --global user.email "tu-email@ejemplo.com"

# Ver configuración actual
git config --list

🔗 2. Vincular Carpeta Local a GitHub
Si creas un proyecto desde cero en tu PC y quieres subirlo a un repo vacío:
git init                                     # Inicializa Git en la carpeta
git remote add origin [https://github.com/gikocode/odontoshop.git](https://github.com/gikocode/odontoshop.git) # Conecta al servidor
git branch -M main                           # Renombra la rama a 'main'
git add .                                    # Prepara los archivos
git commit -m "Primer commit"                # Crea la foto inicial
git push -u origin main                      # Sube y vincula por primera vez

🔄 3. Flujo de Trabajo Diario (Loop de Trabajo)
Usa estos comandos cada vez que termines una funcionalidad:
# 1. Ver qué archivos cambiaste
git status

# 2. Seleccionar cambios
git add .                  # Añadir TODO (recomendado para este proyecto)
git add nombre-archivo.go  # Añadir solo uno específico

# 3. Guardar con mensaje (Commit)
git commit -m "feat: login de administrador funcional"

# 4. Enviar a la nube (Push)
git push origin main

4. Ramas (Branches)
Para probar cosas sin romper la versión principal:
git checkout -b nueva-rama    # Crear y saltar a una rama nueva
git checkout main             # Volver a la principal
git merge nueva-rama          # Traer los cambios de 'nueva-rama' a 'main'
git branch -d nueva-rama      # Borrar la rama (cuando ya no sirva)

🆘 5. Botón de Pánico y Limpieza
# ¿Hiciste un commit y olvidaste un archivo?
git add archivo-olvidado
git commit --amend --no-edit

# ¿El .gitignore no funciona? (Limpiar caché)
git rm -r --cached .
git add .
git commit -m "fix: aplicando .gitignore"

# Deshacer cambios locales NO guardados
git checkout -- .

# Ver historial de cambios
git log --oneline --graph --all

Tips para OdontoShop
Antes de programar: Haz un git pull origin main para estar al día.

Antes de un Push: Revisa el git status para no subir node_modules.

Mensajes: Usa prefijos como feat: (nueva función), fix: (error corregido) o docs: (documentación).