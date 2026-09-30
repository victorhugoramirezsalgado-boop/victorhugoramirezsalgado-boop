#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

printf '%b\n' "${BLUE}================================================${NC}"
printf '%b\n' "${BLUE}   AUDITORÍA Y ANÁLISIS DE SISTEMAS${NC}"
printf '%s\n\n' '================================================'

PASSED=0
FAILED=0
WARNINGS=0

log_pass() {
    printf '%b\n' "${GREEN}✓ PASS${NC}: $1"
    PASSED=$((PASSED + 1))
}

log_fail() {
    printf '%b\n' "${RED}✗ FAIL${NC}: $1"
    FAILED=$((FAILED + 1))
}

log_warn() {
    printf '%b\n' "${YELLOW}⚠ WARN${NC}: $1"
    WARNINGS=$((WARNINGS + 1))
}

echo -e "${BLUE}[1] Sistema operativo${NC}"
if uname -a >/dev/null 2>&1; then log_pass "SO disponible: $(uname -s)"; else log_fail "No se pudo detectar el SO"; fi
if uptime >/dev/null 2>&1; then log_pass "Sistema activo: $(uptime)"; else log_warn "No se pudo obtener uptime"; fi
if [ -r /proc/loadavg ]; then log_pass "Carga: $(awk '{print $1, $2, $3}' /proc/loadavg)"; fi
echo

echo -e "${BLUE}[2] Memoria${NC}"
if command -v free >/dev/null 2>&1; then
    log_pass "Memoria: $(free -h | awk '/^Mem:/{printf "Total %s | Usado %s | Libre %s", $2, $3, $4}')"
    used_percent=$(free | awk '/^Mem:/{printf "%.0f", $3/$2*100}')
    if [ "$used_percent" -gt 80 ]; then log_warn "Memoria al ${used_percent}% - nivel crítico"; elif [ "$used_percent" -gt 60 ]; then log_warn "Memoria al ${used_percent}% - nivel alto"; else log_pass "Uso de memoria: ${used_percent}%"; fi
else log_warn "Comando free no disponible"; fi
echo

echo -e "${BLUE}[3] Disco${NC}"
if command -v df >/dev/null 2>&1; then
    while read -r usage mount; do
        [ -n "$usage" ] || continue
        if [ "$usage" -gt 80 ]; then log_warn "Disco $mount al ${usage}% - crítico"; elif [ "$usage" -gt 60 ]; then log_warn "Disco $mount al ${usage}% - alto"; else log_pass "Disco $mount al ${usage}%"; fi
    done < <(df -P | awk 'NR>1 && $1 ~ /^\/dev\// {gsub(/%/, "", $5); print $5, $6}')
else log_fail "Comando df no disponible"; fi
echo

echo -e "${BLUE}[4] Procesos${NC}"
if command -v ps >/dev/null 2>&1; then log_pass "Procesos activos: $(ps -e --no-headers | wc -l | tr -d ' ')"; else log_fail "Comando ps no disponible"; fi
echo

echo -e "${BLUE}[5] Red${NC}"
if command -v ping >/dev/null 2>&1 && ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then log_pass 'Conectividad a internet'; else log_warn 'No se pudo confirmar conectividad ICMP'; fi
if command -v ip >/dev/null 2>&1; then log_pass "Interfaces de red detectadas: $(ip -o link show | wc -l | tr -d ' ')"; else log_warn 'Comando ip no disponible'; fi
echo

echo -e "${BLUE}[6] Herramientas${NC}"
for command_name in git ssh python3 pip3; do
    if command -v "$command_name" >/dev/null 2>&1; then log_pass "$command_name disponible"; else log_warn "$command_name no disponible"; fi
done
echo

echo -e "${BLUE}[7] Repositorio Git${NC}"
if [ -d .git ]; then
    log_pass 'Repositorio Git detectado'
    log_pass "Rama: $(git rev-parse --abbrev-ref HEAD)"
    changes=$(git status --short | wc -l | tr -d ' ')
    if [ "$changes" -gt 0 ]; then log_warn "Cambios sin confirmar: $changes"; else log_pass 'Árbol de trabajo limpio'; fi
else log_warn 'No es un repositorio Git'; fi
echo

echo -e "${BLUE}[8] Proyecto Python${NC}"
if [ -f requirements.txt ]; then log_pass 'requirements.txt encontrado'; else log_warn 'requirements.txt no encontrado'; fi
if [ -f manage.py ]; then log_pass 'Proyecto Django detectado'; fi
if [ -f app.py ]; then log_pass 'app.py detectado'; fi
if [ -d tests ] || [ -f pytest.ini ]; then log_pass 'Tests detectados'; else log_warn 'No se detectó carpeta tests ni pytest.ini'; fi
if command -v python3 >/dev/null 2>&1; then
    if python3 -m compileall -q .; then log_pass 'Sintaxis Python válida'; else log_fail 'Hay errores de sintaxis Python'; fi
fi

echo
printf '%b\n' "${BLUE}================================================${NC}"
printf '%b\n' "${BLUE}   RESUMEN DE AUDITORÍA${NC}"
printf '%b\n' "${GREEN}✓ Pasadas: $PASSED${NC}"
printf '%b\n' "${YELLOW}⚠ Advertencias: $WARNINGS${NC}"
printf '%b\n' "${RED}✗ Fallos: $FAILED${NC}"
if [ "$FAILED" -eq 0 ]; then printf '%b\n' "${GREEN}Estado: auditoría completada sin fallos críticos${NC}"; else printf '%b\n' "${RED}Estado: requiere atención${NC}"; exit 1; fi
