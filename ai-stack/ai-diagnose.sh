#!/bin/bash
# ai-diagnose.sh - diagnostico puntual de rendimiento de un stack Ollama.
# Modelo cargado, CPU, RAM, top de procesos, temperatura, frecuencia y un test
# rapido de inferencia. Solo lectura.
#
# Variables: TEST_MODEL (modelo para el test, def. llama3.2), OLLAMA_URL.
set -uo pipefail

TEST_MODEL="${TEST_MODEL:-llama3.2}"

echo "=== Diagnostico del stack de IA ==="

echo
echo "1. Modelo(s) cargado(s):"
ollama ps 2>/dev/null || echo "  (ollama no disponible)"

echo
echo "2. Uso de CPU:"
top -bn1 | grep "Cpu(s)"

echo
echo "3. Memoria:"
free -h | grep Mem

echo
echo "4. Top 5 procesos por CPU:"
ps aux --sort=-%cpu | head -6

echo
echo "5. Temperatura CPU:"
sensors 2>/dev/null | grep "Package id 0:" || echo "  N/A (instala lm-sensors)"

echo
echo "6. Frecuencia CPU:"
grep -m1 "cpu MHz" /proc/cpuinfo || true

echo
echo "7. Test rapido de inferencia (${TEST_MODEL}):"
if command -v ollama >/dev/null 2>&1; then
    time ollama run "${TEST_MODEL}" "Di 'hola' en una palabra" || \
        echo "  (no se pudo ejecutar; comprueba que el modelo '${TEST_MODEL}' existe: ollama pull ${TEST_MODEL})"
else
    echo "  (ollama no disponible)"
fi
