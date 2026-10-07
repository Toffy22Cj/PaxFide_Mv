#!/usr/bin/env bash
# CI local de paxfide-mobile (encargo de Carlos, 2026-10-07, §6): mismo criterio que scripts/ci-local.sh del backend.
# Ejecuta `flutter analyze` y `flutter test`, guarda su salida literal en Documentos/evidencia-mobile/ y sale con un
# código distinto de 0 si algo falla. Se niega a correr con cambios sin commit: la evidencia es de un commit concreto.
#
# Uso: scripts/ci-local.sh        (desde cualquier carpeta del repositorio)
set -uo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "ci-local: no es un repositorio git" >&2; exit 2; }
cd "$ROOT"

# 1. Nada sin commit
if [ -n "$(git status --porcelain)" ]; then
    echo "ci-local: hay cambios sin commit; la evidencia tiene que corresponder a un commit. Abortado." >&2
    git status --short >&2
    exit 3
fi

# 2. Flutter disponible
if ! command -v flutter >/dev/null 2>&1; then
    echo "ci-local: no se encuentra 'flutter' en el PATH. Abortado." >&2
    exit 4
fi

COMMIT=$(git rev-parse --short HEAD)
COMMIT_FULL=$(git rev-parse HEAD)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
STAMP=$(date -u +%Y-%m-%dT%H-%M-%SZ)
OUT_DIR="Documentos/evidencia-mobile"
OUT="$OUT_DIR/ci-local-$COMMIT-$STAMP.txt"
ANALYZE_LOG=$(mktemp "${TMPDIR:-/tmp}/ci-local-analyze-XXXXXX.log")
TEST_LOG=$(mktemp "${TMPDIR:-/tmp}/ci-local-test-XXXXXX.log")
mkdir -p "$OUT_DIR"

echo "ci-local: commit $COMMIT ($BRANCH)"

START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
flutter pub get >/dev/null 2>&1
flutter analyze >"$ANALYZE_LOG" 2>&1
ANALYZE_STATUS=$?
flutter test --reporter expanded >"$TEST_LOG" 2>&1
TEST_STATUS=$?
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# La salida de los comandos puede tocar ficheros generados; la evidencia exige el árbol limpio igual que al empezar.
if [ -n "$(git status --porcelain)" ]; then
    echo "ci-local: aviso — la ejecución dejó cambios en el árbol:" >&2
    git status --short >&2
fi

{
    echo "# CI local — scripts/ci-local.sh (paxfide-mobile)"
    echo "commit:   $COMMIT_FULL"
    echo "rama:     $BRANCH"
    echo "inicio:   $START"
    echo "fin:      $END"
    echo "comandos: flutter analyze ; flutter test --reporter expanded"
    echo "salida:   analyze=$ANALYZE_STATUS test=$TEST_STATUS"
    echo
    echo "## Versiones"
    flutter --version 2>&1 | grep -v -i "woah\|root\|superuser\|^ *$\|/$"
    echo
    echo "## flutter analyze (literal)"
    cat "$ANALYZE_LOG"
    echo
    echo "## flutter test (literal)"
    cat "$TEST_LOG"
    echo
    echo "## sha256 de las dos salidas"
    sha256sum "$ANALYZE_LOG" | cut -d' ' -f1 | sed 's/^/analyze: /'
    sha256sum "$TEST_LOG" | cut -d' ' -f1 | sed 's/^/test:    /'
} >"$OUT"

echo "ci-local: evidencia en $OUT"
tail -n 1 "$ANALYZE_LOG"
tail -n 1 "$TEST_LOG"

if [ "$ANALYZE_STATUS" -ne 0 ] || [ "$TEST_STATUS" -ne 0 ]; then
    echo "ci-local: FALLO (analyze=$ANALYZE_STATUS, test=$TEST_STATUS)" >&2
    exit 1
fi
exit 0
