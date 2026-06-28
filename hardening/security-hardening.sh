#!/bin/bash
# Hardening basico para un servidor Debian/Ubuntu:
#   1. Fail2ban (anti fuerza bruta)
#   2. UFW (firewall)
#   3. rkhunter (deteccion de rootkits)
#   4. Actualizaciones automaticas de seguridad
#   5. Hardening SSH
#   6. Escaneo diario de seguridad
#
# Ajusta estas variables antes de ejecutar:
SSH_USER="${SSH_USER:-tuusuario}"            # usuario permitido por SSH
ALERT_EMAIL="${ALERT_EMAIL:-tu-email@ejemplo.com}"
LAN_CIDR="${LAN_CIDR:-192.168.1.0/24}"       # red de confianza para SSH
set -e

cat << EOF
==============================================
  HARDENING DE SEGURIDAD (Debian/Ubuntu)
==============================================
Usuario SSH permitido : $SSH_USER
Email de alertas      : $ALERT_EMAIL
Red de confianza SSH  : $LAN_CIDR

Capas: fail2ban, UFW, rkhunter, unattended-upgrades, SSH, escaneo diario.
EOF

read -p "Continuar con el hardening? (s/N): " -n 1 -r
echo
[[ $REPLY =~ ^[Ss]$ ]] || exit 0

# 1. FAIL2BAN
echo "1/6 - Instalando Fail2ban..."
sudo apt update
sudo apt install -y fail2ban
sudo tee /etc/fail2ban/jail.local << F2BCONF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
destemail = $ALERT_EMAIL
sendername = Fail2Ban
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200
F2BCONF
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
echo "[OK] Fail2ban configurado"

# 2. UFW FIREWALL
echo "2/6 - Configurando UFW..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from "$LAN_CIDR" to any port 22 comment 'SSH red de confianza'
sudo ufw allow from 172.16.0.0/12 comment 'Redes Docker'
sudo ufw allow from 10.0.0.0/8 comment 'VPN y K8s'
sudo ufw --force enable
echo "[OK] UFW configurado"

# 3. RKHUNTER
echo "3/6 - Instalando rkhunter..."
sudo apt install -y rkhunter
sudo rkhunter --update || true
sudo rkhunter --propupd
echo "[OK] rkhunter instalado"

# 4. ACTUALIZACIONES AUTOMATICAS
echo "4/6 - Configurando actualizaciones automaticas de seguridad..."
sudo apt install -y unattended-upgrades
sudo tee /etc/apt/apt.conf.d/50unattended-upgrades << UNATTENDED
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Mail "$ALERT_EMAIL";
Unattended-Upgrade::Automatic-Reboot "false";
UNATTENDED
sudo dpkg-reconfigure -plow unattended-upgrades
echo "[OK] Actualizaciones automaticas configuradas"

# 5. HARDENING SSH
echo "5/6 - Hardening SSH..."
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sudo tee -a /etc/ssh/sshd_config << SSHCONF

# Hardening SSH
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers $SSH_USER
SSHCONF
sudo systemctl restart sshd
echo "[OK] SSH hardening aplicado"

# 6. ESCANEO DIARIO DE SEGURIDAD
echo "6/6 - Configurando escaneo diario de seguridad..."
sudo tee /etc/cron.daily/security-scan << 'CRONSCAN'
#!/bin/bash
LOG="/var/log/security-scan.log"
echo "=======================================================" >> $LOG
echo "Escaneo de seguridad: $(date)" >> $LOG
echo "RKHUNTER:" >> $LOG
/usr/bin/rkhunter --check --skip-keypress --report-warnings-only >> $LOG 2>&1
echo "FAIL2BAN:" >> $LOG
/usr/bin/fail2ban-client status >> $LOG 2>&1
echo "SSH LOGIN FAILURES (24h):" >> $LOG
grep "Failed password" /var/log/auth.log | grep "$(date +%b\ %d)" >> $LOG 2>&1
echo "PUERTOS ABIERTOS:" >> $LOG
ss -tlnp >> $LOG 2>&1
echo "Escaneo completado" >> $LOG
CRONSCAN
sudo chmod +x /etc/cron.daily/security-scan
echo "[OK] Escaneo diario configurado"

cat << EOF

==============================================
  HARDENING COMPLETADO
==============================================
Servicios activos: fail2ban, UFW, rkhunter, unattended-upgrades, SSH hardening, escaneo diario.

Ver estado:
  sudo fail2ban-client status
  sudo ufw status
  cat /var/log/security-scan.log
EOF
