#!/bin/bash
# Limpieza de imagenes/contenedores/cache de containerd en nodos K3s.
# Util cuando / se llena por imagenes huerfanas (puede liberar 15-20 GB).
# Para K3s temporalmente; ejecutar en una ventana de mantenimiento.
# Uso: sudo bash cleanup-containerd.sh
set -uo pipefail

echo "=== Limpieza de containerd / K3s ==="
echo "Espacio actual en /: $(df -h / | awk 'NR==2 {print $5}')"
echo

echo "Imagenes actuales:"
sudo crictl images 2>/dev/null || sudo k3s crictl images

echo
read -p "Eliminar TODAS las imagenes/contenedores no utilizados? (s/N): " -n 1 -r
echo
[[ $REPLY =~ ^[Ss]$ ]] || exit 0

echo "Parando K3s..."
sudo systemctl stop k3s

echo "Eliminando imagenes no utilizadas..."
sudo crictl rmi --prune 2>/dev/null || sudo k3s crictl rmi --prune

echo "Eliminando contenedores parados..."
sudo crictl rm $(sudo crictl ps -a -q) 2>/dev/null || true

echo "Limpiando ingest/cache de containerd..."
sudo rm -rf /var/lib/rancher/k3s/agent/containerd/io.containerd.content.v1.content/ingest/* 2>/dev/null || true
sudo rm -rf /var/lib/containerd/io.containerd.content.v1.content/ingest/* 2>/dev/null || true

echo "Reiniciando K3s..."
sudo systemctl start k3s
sleep 30
kubectl get nodes 2>/dev/null || echo "[INFO] K3s aun reiniciando..."

echo
echo "=== Resultado ==="
df -h / | grep -E "Filesystem|/dev"
echo "Espacio usado por containerd:"
sudo du -sh /var/lib/containerd 2>/dev/null || true
sudo du -sh /var/lib/rancher 2>/dev/null || true
