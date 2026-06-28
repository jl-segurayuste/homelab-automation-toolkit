# wireguard — VPN moderna con WireGuard

Despliegue y gestión de un servidor WireGuard, con buenas prácticas de seguridad.
Alternativa moderna y ligera a OpenVPN (ver también [`../openvpn`](../openvpn)).

| Script | Qué hace |
|--------|----------|
| `install-wireguard.sh` | Instala WireGuard, **genera las claves en el host**, activa el reenvío IP y crea `wg0` con NAT de salida |
| `add-peer.sh` | Añade un peer: genera sus claves + clave precompartida (PSK) y produce la config del cliente |

## Uso

```bash
sudo WG_ADDR=10.10.0.1/24 WG_PORT=51820 bash install-wireguard.sh
sudo ENDPOINT=vpn.example.com bash add-peer.sh portatil 10.10.0.2
# Entrega la config del cliente por un canal seguro; opcional QR:
qrencode -t ansiutf8 < /etc/wireguard/clients/portatil.conf
```

## Seguridad

- **Las claves nunca se versionan**: se generan en el host y viven en `/etc/wireguard`
  con permisos `600`. No subas `*.conf` ni `*.key` a git (el `.gitignore` ya los excluye).
- Se usa **PresharedKey (PSK)** por peer como capa extra (defensa frente a futuros
  ataques cuánticos al intercambio de claves).
- Abre en el firewall **solo** el puerto WireGuard (UDP); todo lo demás, cerrado.
- Entrega las configs de cliente por canal seguro (contienen la clave privada del cliente).
- Revoca un peer quitándolo de `wg0.conf` y con `wg set wg0 peer <PUBKEY> remove`.
