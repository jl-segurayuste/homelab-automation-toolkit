# kerberos-linux-dc — Controlador de Dominio en Linux (Samba AD + Kerberos)

Montar y **endurecer** un Controlador de Dominio Active Directory sobre Linux usando
Samba 4 y Kerberos (MIT krb5). Enfoque de ciberseguridad: cifrados fuertes, auditoría y
buenas prácticas desde el primer minuto.

| Script | Qué hace |
|--------|----------|
| `provision-samba-ad-dc.sh` | Provisiona un DC (Samba AD) con DNS interno; pide la contraseña de forma interactiva (no se incrusta) |
| `harden-kerberos.sh` | Reescribe `/etc/krb5.conf` con solo AES (sin RC4/DES), `allow_weak_crypto=false` y tiempos de ticket acotados |
| `kerberos-security-audit.sh` | Auditoría de solo lectura: cifrados débiles, política de contraseñas, cuentas de riesgo y grupos privilegiados |
| `audit-keytabs-noaes.sh` | Recorre una flota de servidores por SSH y detecta keytabs con cifrado débil (no-AES: RC4/DES); genera CSV. Solo lectura |
| `detect-kerberoast.sh` | Detección defensiva (solo lectura): cuentas Kerberoastables (SPN), AS-REP roastables (sin preautenticación) y con RC4/sin AES |
| `rotate-krbtgt.sh` | Rota la contraseña de `krbtgt` (mitiga Golden Ticket); guía para ejecutarla dos veces con margen |
| `generate-keytab.sh` | Genera un keytab para un principal **forzando solo AES** (modo Samba DC con `samba-tool` o modo cliente con `ktutil`); permisos `600` |
| `krb-ticket-renew.sh` | Renovación automática de TGT (re-`kinit` desde keytab o `kinit -R`); para cron o `systemd.timer` |

## Uso

```bash
# 1. Provisionar (host dedicado, como root)
sudo REALM=EXAMPLE.LAN DOMAIN=EXAMPLE bash provision-samba-ad-dc.sh

# 2. Endurecer Kerberos
sudo REALM=EXAMPLE.LAN KDC=dc1.example.lan bash harden-kerberos.sh

# 3. Auditar
sudo bash kerberos-security-audit.sh
```

## Keytab y renovación automática de tickets

```bash
# Generar un keytab (en el DC, solo AES) para una cuenta de servicio
sudo bash generate-keytab.sh host/web1.example.lan /etc/krb5.keytab --samba

# Renovar el ticket automáticamente desde el keytab
sudo KEYTAB=/etc/krb5.keytab PRINCIPAL=host/web1.example.lan bash krb-ticket-renew.sh
```

Ejemplo de `systemd.timer` para renovar cada 6 horas
(`/etc/systemd/system/krb-renew.service` y `krb-renew.timer`):

```ini
# krb-renew.service
[Service]
Type=oneshot
Environment=KEYTAB=/etc/krb5.keytab PRINCIPAL=host/web1.example.lan
ExecStart=/usr/local/bin/krb-ticket-renew.sh

# krb-renew.timer
[Timer]
OnCalendar=*-*-* 00/6:00:00
Persistent=true
[Install]
WantedBy=timers.target
```

## Notas de seguridad

- Usa un **host dedicado** para el DC (no compartas roles).
- Tras el despliegue, **elimina claves RC4** de cuentas de servicio y **rota `krbtgt` dos veces**
  (mitiga Golden Ticket si la clave se vio comprometida).
- Aplica una política de contraseñas robusta:
  `samba-tool domain passwordsettings set --complexity=on --min-pwd-length=14 --history-length=24`.
- Sincroniza el reloj (NTP): Kerberos falla con desfase horario y el skew amplio facilita ataques.
- Mínimo privilegio en `Domain Admins`/`Enterprise Admins`: audítalos con regularidad.
- Las cuentas de servicio: usa **gMSA** o contraseñas largas y aleatorias; vigila el Kerberoasting.
