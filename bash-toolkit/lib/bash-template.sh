#!/usr/bin/env bash
#===============================================================================
# BIBLIOTECA DE PLANTILLAS PARA SCRIPTS BASH (robusta)
#===============================================================================
# - set -Eeuo pipefail y trap de errores con linea
# - Logging con niveles, colores opcionales y syslog
# - Validacion de dependencias, args y ficheros
# - Utilidades HTTP (curl) con reintentos sin eval
# - Gestion de temporales y cleanup seguro
# - Helpers de tiempo, progreso y parsing JSON opcional con jq
#===============================================================================
set -Eeuo pipefail
LOG_FILE=${LOG_FILE:-script.log}
DEBUG=${DEBUG:-0}
COLOR=${COLOR:-1}   # 1=colores, 0=sin colores
SYSLOG=${SYSLOG:-0} # 1=duplica logs a syslog (logger)

trap 'trap_error $LINENO' ERR

trap_error() {
	local line="$1"
	echo "[ERROR] $(date "+%F %T") - Falla en linea $line" >> "$LOG_FILE"
	[ "$SYSLOG" -eq 1 ] && logger -t bash-template "ERROR en linea $line"
}

#===============================================================================
# LOGGING
#===============================================================================
_color() {
	local code="$1"; shift
	if [ "$COLOR" -eq 1 ] && [ -t 1 ]; then
		printf "\e[%sm%s\e[0m" "$code" "$*"
	else
		printf "%s" "$*"
	fi
}

log() {
	local level="$1"; shift
	local message="$*"
	local ts
	ts=$(date "+%F %T")
	echo "[$ts] [$level] $message" >> "$LOG_FILE"
	[ "$SYSLOG" -eq 1 ] && logger -t bash-template "$level $message" || true
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

init_log() {
	local file="${1:-$LOG_FILE}"
	local append="${2:-0}"
	LOG_FILE="$file"
	[ "$append" -eq 0 ] && : > "$LOG_FILE"
	log INFO "Iniciando registro en $LOG_FILE"
}

die() { log ERROR "$*"; exit 1; }

#===============================================================================
# DEPENDENCIAS / ARGUMENTOS / FICHEROS
#===============================================================================
check_dependencies() {
	local missing=()
	for dep in "$@"; do command -v "$dep" >/dev/null 2>&1 || missing+=("$dep"); done
	if [ ${#missing[@]} -gt 0 ]; then
		log ERROR "Faltan dependencias: ${missing[*]}"; return 1
	fi
	log DEBUG "Dependencias OK: $*"; return 0
}

# Uso: require_args N "uso: script.sh <a> <b>" "$@"
require_args() {
	local expected="$1"; local usage="$2"; shift 2
	local actual=$#
	if [ "$actual" -ne "$expected" ]; then
		log ERROR "Se esperaban $expected argumentos, se recibieron $actual"; log ERROR "$usage"; return 1
	fi
	return 0
}

check_files_exist() {
	local f; for f in "$@"; do [ -f "$f" ] || { log ERROR "No existe: $f"; return 1; }; done
	return 0
}

#===============================================================================
# INDICADORES DE PROGRESO
#===============================================================================
show_progress() {
	local current="$1" total="$2" prefix="${3:-Progreso:}" width=50
	[ "$total" -eq 0 ] && total=1
	local percent=$(( current * 100 / total ))
	local done=$(( width * current / total ))
	local bar="["; for ((i=0;i<done;i++)); do bar+="#"; done; for ((i=done;i<width;i++)); do bar+="."; done; bar+="]"
	printf "\r%s %s %3d%% (%d/%d)" "$prefix" "$bar" "$percent" "$current" "$total"
	[ "$current" -ge "$total" ] && printf "\n"
}

show_spinner() {
	local pid="$1" msg="${2:-Procesando...}" spin='-\|/' i=0
	while kill -0 "$pid" 2>/dev/null; do i=$(( (i+1) % 4 )); printf "\r%s %c" "$msg" "${spin:$i:1}"; sleep 0.1; done
	printf "\r%s Completado.\n" "$msg"
}

#===============================================================================
# HTTP / API (curl)
#===============================================================================
http_request() {
	local url="$1" method="${2:-GET}" output="${3:-response.json}" retries="${4:-3}" timeout="${5:-30}"
	local auth_user="${6:-}" auth_pass="${7:-}" headers=("-H" "Accept: application/json")
	local try=1
	local args=( -k -s -S --fail --connect-timeout "$timeout" -X "$method" -o "$output" )
	[ -n "$auth_user" ] && args+=( -u "$auth_user:$auth_pass" )
	while [ "$try" -le "$retries" ]; do
		log DEBUG "HTTP $method $url (intento $try/$retries)"
		if curl "${headers[@]}" "${args[@]}" "$url" 2>curl_error.log; then
			[ -s "$output" ] || { log WARNING "Respuesta vacia"; };
			rm -f curl_error.log
			return 0
		else
			log DEBUG "curl error: $(<curl_error.log)"
			try=$((try+1)); [ "$try" -le "$retries" ] && sleep 2
		fi
	done
	rm -f curl_error.log
	log ERROR "Fallo HTTP tras $retries intentos"; return 1
}

upload_file() {
	local url="$1" file_path="$2" field_name="${3:-file}" auth_user="${4:-}" auth_pass="${5:-}" retries="${6:-3}"
	[ -f "$file_path" ] || { log ERROR "No existe $file_path"; return 1; }
	local try=1
	while [ "$try" -le "$retries" ]; do
		log DEBUG "Subiendo $file_path a $url (intento $try/$retries)"
		if [ -n "$auth_user" ]; then
			curl -k -s -S --fail -u "$auth_user:$auth_pass" -X POST -F "$field_name=@$file_path" "$url" && return 0
		else
			curl -k -s -S --fail -X POST -F "$field_name=@$file_path" "$url" && return 0
		fi
		try=$((try+1)); [ "$try" -le "$retries" ] && sleep 2
	done
	log ERROR "Fallo al subir $file_path"; return 1
}

#===============================================================================
# ARCHIVOS / DIRECTORIOS
#===============================================================================
prepare_directory() {
	local dir="$1" clean="${2:-0}"
	[ -d "$dir" ] || { log DEBUG "Creando $dir"; mkdir -p "$dir"; }
	[ "$clean" -eq 1 ] && { log DEBUG "Limpiando $dir"; rm -rf "${dir:?}"/* 2>/dev/null || true; }
	[ -w "$dir" ] || { log ERROR "Sin permisos de escritura en $dir"; return 1; }
}

extract_archive() {
	local src="$1" out="$2" format="${3:-auto}"
	[ -f "$src" ] || { log ERROR "No existe $src"; return 1; }
	prepare_directory "$out" 0
	log INFO "Extrayendo $src en $out"
	if [ "$format" = auto ]; then
		case "$src" in
			*.tar.gz|*.tgz) format=tar.gz;;
			*.tar.bz2) format=tar.bz2;;
			*.tar) format=tar;;
			*.zip) format=zip;;
			*) die "Formato no soportado";;
		esac
	fi
	case "$format" in
		tar) tar -xf "$src" -C "$out";;
		tar.gz) tar -xzf "$src" -C "$out";;
		tar.bz2) tar -xjf "$src" -C "$out";;
		zip) unzip -q "$src" -d "$out";;
		*) die "Formato no soportado: $format";;
	esac
	log DEBUG "Extraccion OK"
}

compress_directory() {
	local src="$1" dst="$2" format="${3:-tar.gz}"
	[ -d "$src" ] || { log ERROR "No existe dir $src"; return 1; }
	log INFO "Comprimiendo $src en $dst"
	case "$format" in
		tar) tar -cf "$dst" -C "$(dirname "$src")" "$(basename "$src")";;
		tar.gz) tar -czf "$dst" -C "$(dirname "$src")" "$(basename "$src")";;
		tar.bz2) tar -cjf "$dst" -C "$(dirname "$src")" "$(basename "$src")";;
		zip) (cd "$(dirname "$src")" && zip -qr "$dst" "$(basename "$src")") ;;
		*) die "Formato no soportado: $format";;
	esac
}

#===============================================================================
# PARSING / FILTROS
#===============================================================================
# Si hay jq, usalo; si no, intenta con grep/sed simple
json_get() {
	local file="$1" key="$2"
	[ -f "$file" ] || { log ERROR "No existe $file"; return 1; }
	if command -v jq >/dev/null 2>&1; then
		jq -r ".$key // empty" "$file"
	else
		grep -o "\"$key\" *: *\"[^\"]*\"" "$file" | sed -E "s/\"$key\" *: *\"([^\"]*)\"/\1/" || true
	fi
}

filter_files() {
	local src="$1" pattern="$2" mode="${3:-exclude}" dst="${4:-$1/filtered}"
	[ -d "$src" ] || { log ERROR "No existe dir $src"; return 1; }
	prepare_directory "$dst" 0
	log INFO "Filtrando en $src patron=$pattern modo=$mode"
	local f; while IFS= read -r -d '' f; do
		local base; base="$(basename "$f")"
		if echo "$base" | grep -q -E "$pattern"; then
			[ "$mode" = include ] && cp -a "$f" "$dst/" && log DEBUG "Incluido: $base" || log DEBUG "Excluido: $base"
		else
			[ "$mode" = exclude ] && cp -a "$f" "$dst/" && log DEBUG "Incluido: $base" || log DEBUG "Excluido: $base"
		fi
	done < <(find "$src" -type f -print0)
}

#===============================================================================
# TIEMPO / RENDIMIENTO
#===============================================================================
measure_execution_time() {
	local start end dur; start=$(date +%s); "$@"; local status=$?; end=$(date +%s); dur=$((end-start))
	log INFO "Tiempo de ejecucion: $((dur/3600))h $(((dur%3600)/60))m $((dur%60))s"; return $status
}

delayed_operation() { local s="$1" msg="${2:-Esperando...}"; printf "%s " "$msg"; for ((i=s;i>0;i--)); do printf "\r%s %02ds" "$msg" "$i"; sleep 1; done; printf "\r%s Completado.\n" "$msg"; }

#===============================================================================
# VALIDACIONES
#===============================================================================
validate_ip() {
	local ip="$1"; [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
	IFS='.' read -r a b c d <<< "$ip"; for o in $a $b $c $d; do [ "$o" -ge 0 ] && [ "$o" -le 255 ] || return 1; done; return 0
}

validate_url() {
	local url="$1"; [[ $url =~ ^https?://[^[:space:]]+$ ]] && return 0 || return 1
}

check_disk_space() {
	local need_mb="$1" dir="${2:-.}"; local avail_kb; avail_kb=$(df -k "$dir" | awk 'NR==2{print $4}'); local avail_mb=$((avail_kb/1024))
	[ "$avail_mb" -lt "$need_mb" ] && { log ERROR "Disco insuficiente: ${avail_mb}MB < ${need_mb}MB"; return 1; } || { log DEBUG "Disco OK: ${avail_mb}MB"; return 0; }
}

#===============================================================================
# TEMPORALES / LIMPIEZA
#===============================================================================
TEMP_FILES=(); TEMP_DIRS=();
register_temp_resource() { local r="$1" t="${2:-file}"; [ "$t" = file ] && TEMP_FILES+=("$r") || TEMP_DIRS+=("$r"); trap cleanup_temp_resources EXIT; }
cleanup_temp_resources() { log DEBUG "Limpieza de temporales"; local f; for f in "${TEMP_FILES[@]}"; do [ -f "$f" ] && rm -f "$f"; done; for f in "${TEMP_DIRS[@]}"; do [ -d "$f" ] && rm -rf "$f"; done; }

#===============================================================================
# PLANTILLAS
#===============================================================================
paginated_api_template() {
	local base_url="$1" output_file="$2" auth_user="$3" auth_pass="$4"
	local token="" page_count=0 total_items=0 temp_file="temp_page.json"
	: > "$output_file"
	log INFO "Iniciando descarga paginada desde $base_url"
	while true; do
		page_count=$((page_count+1))
		local current_url="$base_url"; [ -n "$token" ] && current_url+="&continuationToken=$token"
		log DEBUG "Descargando pagina $page_count: $current_url"
		if ! http_request "$current_url" GET "$temp_file" 3 30 "$auth_user" "$auth_pass"; then
			log ERROR "Error al descargar la pagina $page_count"; return 1
		fi
		token=$(json_get "$temp_file" continuationToken || true)
		local page_items; page_items=$(grep -c '"path"' "$temp_file" || true)
		total_items=$((total_items+page_items))
		cat "$temp_file" >> "$output_file"
		log INFO "Pagina $page_count procesada: $page_items elementos"
		[ -z "$token" ] && { log INFO "Descarga completa: $total_items elementos en $page_count paginas"; break; }
	done
	rm -f "$temp_file"
}

batch_process_template() {
	local source_dir="$1" batch_size="${2:-10}" process_function="$3"
	[ -d "$source_dir" ] || { log ERROR "No existe dir $source_dir"; return 1; }
	mapfile -t files < <(find "$source_dir" -type f)
	local total=${#files[@]}; [ "$total" -eq 0 ] && { log WARNING "Sin archivos en $source_dir"; return 0; }
	log INFO "Procesamiento por lotes: $total archivos"
	local i=0 batch=0 batches=$(( (total + batch_size - 1) / batch_size ))
	while [ "$i" -lt "$total" ]; do
		batch=$((batch+1)); log INFO "Lote $batch/$batches"
		local end=$((i+batch_size)); [ "$end" -gt "$total" ] && end=$total
		for ((; i<end; i++)); do
			show_progress $i $total "Procesando archivos:"
			"$process_function" "${files[$i]}" || log WARNING "Error con ${files[$i]}"
		done
	done
	show_progress $total $total "Procesando archivos:"
	log INFO "Batch completo"
}

#===============================================================================
# PLANTILLA DE MAIN
#===============================================================================
main() {
	init_log "script_$(date +%Y%m%d_%H%M%S).log" 0
	log INFO "Iniciando script"
	require_args 2 "script.sh <PARAM1> <PARAM2>" "$@" || exit 1
	check_dependencies curl sed grep || exit 1
	# Logica principal
	log INFO "Ejecutando logica principal..."
	# ...
	log SUCCESS "Proceso completado"
}

# Descomenta para usar como ejecutable
# main "$@"
