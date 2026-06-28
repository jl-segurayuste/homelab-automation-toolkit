#!/usr/bin/env bash
# Escaneo completo del repo (no solo lo staged). Uso recomendado antes de hacer
# publico el repositorio. Revisa: iconos/emojis en scripts, secretos y terminos
# de la lista negra en TODOS los archivos versionados.
#   Uso: scripts/security/scan-repo.sh
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
BLACKLIST="scripts/security/blacklist.local.txt"
RC=0

ICON_RANGE='[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}\x{FE00}-\x{FE0F}\x{200D}\x{2190}-\x{21FF}\x{2300}-\x{23FF}\x{2460}-\x{24FF}]'

echo "== 1. Iconos/emojis en scripts =="
SCRIPTS=$(git ls-files '*.sh' '*.bash' '*.py' '*.pl' '*.rb' '*.js' '*.ts' '*.ps1' '*.lua' '*.php' '*.yaml' '*.yml' '*.j2' 2>/dev/null || true)
for f in $SCRIPTS; do
  if grep -nP "$ICON_RANGE" "$f" >/dev/null 2>&1; then
    echo "  [ICONO] $f"; grep -nP "$ICON_RANGE" "$f" | sed 's/^/        /'; RC=1
  fi
done
[ "$RC" -eq 0 ] && echo "  OK"

echo "== 2. Patrones de secretos =="
EXCLUDE='\{\{|\}\}|<[A-Za-z_]|vault_|default\(|omit|changeme|change_?me|example|ejemplo|placeholder|tu_|TU_|\$\{?[A-Za-z_]|lookup\('
git grep -nEi 'glpat-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|(password|secret|api[_-]?key|token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{6,}' -- . ':(exclude)scripts/security/*' 2>/dev/null | grep -vEi "$EXCLUDE" >/tmp/_sec || true
if [ -s /tmp/_sec ]; then cat /tmp/_sec | sed 's/^/  /'; RC=1; else echo "  OK"; fi

echo "== 3. Terminos prohibidos (lista negra) =="
if [ -f "$BLACKLIST" ]; then
  while IFS= read -r term; do
    [[ -z "$term" || "$term" =~ ^# ]] && continue
    if git grep -nwiE "$term" -- . ':(exclude)scripts/security/blacklist.*' >/dev/null 2>&1; then
      echo "  [PROHIBIDO] $term:"; git grep -nwiE "$term" -- . ':(exclude)scripts/security/blacklist.*' | sed 's/^/        /'; RC=1
    fi
  done < "$BLACKLIST"
fi
[ "$RC" -eq 0 ] && echo "  OK"

echo ""
[ "$RC" -eq 0 ] && echo "RESULTADO: limpio, apto para publicar." || echo "RESULTADO: hay hallazgos, NO publicar hasta resolverlos."
exit $RC
