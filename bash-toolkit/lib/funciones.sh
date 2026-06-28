#!/usr/bin/env bash
# =============================================================================
# Funciones comunes (log, Nagios, conectividad TCP) — version robusta
# =============================================================================
# Incluye:
# - log(): niveles y creacion automatica de directorio de logs
# - nagiosFormat(): salida estandar para Nagios/Icinga + logging
# - statusToText(): mapea codigos a texto
# - check_tcp(): prueba TCP a un host/puerto con nc y timeout configurable
# - Constantes y valores por defecto seguros
#
# Carga: source "/ruta/funciones.sh"
# =============================================================================

set -Eeuo pipefail

# ---------- Constantes Nagios ----------
# Si ya existen en tu script principal, no se sobreescribiran
: "${OK:=0}"; : "${WARNING:=1}"; : "${CRITICAL:=2}"; : "${UNKNOWN:=3}"

# ---------- Parametros por defecto ----------
: "${SCRIPT_LOG:=/var/log/miscripts/$(basename "$0" .sh).log}"
: "${DEBUG:=0}"               # 1 para mostrar DEBUG por pantalla
: "${COLOR:=1}"               # 1 colores, 0 sin colores
: "${CONNECTION_TIMEOUT:=5}"  # segundos

# Crea el directorio del log si no existe
_log_init_dir() {
	local dir
	dir=$(dirname -- "$SCRIPT_LOG")
	[ -d "$dir" ] || mkdir -p "$dir"
}

# ---------- Colores (opcionales) ----------
_color() {
	local code="$1"; shift
	if [ "$COLOR" -eq 1 ] && [ -t 1 ]; then
		printf "\e[%sm%s\e[0m" "$code" "$*"
	else
		printf "%s" "$*"
	fi
}

# ---------- Logging ----------
log() {
	# Uso: log NIVEL MENSAJE...
	# Niveles: ERROR WARNING SUCCESS INFO DEBUG
	local level="$1"; shift
	local message="$*"
	local ts
	ts=$(date "+%F %T")
	_log_init_dir
	echo "[$ts] [$level] $message" >> "$SCRIPT_LOG"
	case "$level" in
		ERROR) _color 31 "[$level] $message";;
		WARNING) _color 33 "[$level] $message";;
		SUCCESS) _color 32 "[$level] $message";;
		INFO) echo "[$level] $message";;
		DEBUG) [ "$DEBUG" -eq 1 ] && _color 90 "[$level] $message" || true;;
		*) echo "[$level] $message";;
	esac
	echo
}

# ---------- Nagios helpers ----------
statusToText() {
	local status="$1"
	case "$status" in
		"$OK") echo "OK";;
		"$WARNING") echo "WARNING";;
		"$CRITICAL") echo "CRITICAL";;
		*) echo "UNKNOWN";;
	esac
}

nagiosFormat() {
	# Uso: nagiosFormat <STATUS> <MENSAJE> [PERFDATA]
	local status="$1"; shift
	local message="$1"; shift || true
	local perfdata="${1:-}"

	case "$status" in
		"$OK")       echo "OK: $message${perfdata:+ | $perfdata}";;
		"$WARNING")  echo "WARNING: $message${perfdata:+ | $perfdata}";;
		"$CRITICAL") echo "CRITICAL: $message${perfdata:+ | $perfdata}";;
		*)           echo "UNKNOWN: $message${perfdata:+ | $perfdata}"; status=$UNKNOWN;;
	esac

	log INFO "Estado salida: $(statusToText "$status") - $message"
	exit "$status"
}

# ---------- Conectividad TCP ----------
check_tcp() {
	# Prueba TCP a un host/puerto (util para concentradores VPN, APIs, etc.)
	# Requiere variables: TCP_HOST, TCP_PORT
	if [ -z "${TCP_HOST:-}" ] || [ -z "${TCP_PORT:-}" ]; then
		log ERROR "TCP_HOST o TCP_PORT no definidos"; return 2
	fi
	# -z solo prueba conexion, -v verbose, -w timeout
	if command -v nc >/dev/null 2>&1; then
		nc -z -v -w "$CONNECTION_TIMEOUT" "$TCP_HOST" "$TCP_PORT" >/dev/null 2>&1 && return 0 || return 1
	else
		# Fallback con /dev/tcp si bash lo soporta
		timeout "$CONNECTION_TIMEOUT" bash -c "</dev/tcp/$TCP_HOST/$TCP_PORT" >/dev/null 2>&1 && return 0 || return 1
	fi
}

# ---------- Ejemplo de integracion (comenta o elimina en produccion) ----------
# source "/ruta/funciones.sh"
# export SCRIPT_LOG="/var/log/miscripts/mi_script.log"
# export TCP_HOST="vpn.example.local"
# export TCP_PORT=443
#
# log INFO "Probando conectividad..."
# if check_tcp; then
#     log SUCCESS "Conectividad OK"
#     nagiosFormat "$OK" "Servicio accesible" "tcp_connect=1"
# else
#     log WARNING "Conectividad KO"
#     nagiosFormat "$CRITICAL" "Servicio inaccesible" "tcp_connect=0"
# fi
