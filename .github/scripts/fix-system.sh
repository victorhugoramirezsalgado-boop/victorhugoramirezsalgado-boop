#!/usr/bin/env bash
set -euo pipefail

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   AUDITORÍA Y ANÁLISIS DE SISTEMAS${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Variables de estado
PASSED=0
FAILED=0
WARNINGS=0

# Función para registrar resultados
log_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASSED++))
}

log_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAILED++))
}

log_warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
    ((WARNINGS++))
}

# ========== 1. AUDITORÍA DEL SISTEMA OPERATIVO ==========
echo -e "${BLUE}[1] Auditoría del Sistema Operativo${NC}"
echo "---"

if uname -a &>/dev/null; then
    log_pass "SO disponible: $(uname -s)"
else
    log_fail "No se pudo detectar el SO"
fi

# Revisar uptime
if uptime &>/dev/null; then
    UPTIME=$(uptime)
    log_pass "Sistema activo: $UPTIME"
else
    log_warn "No se pudo obtener uptime"
fi

# Revisar carga del sistema
if [ -f /proc/loadavg ]; then
    LOAD=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    log_pass "Carga del sistema (1m, 5m, 15m): $LOAD"
fi

echo ""

# ========== 2. AUDITORÍA DE MEMORIA ==========
echo -e "${BLUE}[2] Auditoría de Memoria${NC}"
echo "---"

if command -v free &>/dev/null; then
    MEMORY=$(free -h | grep "Mem:" | awk '{printf "Total: %s | Usado: %s | Libre: %s", $2, $3, $4}')
    log_pass "Memoria: $MEMORY"
    
    # Advertencia si memoria está muy llena
    USED_PERCENT=$(free | grep "Mem:" | awk '{printf("%.0f", $3/$2 * 100)}')
    if [ "$USED_PERCENT" -gt 80 ]; then
        log_warn "Memoria al ${USED_PERCENT}% - Nivel crítico"
    elif [ "$USED_PERCENT" -gt 60 ]; then
        log_warn "Memoria al ${USED_PERCENT}% - Nivel alto"
    else
        log_pass "Uso de memoria: ${USED_PERCENT}% - Óptimo"
    fi
else
    log_fail "Comando 'free' no disponible"
fi

echo ""

# ========== 3. AUDITORÍA DE DISCO ==========
echo -e "${BLUE}[3] Auditoría de Disco${NC}"
echo "---"

if command -v df &>/dev/null; then
    echo "Espacio en disco:"
    df -h | grep -E "^/dev/" | while read line; do
        USAGE=$(echo $line | awk '{print $5}' | sed 's/%//')
        MOUNT=$(echo $line | awk '{print $6}')
        if [ "$USAGE" -gt 80 ]; then
            log_warn "Disco $MOUNT al ${USAGE}% - Crítico"
        elif [ "$USAGE" -gt 60 ]; then
            log_warn "Disco $MOUNT al ${USAGE}% - Alto"
        else
            echo "  ✓ $MOUNT: ${USAGE}%"
        fi
    done
else
    log_fail "Comando 'df' no disponible"
fi

echo ""

# ========== 4. AUDITORÍA DE PROCESOS ==========
echo -e "${BLUE}[4] Auditoría de Procesos Activos${NC}"
echo "---"

if command -v ps &>/dev/null; then
    TOTAL_PROC=$(ps aux | wc -l)
    log_pass "Total de procesos activos: $TOTAL_PROC"
    
    # Top 5 procesos por CPU
    echo "Top 5 procesos por uso de CPU:"
    ps aux --sort=-%cpu | head -6 | tail -5 | awk '{printf "  %s: %.1f%%\n", $11, $3}'
    
    echo ""
    # Top 5 procesos por memoria
    echo "Top 5 procesos por uso de memoria:"
    ps aux --sort=-%mem | head -6 | tail -5 | awk '{printf "  %s: %.1f%%\n", $11, $4}'
else
    log_fail "Comando 'ps' no disponible"
fi

echo ""

# ========== 5. AUDITORÍA DE RED ==========
echo -e "${BLUE}[5] Auditoría de Red${NC}"
echo "---"

# Verificar conectividad
if ping -c 1 8.8.8.8 &>/dev/null; then
    log_pass "Conectividad a internet: OK"
else
    log_fail "Sin conectividad a internet"
fi

# Interfaces de red
if command -v ip &>/dev/null; then
    log_pass "Interfaces de red activas:"
    ip link show | grep -E "^[0-9]+:" | grep "UP" | awk -F: '{print "  - " $2}' || log_warn "No hay interfaces activas"
else
    log_warn "Comando 'ip' no disponible"
fi

echo ""

# ========== 6. AUDITORÍA DE SERVICIOS CRÍTICOS ==========
echo -e "${BLUE}[6] Auditoría de Servicios Críticos${NC}"
echo "---"

# SSH
if command -v ssh &>/dev/null; then
    log_pass "SSH disponible"
else
    log_warn "SSH no disponible"
fi

# Git
if command -v git &>/dev/null; then
    GIT_VERSION=$(git --version)
    log_pass "$GIT_VERSION"
else
    log_warn "Git no disponible"
fi

# Node.js (si existe)
if command -v node &>/dev/null; then
    NODE_VERSION=$(node --version)
    log_pass "Node.js $NODE_VERSION"
fi

# Python (si existe)
if command -v python3 &>/dev/null; then
    PYTHON_VERSION=$(python3 --version)
    log_pass "$PYTHON_VERSION"
fi

echo ""

# ========== 7. AUDITORÍA DEL REPOSITORIO GIT ==========
echo -e "${BLUE}[7] Auditoría del Repositorio GIT${NC}"
echo "---"

if [ -d ".git" ]; then
    log_pass "Repositorio Git detectado"
    
    # Estado del repo
    if git status &>/dev/null; then
        BRANCH=$(git rev-parse --abbrev-ref HEAD)
        log_pass "Rama actual: $BRANCH"
        
        # Cambios sin confirmar
        CHANGES=$(git status --short | wc -l)
        if [ "$CHANGES" -gt 0 ]; then
            log_warn "Cambios sin confirmar: $CHANGES archivos"
        else
            log_pass "Estado limpio: sin cambios sin confirmar"
        fi
        
        # Último commit
        LAST_COMMIT=$(git log -1 --pretty=format:"%h - %s (%ar)" 2>/dev/null)
        log_pass "Último commit: $LAST_COMMIT"
    fi
else
    log_warn "No es un repositorio Git"
fi

echo ""

# ========== 8. AUDITORÍA DE PERMISOS ==========
echo -e "${BLUE}[8] Auditoría de Permisos${NC}"
echo "---"

# Verificar permisos del directorio actual
if [ -w "." ]; then
    log_pass "Permisos de escritura en directorio actual: OK"
else
    log_fail "Sin permisos de escritura en directorio actual"
fi

# Usuario actual
CURRENT_USER=$(whoami)
log_pass "Usuario actual: $CURRENT_USER"

echo ""

# ========== 9. AUDITORÍA DE DEPENDENCIAS DEL PROYECTO ==========
echo -e "${BLUE}[9] Auditoría de Dependencias del Proyecto${NC}"
echo "---"

# Node.js project
if [ -f "package.json" ]; then
    log_pass "Proyecto Node.js detectado"
    
    if command -v npm &>/dev/null; then
        NPM_VERSION=$(npm --version)
        log_pass "npm versión: $NPM_VERSION"
        
        # Verificar si node_modules existe
        if [ -d "node_modules" ]; then
            MODULES=$(find node_modules -maxdepth 1 -type d | wc -l)
            log_pass "Módulos npm instalados: $((MODULES-1))"
        else
            log_warn "node_modules no instalado - ejecutar 'npm install'"
        fi
    fi
fi

# Python project
if [ -f "requirements.txt" ]; then
    log_pass "Proyecto Python detectado"
    
    if command -v pip &>/dev/null; then
        PIP_VERSION=$(pip --version)
        log_pass "$PIP_VERSION"
        
        # Verificar si venv existe
        if [ -d "venv" ] || [ -d ".venv" ]; then
            log_pass "Entorno virtual detectado"
        else
            log_warn "Entorno virtual no encontrado - se recomienda crear uno"
        fi
    fi
fi

# Docker
if command -v docker &>/dev/null; then
    DOCKER_VERSION=$(docker --version)
    log_pass "$DOCKER_VERSION"
    
    RUNNING_CONTAINERS=$(docker ps -q | wc -l)
    log_pass "Contenedores ejecutándose: $RUNNING_CONTAINERS"
fi

echo ""

# ========== 10. RESUMEN FINAL ==========
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   RESUMEN DE AUDITORÍA${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}✓ Pasadas: $PASSED${NC}"
echo -e "${YELLOW}⚠ Advertencias: $WARNINGS${NC}"
echo -e "${RED}✗ Fallos: $FAILED${NC}"

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}Estado general: SISTEMA OPERATIVO CORRECTAMENTE${NC}"
    exit 0
else
    echo -e "${RED}Estado general: REQUIERE ATENCIÓN${NC}"
    exit 1
fi
