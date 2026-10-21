#!/bin/bash
# shellcheck disable=SC1091,SC2034

# OpenVPN installer optimizado para Debian/Ubuntu
# Basado en: https://github.com/angristan/openvpn-install
#   Copyright (c) 2013 Nyr
#   Copyright (c) 2016 Stanislas Lange (angristan)
#   Licencia MIT: ver LICENSE-angristan en este directorio. Las modificaciones se
#   distribuyen bajo la licencia MIT del repositorio (LICENSE en la raíz).

set -euo pipefail

# Constantes de configuración
readonly CERT_VALIDITY_DAYS=3650
readonly CRL_VALIDITY_DAYS=3650
readonly EASYRSA_VERSION="3.1.2"
readonly EASYRSA_SHA256="d63cf129490ffd6d8792ede7344806c506c82c32428b5bb609ad97ca6a6e4499"
readonly EASYRSA_URL="https://github.com/OpenVPN/easy-rsa/releases/download/v${EASYRSA_VERSION}/EasyRSA-${EASYRSA_VERSION}.tgz"

# Colores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Funciones de logging
log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $*"
}

log_info() {
    echo "[INFO] $*"
}

# Validaciones básicas
is_root() {
    [[ "$EUID" -eq 0 ]]
}

tun_available() {
    [[ -e /dev/net/tun ]]
}

check_os() {
    if [[ ! -e /etc/debian_version ]]; then
        log_error "Este script solo funciona en Debian/Ubuntu"
        exit 1
    fi

    source /etc/os-release

    if [[ $ID == "debian" || $ID == "raspbian" ]]; then
        if [[ $VERSION_ID -lt 11 ]]; then
            log_warning "Se requiere Debian 11 o superior"
            read -rp "Continuar de todos modos? [y/n]: " -e CONTINUE
            [[ $CONTINUE == "n" ]] && exit 1
        fi
    elif [[ $ID == "ubuntu" ]]; then
        local major_version
        major_version=$(echo "$VERSION_ID" | cut -d '.' -f1)
        if [[ $major_version -lt 18 ]]; then
            log_warning "Se requiere Ubuntu 18.04 o superior"
            read -rp "Continuar de todos modos? [y/n]: " -e CONTINUE
            [[ $CONTINUE == "n" ]] && exit 1
        fi
    else
        log_error "Distribución no soportada: $ID"
        exit 1
    fi
}

initial_check() {
    if ! is_root; then
        log_error "Ejecuta el script como root o con sudo"
        exit 1
    fi
    
    if ! tun_available; then
        log_error "TUN/TAP no está disponible en este sistema"
        exit 1
    fi
    
    check_os
}

# Validación de IP
is_valid_ip() {
    local ip=$1
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ $ip =~ $regex ]]; then
        local IFS='.'
        read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if ((octet > 255)); then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

is_private_ip() {
    local ip=$1
    [[ $ip =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.) ]]
}

# Resolver IP pública
resolve_public_ip() {
    local curl_flags="-4"
    [[ ${IPV6_SUPPORT:-n} == "y" ]] && curl_flags=""

    local public_ip
    local services=(
        "https://api.seeip.org"
        "https://ifconfig.me"
        "https://api.ipify.org"
        "https://icanhazip.com"
    )

    for service in "${services[@]}"; do
        public_ip=$(curl -f -m 5 -sS --retry 2 $curl_flags "$service" 2>/dev/null) && break
    done

    if [[ -z $public_ip ]]; then
        log_error "No se pudo resolver la IP pública"
        return 1
    fi

    echo "$public_ip"
}

# Instalación de Unbound
install_unbound() {
    log_info "Configurando Unbound DNS resolver..."
    
    if [[ ! -e /etc/unbound/unbound.conf ]]; then
        apt-get install -y unbound

        cat >> /etc/unbound/unbound.conf <<EOF

# OpenVPN configuration
server:
    interface: 10.8.0.1
    access-control: 10.8.0.1/24 allow
    hide-identity: yes
    hide-version: yes
    use-caps-for-id: yes
    prefetch: yes
EOF

        if [[ ${IPV6_SUPPORT:-n} == 'y' ]]; then
            cat >> /etc/unbound/unbound.conf <<EOF
    interface: fd42:42:42:42::1
    access-control: fd42:42:42:42::/112 allow
EOF
        fi

        # Privacidad DNS
        cat >> /etc/unbound/unbound.conf <<EOF
    private-address: 10.0.0.0/8
    private-address: 172.16.0.0/12
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    private-address: fd00::/8
    private-address: fe80::/10
    private-address: 127.0.0.0/8
    private-address: ::ffff:0:0/96
EOF
        [[ ${IPV6_SUPPORT:-n} == 'y' ]] && echo "    private-address: fd42:42:42:42::/112" >> /etc/unbound/unbound.conf
    else
        echo 'include: /etc/unbound/openvpn.conf' >> /etc/unbound/unbound.conf

        cat > /etc/unbound/openvpn.conf <<EOF
server:
    interface: 10.8.0.1
    access-control: 10.8.0.1/24 allow
    hide-identity: yes
    hide-version: yes
    use-caps-for-id: yes
    prefetch: yes
    private-address: 10.0.0.0/8
    private-address: 172.16.0.0/12
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    private-address: fd00::/8
    private-address: fe80::/10
    private-address: 127.0.0.0/8
    private-address: ::ffff:0:0/96
EOF
        if [[ ${IPV6_SUPPORT:-n} == 'y' ]]; then
            cat >> /etc/unbound/openvpn.conf <<EOF
    interface: fd42:42:42:42::1
    access-control: fd42:42:42:42::/112 allow
    private-address: fd42:42:42:42::/112
EOF
        fi
    fi

    systemctl enable unbound
    systemctl restart unbound
    log_success "Unbound configurado correctamente"
}

# Preguntas de instalación
install_questions() {
    echo ""
    echo "============================================="
    echo "  Instalador de OpenVPN para Debian/Ubuntu"
    echo "============================================="
    echo ""
    log_info "Responde las siguientes preguntas de configuración"
    echo ""

    # Detectar IP local
    local detected_ip
    detected_ip=$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | head -1)
    [[ -z $detected_ip ]] && detected_ip=$(ip -6 addr | sed -ne 's|^.* inet6 \([^/]*\)/.* scope global.*$|\1|p' | head -1)

    if [[ ${APPROVE_IP:-n} =~ n ]]; then
        read -rp "Dirección IP del servidor [$detected_ip]: " -e -i "$detected_ip" IP
    else
        IP=$detected_ip
    fi

    # Verificar si está detrás de NAT
    if is_private_ip "$IP"; then
        echo ""
        log_info "El servidor parece estar detrás de NAT"
        
        if [[ -z ${ENDPOINT:-} ]]; then
            local default_endpoint
            default_endpoint=$(resolve_public_ip)
        fi

        until [[ -n ${ENDPOINT:-} ]]; do
            read -rp "IP pública o hostname [${default_endpoint}]: " -e -i "${default_endpoint}" ENDPOINT
        done
    fi

    # IPv6
    echo ""
    log_info "Comprobando conectividad IPv6..."
    
    local has_ipv6="n"
    if ping -6 -c 3 -W 2 ipv6.google.com &>/dev/null; then
        log_success "Conectividad IPv6 detectada"
        has_ipv6="y"
    else
        log_warning "Sin conectividad IPv6"
    fi

    until [[ ${IPV6_SUPPORT:-} =~ ^(y|n)$ ]]; do
        read -rp "Habilitar soporte IPv6? [y/n] [$has_ipv6]: " -e -i "$has_ipv6" IPV6_SUPPORT
    done

    # Puerto
    echo ""
    echo "Configuración de puerto:"
    echo "  1) Puerto 1194 (estándar)"
    echo "  2) Puerto personalizado"
    echo "  3) Puerto aleatorio (49152-65535)"
    
    until [[ ${PORT_CHOICE:-} =~ ^[1-3]$ ]]; do
        read -rp "Selecciona opción [1-3] [1]: " -e -i 1 PORT_CHOICE
    done

    case $PORT_CHOICE in
        1) PORT="1194" ;;
        2) 
            until [[ ${PORT:-} =~ ^[0-9]+$ ]] && (( PORT >= 1 && PORT <= 65535 )); do
                read -rp "Puerto personalizado (1-65535) [1194]: " -e -i 1194 PORT
            done
            ;;
        3) 
            PORT=$(shuf -i 49152-65535 -n1)
            log_info "Puerto aleatorio generado: $PORT"
            ;;
    esac

    # Protocolo
    echo ""
    echo "Protocolo de transporte:"
    echo "  1) UDP (recomendado - más rápido)"
    echo "  2) TCP (más compatible con firewalls restrictivos)"
    
    until [[ ${PROTOCOL_CHOICE:-} =~ ^[1-2]$ ]]; do
        read -rp "Selecciona protocolo [1-2] [1]: " -e -i 1 PROTOCOL_CHOICE
    done
    
    PROTOCOL=$([[ $PROTOCOL_CHOICE == "1" ]] && echo "udp" || echo "tcp")

    # DNS
    echo ""
    echo "Servidores DNS para clientes VPN:"
    echo "  1) Resolvers del sistema"
    echo "  2) Unbound (DNS local auto-hospedado)"
    echo "  3) Cloudflare (1.1.1.1) - Privado"
    echo "  4) Quad9 (9.9.9.9) - Seguridad"
    echo "  5) Google (8.8.8.8)"
    echo "  6) AdGuard (94.140.14.14) - Bloquea ads"
    echo "  7) DNS personalizado"
    
    until [[ ${DNS:-} =~ ^[1-7]$ ]]; do
        read -rp "Selecciona DNS [1-7] [3]: " -e -i 3 DNS
    done

    if [[ $DNS == "7" ]]; then
        until is_valid_ip "${DNS1:-}"; do
            read -rp "DNS primario (ej: 1.1.1.1): " -e DNS1
        done
        
        read -rp "DNS secundario (opcional): " -e DNS2
        if [[ -n $DNS2 ]] && ! is_valid_ip "$DNS2"; then
            log_warning "DNS secundario inválido, se ignorará"
            DNS2=""
        fi
    fi

    # Compresión
    echo ""
    log_warning "La compresión puede ser vulnerable al ataque VORACLE"
    until [[ ${COMPRESSION_ENABLED:-} =~ ^(y|n)$ ]]; do
        read -rp "Habilitar compresión LZ4? [y/n] [n]: " -e -i n COMPRESSION_ENABLED
    done

    # Cifrado
    echo ""
    log_info "Configuración de cifrado"
    until [[ ${CUSTOMIZE_ENC:-} =~ ^(y|n)$ ]]; do
        read -rp "Usar configuración de cifrado personalizada? [y/n] [n]: " -e -i n CUSTOMIZE_ENC
    done

    if [[ $CUSTOMIZE_ENC == "n" ]]; then
        # Valores seguros por defecto (ECDSA + AES-128-GCM)
        CIPHER="AES-128-GCM"
        CERT_TYPE="1"
        CERT_CURVE="prime256v1"
        CC_CIPHER="TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256"
        DH_TYPE="1"
        DH_CURVE="prime256v1"
        HMAC_ALG="SHA256"
        TLS_SIG="1"
        log_info "Usando configuración recomendada: ECDSA P-256 + AES-128-GCM"
    else
        configure_custom_encryption
    fi

    echo ""
    log_success "Configuración completada"
    
    if [[ ${APPROVE_INSTALL:-n} =~ n ]]; then
        echo ""
        read -n1 -r -p "Presiona cualquier tecla para comenzar la instalación..."
        echo ""
    fi
}

# Configuración personalizada de cifrado
configure_custom_encryption() {
    echo ""
    echo "Cifrado del canal de datos:"
    echo "  1) AES-128-GCM (recomendado)"
    echo "  2) AES-192-GCM"
    echo "  3) AES-256-GCM"
    echo "  4) AES-128-CBC"
    echo "  5) AES-192-CBC"
    echo "  6) AES-256-CBC"
    until [[ ${CIPHER_CHOICE:-} =~ ^[1-6]$ ]]; do
        read -rp "Selecciona cipher [1-6] [1]: " -e -i 1 CIPHER_CHOICE
    done

    case $CIPHER_CHOICE in
        1) CIPHER="AES-128-GCM" ;;
        2) CIPHER="AES-192-GCM" ;;
        3) CIPHER="AES-256-GCM" ;;
        4) CIPHER="AES-128-CBC" ;;
        5) CIPHER="AES-192-CBC" ;;
        6) CIPHER="AES-256-CBC" ;;
    esac

    echo ""
    echo "Tipo de certificado:"
    echo "  1) ECDSA (recomendado - más rápido)"
    echo "  2) RSA"
    until [[ ${CERT_TYPE:-} =~ ^[1-2]$ ]]; do
        read -rp "Tipo de certificado [1-2] [1]: " -e -i 1 CERT_TYPE
    done

    if [[ $CERT_TYPE == "1" ]]; then
        echo ""
        echo "Curva elíptica:"
        echo "  1) prime256v1 (P-256, recomendada)"
        echo "  2) secp384r1 (P-384)"
        echo "  3) secp521r1 (P-521)"
        until [[ ${CERT_CURVE_CHOICE:-} =~ ^[1-3]$ ]]; do
            read -rp "Curva [1-3] [1]: " -e -i 1 CERT_CURVE_CHOICE
        done

        case $CERT_CURVE_CHOICE in
            1) CERT_CURVE="prime256v1" ;;
            2) CERT_CURVE="secp384r1" ;;
            3) CERT_CURVE="secp521r1" ;;
        esac
    else
        echo ""
        echo "Tamaño de clave RSA:"
        echo "  1) 2048 bits (recomendado)"
        echo "  2) 3072 bits"
        echo "  3) 4096 bits"
        until [[ ${RSA_KEY_SIZE_CHOICE:-} =~ ^[1-3]$ ]]; do
            read -rp "Tamaño RSA [1-3] [1]: " -e -i 1 RSA_KEY_SIZE_CHOICE
        done

        case $RSA_KEY_SIZE_CHOICE in
            1) RSA_KEY_SIZE="2048" ;;
            2) RSA_KEY_SIZE="3072" ;;
            3) RSA_KEY_SIZE="4096" ;;
        esac
    fi

    # Control channel cipher
    echo ""
    echo "Cifrado del canal de control:"
    if [[ $CERT_TYPE == "1" ]]; then
        echo "  1) TLS-ECDHE-ECDSA-AES-128-GCM-SHA256 (recomendado)"
        echo "  2) TLS-ECDHE-ECDSA-AES-256-GCM-SHA384"
        until [[ ${CC_CIPHER_CHOICE:-} =~ ^[1-2]$ ]]; do
            read -rp "Control cipher [1-2] [1]: " -e -i 1 CC_CIPHER_CHOICE
        done

        CC_CIPHER=$([[ $CC_CIPHER_CHOICE == "1" ]] && echo "TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256" || echo "TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384")
    else
        echo "  1) TLS-ECDHE-RSA-AES-128-GCM-SHA256 (recomendado)"
        echo "  2) TLS-ECDHE-RSA-AES-256-GCM-SHA384"
        until [[ ${CC_CIPHER_CHOICE:-} =~ ^[1-2]$ ]]; do
            read -rp "Control cipher [1-2] [1]: " -e -i 1 CC_CIPHER_CHOICE
        done

        CC_CIPHER=$([[ $CC_CIPHER_CHOICE == "1" ]] && echo "TLS-ECDHE-RSA-WITH-AES-128-GCM-SHA256" || echo "TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384")
    fi

    # Diffie-Hellman
    echo ""
    echo "Tipo de intercambio de claves Diffie-Hellman:"
    echo "  1) ECDH (recomendado - más rápido)"
    echo "  2) DH tradicional"
    until [[ ${DH_TYPE:-} =~ ^[1-2]$ ]]; do
        read -rp "DH type [1-2] [1]: " -e -i 1 DH_TYPE
    done

    if [[ $DH_TYPE == "1" ]]; then
        echo ""
        echo "Curva ECDH:"
        echo "  1) prime256v1 (recomendada)"
        echo "  2) secp384r1"
        echo "  3) secp521r1"
        until [[ ${DH_CURVE_CHOICE:-} =~ ^[1-3]$ ]]; do
            read -rp "Curva [1-3] [1]: " -e -i 1 DH_CURVE_CHOICE
        done

        case $DH_CURVE_CHOICE in
            1) DH_CURVE="prime256v1" ;;
            2) DH_CURVE="secp384r1" ;;
            3) DH_CURVE="secp521r1" ;;
        esac
    else
        echo ""
        echo "Tamaño de parámetros DH:"
        echo "  1) 2048 bits (recomendado)"
        echo "  2) 3072 bits"
        echo "  3) 4096 bits (muy lento)"
        until [[ ${DH_KEY_SIZE_CHOICE:-} =~ ^[1-3]$ ]]; do
            read -rp "Tamaño DH [1-3] [1]: " -e -i 1 DH_KEY_SIZE_CHOICE
        done

        case $DH_KEY_SIZE_CHOICE in
            1) DH_KEY_SIZE="2048" ;;
            2) DH_KEY_SIZE="3072" ;;
            3) DH_KEY_SIZE="4096" ;;
        esac
    fi

    # HMAC
    echo ""
    echo "Algoritmo HMAC para autenticación:"
    echo "  1) SHA-256 (recomendado)"
    echo "  2) SHA-384"
    echo "  3) SHA-512"
    until [[ ${HMAC_ALG_CHOICE:-} =~ ^[1-3]$ ]]; do
        read -rp "HMAC [1-3] [1]: " -e -i 1 HMAC_ALG_CHOICE
    done

    case $HMAC_ALG_CHOICE in
        1) HMAC_ALG="SHA256" ;;
        2) HMAC_ALG="SHA384" ;;
        3) HMAC_ALG="SHA512" ;;
    esac

    # TLS auth/crypt
    echo ""
    echo "Seguridad adicional del canal de control:"
    echo "  1) tls-crypt (recomendado - autenticación + cifrado)"
    echo "  2) tls-auth (solo autenticación)"
    until [[ ${TLS_SIG:-} =~ ^[1-2]$ ]]; do
        read -rp "TLS security [1-2] [1]: " -e -i 1 TLS_SIG
    done
}

# Instalación principal
install_openvpn() {
    if [[ ${AUTO_INSTALL:-n} == "y" ]]; then
        APPROVE_INSTALL=${APPROVE_INSTALL:-y}
        APPROVE_IP=${APPROVE_IP:-y}
        IPV6_SUPPORT=${IPV6_SUPPORT:-n}
        PORT_CHOICE=${PORT_CHOICE:-1}
        PROTOCOL_CHOICE=${PROTOCOL_CHOICE:-1}
        DNS=${DNS:-3}
        COMPRESSION_ENABLED=${COMPRESSION_ENABLED:-n}
        CUSTOMIZE_ENC=${CUSTOMIZE_ENC:-n}
        CLIENT=${CLIENT:-client}
        PASS=${PASS:-1}
        
        [[ -z ${ENDPOINT:-} ]] && ENDPOINT=$(resolve_public_ip)
    fi

    install_questions

    # Detectar interfaz de red principal
    log_info "Detectando interfaz de red..."
    NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
    
    if [[ -z $NIC ]] && [[ ${IPV6_SUPPORT:-n} == 'y' ]]; then
        NIC=$(ip -6 route show default | sed -ne 's/^default .* dev \([^ ]*\) .*$/\1/p')
    fi

    if [[ -z $NIC ]]; then
        log_error "No se pudo detectar la interfaz de red principal"
        read -rp "Introduce manualmente la interfaz (ej: eth0): " -e NIC
        
        if [[ -z $NIC ]]; then
            log_error "Interfaz de red requerida para continuar"
            exit 1
        fi
    fi
    
    log_success "Interfaz detectada: $NIC"

    # Instalar paquetes necesarios
    if [[ ! -e /etc/openvpn/server.conf ]]; then
        log_info "Actualizando repositorios e instalando paquetes..."
        apt-get update -qq
        apt-get install -y -qq openvpn iptables openssl wget ca-certificates curl procps   # procps: sysctl (falta en imágenes mínimas)
        log_success "Paquetes instalados"
    fi

    # Detectar grupo sin permisos
    NOGROUP=$(grep -qs "^nogroup:" /etc/group && echo "nogroup" || echo "nobody")

    # Descargar e instalar easy-rsa
    if [[ ! -d /etc/openvpn/easy-rsa/ ]]; then
        log_info "Descargando Easy-RSA ${EASYRSA_VERSION}..."
        
        if ! wget -q -O ~/easy-rsa.tgz "$EASYRSA_URL"; then
            log_error "Fallo al descargar Easy-RSA"
            exit 1
        fi

        log_info "Verificando integridad..."
        if ! echo "${EASYRSA_SHA256}  $HOME/easy-rsa.tgz" | sha256sum -c --status; then
            log_error "Verificación SHA256 fallida - archivo corrupto o comprometido"
            rm -f ~/easy-rsa.tgz
            exit 1
        fi

        mkdir -p /etc/openvpn/easy-rsa
        tar xzf ~/easy-rsa.tgz --strip-components=1 --no-same-owner --directory /etc/openvpn/easy-rsa
        rm -f ~/easy-rsa.tgz
        log_success "Easy-RSA instalado"

        cd /etc/openvpn/easy-rsa/ || exit 1

        # Configurar Easy-RSA según tipo de certificado
        case ${CERT_TYPE:-1} in
            1)
                cat > vars <<EOF
set_var EASYRSA_ALGO ec
set_var EASYRSA_CURVE ${CERT_CURVE:-prime256v1}
set_var EASYRSA_CERT_EXPIRE ${CERT_VALIDITY_DAYS}
set_var EASYRSA_CA_EXPIRE ${CERT_VALIDITY_DAYS}
set_var EASYRSA_CRL_DAYS ${CRL_VALIDITY_DAYS}
EOF
                ;;
            2)
                cat > vars <<EOF
set_var EASYRSA_KEY_SIZE ${RSA_KEY_SIZE:-2048}
set_var EASYRSA_CERT_EXPIRE ${CERT_VALIDITY_DAYS}
set_var EASYRSA_CA_EXPIRE ${CERT_VALIDITY_DAYS}
set_var EASYRSA_CRL_DAYS ${CRL_VALIDITY_DAYS}
EOF
                ;;
        esac

        # Generar identificadores aleatorios seguros
        log_info "Generando infraestructura PKI..."
        SERVER_CN="cn_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
        SERVER_NAME="server_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
        echo "$SERVER_CN" > SERVER_CN_GENERATED
        echo "$SERVER_NAME" > SERVER_NAME_GENERATED

        # Inicializar PKI
        ./easyrsa --batch init-pki >/dev/null 2>&1
        
        # Crear CA
        log_info "Creando Autoridad Certificadora..."
        ./easyrsa --batch --req-cn="$SERVER_CN" build-ca nopass >/dev/null 2>&1

        # Generar parámetros DH si es necesario
        if [[ ${DH_TYPE:-1} == "2" ]]; then
            log_info "Generando parámetros Diffie-Hellman ${DH_KEY_SIZE:-2048} bits (esto puede tardar varios minutos)..."
            openssl dhparam -out dh.pem "${DH_KEY_SIZE:-2048}" 2>/dev/null
        fi

        # Generar certificado del servidor
        log_info "Generando certificado del servidor..."
        ./easyrsa --batch build-server-full "$SERVER_NAME" nopass >/dev/null 2>&1
        
        # Generar CRL
        ./easyrsa gen-crl >/dev/null 2>&1

        # Generar clave TLS
        case ${TLS_SIG:-1} in
            1)
                log_info "Generando clave tls-crypt..."
                openvpn --genkey secret /etc/openvpn/tls-crypt.key 2>/dev/null
                chmod 644 /etc/openvpn/tls-crypt.key
                ;;
            2)
                log_info "Generando clave tls-auth..."
                openvpn --genkey secret /etc/openvpn/tls-auth.key 2>/dev/null
                chmod 644 /etc/openvpn/tls-auth.key
                ;;
        esac
        
        log_success "PKI creada correctamente"
    else
        cd /etc/openvpn/easy-rsa/ || exit 1
        SERVER_NAME=$(cat SERVER_NAME_GENERATED)
        log_info "Usando PKI existente"
    fi

    # Copiar certificados a /etc/openvpn
    log_info "Copiando certificados..."
    cp pki/ca.crt pki/private/ca.key "pki/issued/$SERVER_NAME.crt" "pki/private/$SERVER_NAME.key" pki/crl.pem /etc/openvpn/
    [[ ${DH_TYPE:-1} == "2" ]] && cp dh.pem /etc/openvpn/
    chmod 644 /etc/openvpn/crl.pem

    # Generar configuración del servidor
    log_info "Generando configuración del servidor..."
    
    cat > /etc/openvpn/server.conf <<EOF
# Puerto y protocolo
port ${PORT:-1194}
proto $([ "${IPV6_SUPPORT:-n}" = "y" ] && echo "${PROTOCOL:-udp}6" || echo "${PROTOCOL:-udp}")

# Dispositivo TUN
dev tun

# Usuario y grupo sin privilegios
user nobody
group $NOGROUP

# Persistencia de claves y túnel
persist-key
persist-tun

# Keepalive: ping cada 10s, timeout 120s
keepalive 10 120

# Topología de red
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt

EOF

    # Configurar DNS según elección
    case ${DNS:-3} in
        1) # Sistema
            local resolvconf
            resolvconf=$(grep -q "127.0.0.53" /etc/resolv.conf && echo '/run/systemd/resolve/resolv.conf' || echo '/etc/resolv.conf')
            
            while IFS= read -r ns; do
                if [[ $ns =~ ^[0-9.]+$ ]] || [[ ${IPV6_SUPPORT:-n} == 'y' ]]; then
                    echo "push \"dhcp-option DNS $ns\"" >> /etc/openvpn/server.conf
                fi
            done < <(sed -ne 's/^nameserver[[:space:]]\+\([^[:space:]]\+\).*$/\1/p' "$resolvconf")
            ;;
        2) # Unbound
            echo 'push "dhcp-option DNS 10.8.0.1"' >> /etc/openvpn/server.conf
            [[ ${IPV6_SUPPORT:-n} == 'y' ]] && echo 'push "dhcp-option DNS fd42:42:42:42::1"' >> /etc/openvpn/server.conf
            ;;
        3) # Cloudflare
            cat >> /etc/openvpn/server.conf <<EOF
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 1.0.0.1"
EOF
            ;;
        4) # Quad9
            cat >> /etc/openvpn/server.conf <<EOF
push "dhcp-option DNS 9.9.9.9"
push "dhcp-option DNS 149.112.112.112"
EOF
            ;;
        5) # Google
            cat >> /etc/openvpn/server.conf <<EOF
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
EOF
            ;;
        6) # AdGuard
            cat >> /etc/openvpn/server.conf <<EOF
push "dhcp-option DNS 94.140.14.14"
push "dhcp-option DNS 94.140.15.15"
EOF
            ;;
        7) # Custom
            echo "push \"dhcp-option DNS ${DNS1}\"" >> /etc/openvpn/server.conf
            [[ -n ${DNS2:-} ]] && echo "push \"dhcp-option DNS ${DNS2}\"" >> /etc/openvpn/server.conf
            ;;
    esac

    # Redirigir todo el tráfico por VPN
    echo 'push "redirect-gateway def1 bypass-dhcp"' >> /etc/openvpn/server.conf

    # Configuración IPv6 si está habilitado
    if [[ ${IPV6_SUPPORT:-n} == 'y' ]]; then
        cat >> /etc/openvpn/server.conf <<EOF

# Configuración IPv6
server-ipv6 fd42:42:42:42::/112
tun-ipv6
push tun-ipv6
push "route-ipv6 2000::/3"
push "redirect-gateway ipv6"
EOF
    fi

    # Compresión
    [[ ${COMPRESSION_ENABLED:-n} == "y" ]] && echo -e "\n# Compresión\ncompress lz4-v2" >> /etc/openvpn/server.conf

    # Diffie-Hellman
    cat >> /etc/openvpn/server.conf <<EOF

# Diffie-Hellman
EOF
    if [[ ${DH_TYPE:-1} == "1" ]]; then
        cat >> /etc/openvpn/server.conf <<EOF
dh none
ecdh-curve ${DH_CURVE:-prime256v1}
EOF
    else
        echo "dh dh.pem" >> /etc/openvpn/server.conf
    fi

    # TLS auth/crypt
    cat >> /etc/openvpn/server.conf <<EOF

# Seguridad TLS
EOF
    case ${TLS_SIG:-1} in
        1) echo "tls-crypt tls-crypt.key" >> /etc/openvpn/server.conf ;;
        2) echo "tls-auth tls-auth.key 0" >> /etc/openvpn/server.conf ;;
    esac

    # Configuración de certificados y cifrado
    cat >> /etc/openvpn/server.conf <<EOF

# Certificados
crl-verify crl.pem
ca ca.crt
cert $SERVER_NAME.crt
key $SERVER_NAME.key

# Cifrado
auth ${HMAC_ALG:-SHA256}
cipher ${CIPHER:-AES-128-GCM}
ncp-ciphers ${CIPHER:-AES-128-GCM}

# TLS
tls-server
tls-version-min 1.2
tls-cipher ${CC_CIPHER:-TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256}

# Directorios
client-config-dir /etc/openvpn/ccd
status /var/log/openvpn/status.log

# Verbosidad
verb 3
EOF

    # Crear directorios necesarios
    mkdir -p /etc/openvpn/ccd /var/log/openvpn

    # Habilitar IP forwarding
    log_info "Habilitando IP forwarding..."
    cat > /etc/sysctl.d/99-openvpn.conf <<EOF
# IP Forwarding para OpenVPN
net.ipv4.ip_forward=1
EOF
    [[ ${IPV6_SUPPORT:-n} == 'y' ]] && echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.d/99-openvpn.conf
    sysctl --system >/dev/null 2>&1

    # Configurar servicio systemd
    log_info "Configurando servicio systemd..."
    cp /lib/systemd/system/openvpn\@.service /etc/systemd/system/openvpn\@.service
    
    # Workarounds para compatibilidad
    sed -i 's|LimitNPROC|#LimitNPROC|' /etc/systemd/system/openvpn\@.service
    sed -i 's|/etc/openvpn/server|/etc/openvpn|' /etc/systemd/system/openvpn\@.service

    systemctl daemon-reload
    systemctl enable openvpn@server >/dev/null 2>&1
    systemctl restart openvpn@server

    # Verificar que el servicio arrancó correctamente
    sleep 2
    if systemctl is-active --quiet openvpn@server; then
        log_success "Servicio OpenVPN iniciado correctamente"
    else
        log_error "Fallo al iniciar el servicio OpenVPN"
        log_info "Revisa los logs: journalctl -xeu openvpn@server"
        exit 1
    fi

    # Instalar Unbound si se seleccionó
    [[ ${DNS:-3} == 2 ]] && install_unbound

    # Configurar reglas de firewall
    log_info "Configurando reglas de firewall..."
    mkdir -p /etc/iptables

    # Script para añadir reglas
    cat > /etc/iptables/add-openvpn-rules.sh <<EOF
#!/bin/bash
# Reglas iptables para OpenVPN

# Habilitar NAT para clientes VPN
iptables -t nat -I POSTROUTING 1 -s 10.8.0.0/24 -o $NIC -j MASQUERADE

# Permitir tráfico en interfaz tun0
iptables -I INPUT 1 -i tun0 -j ACCEPT
iptables -I FORWARD 1 -i $NIC -o tun0 -j ACCEPT
iptables -I FORWARD 1 -i tun0 -o $NIC -j ACCEPT

# Permitir conexiones entrantes a OpenVPN
iptables -I INPUT 1 -i $NIC -p ${PROTOCOL:-udp} --dport ${PORT:-1194} -j ACCEPT
EOF

    if [[ ${IPV6_SUPPORT:-n} == 'y' ]]; then
        cat >> /etc/iptables/add-openvpn-rules.sh <<EOF

# Reglas IPv6
ip6tables -t nat -I POSTROUTING 1 -s fd42:42:42:42::/112 -o $NIC -j MASQUERADE
ip6tables -I INPUT 1 -i tun0 -j ACCEPT
ip6tables -I FORWARD 1 -i $NIC -o tun0 -j ACCEPT
ip6tables -I FORWARD 1 -i tun0 -o $NIC -j ACCEPT
ip6tables -I INPUT 1 -i $NIC -p ${PROTOCOL:-udp} --dport ${PORT:-1194} -j ACCEPT
EOF
    fi

    # Script para eliminar reglas
    cat > /etc/iptables/rm-openvpn-rules.sh <<EOF
#!/bin/bash
# Eliminar reglas iptables de OpenVPN

iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o $NIC -j MASQUERADE
iptables -D INPUT -i tun0 -j ACCEPT
iptables -D FORWARD -i $NIC -o tun0 -j ACCEPT
iptables -D FORWARD -i tun0 -o $NIC -j ACCEPT
iptables -D INPUT -i $NIC -p ${PROTOCOL:-udp} --dport ${PORT:-1194} -j ACCEPT
EOF

    if [[ ${IPV6_SUPPORT:-n} == 'y' ]]; then
        cat >> /etc/iptables/rm-openvpn-rules.sh <<EOF

ip6tables -t nat -D POSTROUTING -s fd42:42:42:42::/112 -o $NIC -j MASQUERADE
ip6tables -D INPUT -i tun0 -j ACCEPT
ip6tables -D FORWARD -i $NIC -o tun0 -j ACCEPT
ip6tables -D FORWARD -i tun0 -o $NIC -j ACCEPT
ip6tables -D INPUT -i $NIC -p ${PROTOCOL:-udp} --dport ${PORT:-1194} -j ACCEPT
EOF
    fi

    chmod +x /etc/iptables/add-openvpn-rules.sh /etc/iptables/rm-openvpn-rules.sh

    # Servicio systemd para iptables
    cat > /etc/systemd/system/iptables-openvpn.service <<EOF
[Unit]
Description=Reglas iptables para OpenVPN
Before=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/etc/iptables/add-openvpn-rules.sh
ExecStop=/etc/iptables/rm-openvpn-rules.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable iptables-openvpn >/dev/null 2>&1
    systemctl start iptables-openvpn
    log_success "Firewall configurado"

    # Usar endpoint público si está configurado
    [[ -n ${ENDPOINT:-} ]] && IP=$ENDPOINT

    # Crear template de configuración de cliente
    log_info "Generando template de cliente..."
    cat > /etc/openvpn/client-template.txt <<EOF
# Cliente OpenVPN
client

# Protocolo
proto $([ "${PROTOCOL:-udp}" = "udp" ] && echo "udp" || echo "tcp-client")
$([ "${PROTOCOL:-udp}" = "udp" ] && echo "explicit-exit-notify")

# Servidor
remote ${IP} ${PORT:-1194}

# Configuración básica
dev tun
resolv-retry infinite
nobind
persist-key
persist-tun

# Seguridad
remote-cert-tls server
verify-x509-name $SERVER_NAME name
auth ${HMAC_ALG:-SHA256}
auth-nocache
cipher ${CIPHER:-AES-128-GCM}

# TLS
tls-client
tls-version-min 1.2
tls-cipher ${CC_CIPHER:-TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256}

# Windows DNS leak protection
ignore-unknown-option block-outside-dns
setenv opt block-outside-dns

# Verbosidad
verb 3
EOF

    [[ ${COMPRESSION_ENABLED:-n} == "y" ]] && echo "compress lz4-v2" >> /etc/openvpn/client-template.txt

    # Crear primer cliente
    new_client

    echo ""
    echo "============================================="
    log_success "Instalación de OpenVPN completada"
    echo "============================================="
    echo ""
    log_info "Estado del servicio:"
    systemctl status openvpn@server --no-pager -l
    echo ""
    log_info "Para añadir más clientes, ejecuta de nuevo este script"
    echo ""
}

# Crear nuevo cliente
new_client() {
    echo ""
    echo "--- Crear nuevo cliente ---"
    echo ""
    
    # En la instalación desatendida, CLIENT y PASS ya vienen dados (por defecto client y 1): sin esto
    # se volvía a preguntar, read fallaba sin terminal y set -e cortaba la instalación
    local client_name="" pass_choice=""
    if [[ ${AUTO_INSTALL:-n} == "y" ]]; then
        client_name=${CLIENT:-client}
        pass_choice=${PASS:-1}
    fi
    until [[ ${client_name:-} =~ ^[a-zA-Z0-9_-]+$ ]]; do
        read -rp "Nombre del cliente (alfanumérico, - y _ permitidos): " -e client_name
    done
    CLIENT=$client_name

    echo ""
    echo "Protección con contraseña:"
    echo "  1) Sin contraseña (recomendado para la mayoría de casos)"
    echo "  2) Con contraseña (mayor seguridad si el archivo .ovpn puede ser robado)"
    
    until [[ ${pass_choice:-} =~ ^[1-2]$ ]]; do
        read -rp "Opción [1-2] [1]: " -e -i 1 pass_choice
    done
    PASS=$pass_choice

    # Verificar si el cliente ya existe
    cd /etc/openvpn/easy-rsa/ || exit 1
    
    local client_exists
    # grep -c ya imprime 0 cuando no hay coincidencias (y sale con 1): con "|| echo 0" salía "0 0"
    client_exists=$(tail -n +2 pki/index.txt 2>/dev/null | grep -c -E "/CN=$CLIENT\$" || true)
    
    if [[ $client_exists -gt 0 ]]; then
        log_error "El cliente '$CLIENT' ya existe"
        log_info "Usa la opción de revocar si quieres recrearlo"
        exit 1
    fi

    log_info "Generando certificado para '$CLIENT'..."
    
    # con set -e, un "if [[ $? -ne 0 ]]" después nunca llegaba a ejecutarse
    local rc=0
    case $PASS in
        1)
            EASYRSA_CERT_EXPIRE=$CERT_VALIDITY_DAYS ./easyrsa --batch build-client-full "$CLIENT" nopass >/dev/null 2>&1 || rc=$?
            ;;
        2)
            echo ""
            log_info "Introduce la contraseña para proteger la clave privada:"
            EASYRSA_CERT_EXPIRE=$CERT_VALIDITY_DAYS ./easyrsa --batch build-client-full "$CLIENT" || rc=$?
            ;;
    esac

    if [[ $rc -ne 0 ]]; then
        log_error "Fallo al generar el certificado"
        exit 1
    fi

    log_success "Certificado para '$CLIENT' generado"

    # Determinar directorio home
    local home_dir
    if [[ -d "/home/${CLIENT}" ]]; then
        home_dir="/home/${CLIENT}"
    elif [[ -n ${SUDO_USER:-} ]]; then
        if [[ $SUDO_USER == "root" ]]; then
            home_dir="/root"
        else
            home_dir="/home/${SUDO_USER}"
        fi
    else
        home_dir="/root"
    fi

    # Detectar tipo de TLS (crypt o auth)
    local tls_sig
    if grep -qs "^tls-crypt" /etc/openvpn/server.conf; then
        tls_sig="1"
    else
        tls_sig="2"
    fi

    # Generar archivo .ovpn
    log_info "Generando archivo de configuración..."
    
    local config_file="${home_dir}/${CLIENT}.ovpn"
    cp /etc/openvpn/client-template.txt "$config_file"

    {
        echo ""
        echo "# Certificados y claves"
        echo "<ca>"
        cat "/etc/openvpn/easy-rsa/pki/ca.crt"
        echo "</ca>"

        echo "<cert>"
        awk '/BEGIN/,/END CERTIFICATE/' "/etc/openvpn/easy-rsa/pki/issued/$CLIENT.crt"
        echo "</cert>"

        echo "<key>"
        cat "/etc/openvpn/easy-rsa/pki/private/$CLIENT.key"
        echo "</key>"

        case $tls_sig in
            1)
                echo "<tls-crypt>"
                cat /etc/openvpn/tls-crypt.key
                echo "</tls-crypt>"
                ;;
            2)
                echo "key-direction 1"
                echo "<tls-auth>"
                cat /etc/openvpn/tls-auth.key
                echo "</tls-auth>"
                ;;
        esac
    } >> "$config_file"

    # Ajustar permisos
    chmod 600 "$config_file"
    
    # Si se usó sudo, cambiar el propietario
    if [[ -n ${SUDO_USER:-} ]] && [[ $SUDO_USER != "root" ]]; then
        chown "${SUDO_USER}:${SUDO_USER}" "$config_file" 2>/dev/null || true
    fi

    echo ""
    log_success "Cliente '$CLIENT' creado exitosamente"
    echo ""
    echo "Archivo de configuración:"
    echo "  $config_file"
    echo ""
    log_info "Descarga este archivo e impórtalo en tu cliente OpenVPN"
    echo ""
}

# Revocar cliente
revoke_client() {
    cd /etc/openvpn/easy-rsa/ || exit 1
    
    local num_clients
    num_clients=$(tail -n +2 pki/index.txt 2>/dev/null | grep -c "^V" || true)
    
    if [[ $num_clients -eq 0 ]]; then
        log_warning "No hay clientes activos para revocar"
        exit 0
    fi

    echo ""
    echo "--- Revocar certificado de cliente ---"
    echo ""
    echo "Clientes activos:"
    
    tail -n +2 pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
    
    echo ""
    local client_number
    until [[ ${client_number:-0} -ge 1 && ${client_number:-0} -le $num_clients ]]; do
        read -rp "Selecciona el número de cliente a revocar [1-$num_clients]: " client_number
    done

    local client_name
    client_name=$(tail -n +2 pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "${client_number}p")

    echo ""
    log_warning "Vas a revocar el certificado de: $client_name"
    read -rp "Confirmas? [y/n]: " -e confirm
    
    if [[ $confirm != "y" ]]; then
        log_info "Operación cancelada"
        exit 0
    fi

    log_info "Revocando certificado..."
    
    ./easyrsa --batch revoke "$client_name" >/dev/null 2>&1
    EASYRSA_CRL_DAYS=$CRL_VALIDITY_DAYS ./easyrsa gen-crl >/dev/null 2>&1

    # Actualizar CRL
    rm -f /etc/openvpn/crl.pem
    cp pki/crl.pem /etc/openvpn/crl.pem
    chmod 644 /etc/openvpn/crl.pem

    # Eliminar archivos de configuración
    find /home/ -maxdepth 2 -name "${client_name}.ovpn" -delete 2>/dev/null
    rm -f "/root/${client_name}.ovpn"

    # Eliminar asignación de IP persistente
    sed -i "/^${client_name},.*/d" /etc/openvpn/ipp.txt 2>/dev/null

    # Backup del índice
    cp pki/index.txt "pki/index.txt.bk-$(date +%Y%m%d-%H%M%S)"

    log_success "Certificado de '$client_name' revocado exitosamente"
    log_info "El cliente ya no podrá conectarse al servidor VPN"
}

# Desinstalar OpenVPN
remove_openvpn() {
    echo ""
    echo "--- Desinstalar OpenVPN ---"
    echo ""
    log_warning "Esta acción eliminará:"
    echo "  - Servidor OpenVPN"
    echo "  - Todos los certificados y claves"
    echo "  - Configuraciones de clientes"
    echo "  - Reglas de firewall"
    echo ""
    
    read -rp "Estas seguro de que quieres continuar? [y/n]: " -e -i n confirm
    
    if [[ $confirm != 'y' ]]; then
        log_info "Desinstalación cancelada"
        return 0
    fi

    log_info "Deteniendo servicios..."
    
    # Detener y deshabilitar OpenVPN
    systemctl stop openvpn@server 2>/dev/null
    systemctl disable openvpn@server 2>/dev/null
    rm -f /etc/systemd/system/openvpn\@.service

    # Detener y deshabilitar iptables-openvpn
    systemctl stop iptables-openvpn 2>/dev/null
    systemctl disable iptables-openvpn 2>/dev/null
    rm -f /etc/systemd/system/iptables-openvpn.service
    
    systemctl daemon-reload

    log_info "Eliminando reglas de firewall..."
    rm -f /etc/iptables/add-openvpn-rules.sh /etc/iptables/rm-openvpn-rules.sh

    log_info "Desinstalando paquetes..."
    apt-get remove --purge -y openvpn 2>/dev/null

    log_info "Eliminando archivos de configuración..."
    find /home/ -maxdepth 2 -name "*.ovpn" -delete 2>/dev/null
    find /root/ -maxdepth 1 -name "*.ovpn" -delete 2>/dev/null
    rm -rf /etc/openvpn
    rm -rf /usr/share/doc/openvpn*
    rm -f /etc/sysctl.d/99-openvpn.conf
    rm -rf /var/log/openvpn

    # Preguntar por Unbound
    if [[ -e /etc/unbound/openvpn.conf ]]; then
        echo ""
        log_info "Unbound DNS resolver detectado"
        read -rp "Desinstalar Unbound completamente? [y/n]: " -e remove_unbound
        
        if [[ $remove_unbound == 'y' ]]; then
            systemctl stop unbound 2>/dev/null
            apt-get remove --purge -y unbound 2>/dev/null
            rm -rf /etc/unbound/
            log_success "Unbound eliminado"
        else
            sed -i '/include: \/etc\/unbound\/openvpn.conf/d' /etc/unbound/unbound.conf
            rm -f /etc/unbound/openvpn.conf
            systemctl restart unbound
            log_info "Configuración de OpenVPN eliminada de Unbound"
        fi
    fi

    # Revertir IP forwarding
    sysctl -w net.ipv4.ip_forward=0 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.all.forwarding=0 >/dev/null 2>&1

    echo ""
    log_success "OpenVPN ha sido completamente desinstalado"
}

# Menú de gestión
manage_menu() {
    echo ""
    echo "============================================="
    echo "       Gestor de OpenVPN"
    echo "============================================="
    echo ""
    echo "OpenVPN está instalado y funcionando"
    echo ""
    echo "Opciones disponibles:"
    echo "  1) Añadir nuevo cliente"
    echo "  2) Revocar certificado de cliente"
    echo "  3) Desinstalar OpenVPN"
    echo "  4) Salir"
    echo ""

    local menu_option
    until [[ ${menu_option:-} =~ ^[1-4]$ ]]; do
        read -rp "Selecciona una opción [1-4]: " menu_option
    done

    case $menu_option in
        1) new_client ;;
        2) revoke_client ;;
        3) remove_openvpn ;;
        4) 
            log_info "Saliendo..."
            exit 0
            ;;
    esac
}

# MAIN
main() {
    initial_check

    if [[ -e /etc/openvpn/server.conf ]] && [[ ${AUTO_INSTALL:-n} != "y" ]]; then
        manage_menu
    else
        install_openvpn
    fi
}

# Ejecutar función principal
main "$@"