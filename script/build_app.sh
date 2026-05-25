#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
#  build_app.sh — Empaqueta CopiaPegaMacOs como .app bundle
#
#  Uso:
#    ./script/build_app.sh            # Build release + empaqueta
#    ./script/build_app.sh --install  # Además copia a /Applications
#    ./script/build_app.sh --run      # Instala y ejecuta la app de /Applications
# ──────────────────────────────────────────────────────────────
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"

APP_NAME="Copia y Pega"
PRODUCT_NAME="CopiaPegaMacOs"
EXECUTABLE_NAME="${APP_NAME}"
IDENTIFIER="com.xaviermena.CopiaPegaMacOs"
SIGN_IDENTITY_NAME="Copia y Pega Local Code Signing"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
P12_PASSWORD="copiaypega-local-signing"

BUILD_DIR="${PROJECT_ROOT}/.build/release"
DIST_DIR="${PROJECT_ROOT}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"

RESOURCES_DIR="${PROJECT_ROOT}/Resources"
INFO_PLIST="${RESOURCES_DIR}/Info.plist"
ENTITLEMENTS="${RESOURCES_DIR}/CopiaPegaMacOs.entitlements"

# ── Colores ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${CYAN}▶${NC} $1"; }
ok()    { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
fail()  { echo -e "${RED}✗${NC} $1"; exit 1; }

has_local_signing_identity() {
    security find-identity -p codesigning -v 2>/dev/null | grep -Fq "\"${SIGN_IDENTITY_NAME}\""
}

create_local_signing_identity() {
    command -v openssl >/dev/null || return 1

    local tmp_dir
    tmp_dir="$(mktemp -d)"

    openssl req -newkey rsa:2048 -nodes -x509 -days 3650 -sha256 \
        -subj "/CN=${SIGN_IDENTITY_NAME}" \
        -addext "keyUsage=critical,digitalSignature" \
        -addext "extendedKeyUsage=critical,codeSigning" \
        -addext "basicConstraints=critical,CA:FALSE" \
        -keyout "${tmp_dir}/key.pem" \
        -out "${tmp_dir}/cert.pem" >/dev/null 2>&1

    openssl pkcs12 -legacy -export \
        -inkey "${tmp_dir}/key.pem" \
        -in "${tmp_dir}/cert.pem" \
        -name "${SIGN_IDENTITY_NAME}" \
        -out "${tmp_dir}/identity.p12" \
        -passout "pass:${P12_PASSWORD}" >/dev/null 2>&1

    security import "${tmp_dir}/identity.p12" \
        -k "${KEYCHAIN}" \
        -P "${P12_PASSWORD}" \
        -T /usr/bin/codesign >/dev/null

    security add-trusted-cert \
        -d \
        -r trustRoot \
        -p codeSign \
        -k "${KEYCHAIN}" \
        "${tmp_dir}/cert.pem" >/dev/null

    rm -rf "${tmp_dir}"
}

ensure_local_signing_identity() {
    if has_local_signing_identity; then
        return 0
    fi

    warn "No se encontró firma local estable; creando certificado local para ${APP_NAME}"
    create_local_signing_identity || return 1
    has_local_signing_identity
}

sign_app() {
    local identity="$1"

    if [[ -f "$ENTITLEMENTS" ]]; then
        codesign --force --deep --sign "${identity}" \
            --entitlements "$ENTITLEMENTS" \
            "${APP_BUNDLE}"
    else
        codesign --force --deep --sign "${identity}" \
            "${APP_BUNDLE}"
    fi
}

# ── 1. Build release ──
log "Compilando en modo release..."
swift build -c release 2>&1 | tail -5
ok "Build completado"

# Verificar que el binario existe
BINARY="${BUILD_DIR}/${PRODUCT_NAME}"
if [[ ! -f "$BINARY" ]]; then
    fail "No se encontró el binario en: ${BINARY}"
fi

# ── 2. Crear estructura .app ──
log "Creando bundle: ${APP_NAME}.app"

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copiar binario
cp "${BINARY}" "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE_NAME}"

# Copiar Info.plist
if [[ -f "$INFO_PLIST" ]]; then
    cp "$INFO_PLIST" "${APP_BUNDLE}/Contents/Info.plist"
    ok "Info.plist copiado"
else
    fail "Info.plist no encontrado en: ${INFO_PLIST}"
fi

# Copiar Icono
APP_ICON="${RESOURCES_DIR}/AppIcon.icns"
if [[ -f "$APP_ICON" ]]; then
    cp "$APP_ICON" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
    ok "AppIcon.icns copiado"
else
    warn "AppIcon.icns no encontrado en: ${APP_ICON}"
fi

# Crear PkgInfo
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

ok "Bundle creado en: ${APP_BUNDLE}"

# ── 3. Code sign ──
log "Firmando la aplicación..."

SIGN_IDENTITY="-"
SIGNING_LABEL="ad-hoc"
if ensure_local_signing_identity; then
    SIGN_IDENTITY="${SIGN_IDENTITY_NAME}"
    SIGNING_LABEL="${SIGN_IDENTITY_NAME}"
else
    warn "No se pudo preparar firma local estable; usando firma ad-hoc"
fi

if ! sign_app "${SIGN_IDENTITY}"; then
    if [[ "${SIGN_IDENTITY}" != "-" ]]; then
        warn "Falló la firma local estable; intentando firma ad-hoc"
        SIGN_IDENTITY="-"
        SIGNING_LABEL="ad-hoc"
        sign_app "${SIGN_IDENTITY}" || fail "No se pudo firmar la aplicación"
    else
        fail "No se pudo firmar la aplicación"
    fi
fi

ok "Aplicación firmada con: ${SIGNING_LABEL}"

# ── 4. Verificar firma ──
log "Verificando firma..."
codesign --verify --deep --strict "${APP_BUNDLE}" 2>&1 && ok "Firma verificada" || warn "La verificación de firma mostró advertencias"

# ── 5. Opciones post-build ──
INSTALL=false
RUN=false

for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=true ;;
        --run)     RUN=true ;;
    esac
done

if $RUN && ! $INSTALL; then
    INSTALL=true
fi

FINAL_BUNDLE="${APP_BUNDLE}"

if $INSTALL; then
    log "Instalando en /Applications..."
    
    # Cerrar la app si está corriendo. La segunda línea limpia ejecuciones
    # antiguas del binario SwiftPM crudo para evitar duplicados en permisos.
    pkill -x "${EXECUTABLE_NAME}" 2>/dev/null || true
    pkill -x "${PRODUCT_NAME}" 2>/dev/null || true
    sleep 0.5
    
    # Copiar a Applications
    rm -rf "/Applications/${APP_NAME}.app"
    cp -R "${APP_BUNDLE}" "/Applications/${APP_NAME}.app"
    FINAL_BUNDLE="/Applications/${APP_NAME}.app"
    ok "Instalada en /Applications/${APP_NAME}.app"

    # No dejar una segunda .app visible en el proyecto: macOS/Spotlight la
    # registra como otra aplicación y duplica entradas de permisos.
    rm -rf "${APP_BUNDLE}"
    ok "Bundle temporal eliminado: ${APP_BUNDLE}"
    
    # Re-registrar Login Item (por si cambió la firma)
    warn "Si tenías 'Iniciar al arrancar' activado, desactívalo y vuelve a activarlo en Ajustes"
fi

if $RUN; then
    log "Abriendo ${APP_NAME}..."
    open "${FINAL_BUNDLE}"
    ok "App iniciada"
fi

# ── Resumen ──
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN} ✓ ${APP_NAME} empaquetada exitosamente${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  📦 Bundle:  ${FINAL_BUNDLE}"
echo -e "  📋 ID:      ${IDENTIFIER}"
echo -e "  🔏 Firma:   ${SIGNING_LABEL}"

BINARY_SIZE=$(du -sh "${FINAL_BUNDLE}/Contents/MacOS/${EXECUTABLE_NAME}" | cut -f1)
echo -e "  💾 Tamaño:  ${BINARY_SIZE}"
echo ""

if ! $INSTALL; then
    echo -e "  ${YELLOW}Para instalar en /Applications:${NC}"
    echo -e "    ./script/build_app.sh --install"
    echo ""
    echo -e "  ${YELLOW}Para instalar y ejecutar desde /Applications:${NC}"
    echo -e "    ./script/build_app.sh --run"
    echo ""
fi
