#!/usr/bin/env bash
# Hardening de Kerberos (MIT krb5) en un host Linux (cliente o DC).
# Aplica una /etc/krb5.conf con tipos de cifrado FUERTES y desactiva los debiles.
#
# Mitiga: ataques por cifrados debiles (RC4-HMAC -> Kerberoasting, DES), y reduce
# la ventana de uso de tickets. Haz backup; revisa antes de aplicar en produccion.
#
# Uso:  sudo REALM=EXAMPLE.LAN KDC=dc1.example.lan bash harden-kerberos.sh
set -euo pipefail

REALM="${REALM:-EXAMPLE.LAN}"
KDC="${KDC:-dc1.example.lan}"
ADMIN_SERVER="${ADMIN_SERVER:-$KDC}"

if [[ $EUID -ne 0 ]]; then echo "[ERROR] Ejecuta como root." >&2; exit 1; fi

ts=$(date +%Y%m%d-%H%M%S)
[[ -f /etc/krb5.conf ]] && cp /etc/krb5.conf "/etc/krb5.conf.bak.$ts" && echo "[*] Backup: /etc/krb5.conf.bak.$ts"

realm_lc="$(echo "$REALM" | tr '[:upper:]' '[:lower:]')"

cat > /etc/krb5.conf <<EOF
[libdefaults]
    default_realm = $REALM
    dns_lookup_realm = false
    dns_lookup_kdc = true
    # Solo cifrados fuertes: AES. Se omiten deliberadamente RC4-HMAC y DES (debiles).
    default_tgs_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
    default_tkt_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
    permitted_enctypes  = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
    # Endurecimiento de tickets
    ticket_lifetime = 10h
    renew_lifetime  = 7d
    forwardable = true
    rdns = false
    # Proteccion frente a downgrade y validacion estricta de KDC
    allow_weak_crypto = false

[realms]
    $REALM = {
        kdc = $KDC
        admin_server = $ADMIN_SERVER
    }

[domain_realm]
    .$realm_lc = $REALM
    $realm_lc = $REALM
EOF

chmod 644 /etc/krb5.conf
echo "[OK] /etc/krb5.conf endurecido (solo AES, sin RC4/DES, allow_weak_crypto=false)."
echo "Recomendado: en el DC, eliminar claves RC4 de cuentas de servicio y rotar krbtgt dos veces."
