#!/usr/bin/env python3
"""
manage_problem_ips.py - Gestionar IPs problemáticas
Script para diagnosticar y manejar IPs que causan problemas en el escaneo
"""

import os
import sys
import subprocess
import time
from datetime import datetime
from pathlib import Path
from typing import List, Optional
import re

# Colores ANSI
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
NC = '\033[0m'


def print_header(text: str) -> None:
    """Imprime un encabezado formateado"""
    print(f"\n{BLUE}{'=' * 39}{NC}")
    print(f"{BLUE}  {text}{NC}")
    print(f"{BLUE}{'=' * 39}{NC}\n")


def run_command(cmd: List[str], timeout: int = 30) -> tuple[bool, str]:
    """Ejecuta un comando con timeout y retorna (éxito, salida)"""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        return result.returncode == 0, result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        return False, "Timeout"
    except Exception as e:
        return False, str(e)


def diagnose_ip(ip: str) -> None:
    """Diagnostica una IP específica"""
    print_header(f"DIAGNÓSTICO DE IP: {ip}")
    
    # 1. Test de ping básico
    print("1. Test de ping básico...")
    success, output = run_command(['ping', '-c', '3', '-W', '5', ip], timeout=10)
    if success and 'bytes from' in output:
        print(f"{GREEN}[OK] Responde a ping{NC}")
    else:
        print(f"{RED}[X] No responde a ping{NC}")
    
    # 2. Test de puertos comunes
    print("\n2. Test de puertos comunes (timeout 3s cada uno)...")
    ports = [21, 22, 25, 80, 443, 3306, 3389, 8080]
    for port in ports:
        try:
            result = subprocess.run(
                ['nc', '-z', '-w', '3', ip, str(port)],
                capture_output=True,
                timeout=5
            )
            if result.returncode == 0:
                print(f"   Puerto {port}: {GREEN}ABIERTO{NC}")
            else:
                print(f"   Puerto {port}: cerrado/filtrado")
        except:
            print(f"   Puerto {port}: cerrado/filtrado")
    
    # 3. Escaneo nmap rápido
    print("\n3. Escaneo nmap rápido (solo puertos comunes)...")
    success, output = run_command(
        ['nmap', '-Pn', '-F', '--host-timeout', '30s', ip],
        timeout=60
    )
    if success:
        print(output)
    else:
        print(f"{RED}Error en escaneo nmap{NC}")
    
    # 4. Test HTTP/HTTPS directo
    print("\n4. Test HTTP/HTTPS directo...")
    print("\n   HTTP (puerto 80):")
    success, output = run_command(
        ['curl', '-I', '-m', '3', f'http://{ip}'],
        timeout=5
    )
    print('\n'.join(output.split('\n')[:5]))
    
    print("\n   HTTPS (puerto 443):")
    success, output = run_command(
        ['curl', '-I', '-k', '-m', '3', f'https://{ip}'],
        timeout=5
    )
    print('\n'.join(output.split('\n')[:5]))
    
    # 5. Traceroute
    print("\n5. Traceroute (máximo 10 saltos)...")
    success, output = run_command(
        ['traceroute', '-m', '10', '-w', '1', ip],
        timeout=30
    )
    print('\n'.join(output.split('\n')[:15]))
    
    # 6. Whois básico
    print("\n6. Whois básico...")
    success, output = run_command(['whois', ip], timeout=10)
    if success:
        for line in output.split('\n'):
            if any(keyword in line.lower() for keyword in ['country', 'netname', 'organization']):
                print(line)
    
    print(f"\n{YELLOW}Diagnóstico completado para {ip}{NC}\n")


def create_exclusion_list(report_dir: str) -> bool:
    """Crea lista de exclusión de IPs fallidas"""
    failed_file = Path(report_dir) / 'ips_fallidas.txt'
    exclusion_file = Path(report_dir) / 'EXCLUDED_IPS.txt'
    
    if not failed_file.exists():
        print("No se encontró archivo de IPs fallidas")
        return False
    
    print_header("GENERANDO LISTA DE EXCLUSIÓN")
    print("IPs que fallaron en el último escaneo:\n")
    
    # Extraer IPs únicas
    ips = set()
    with open(failed_file, 'r') as f:
        for line in f:
            if line.strip():
                ip = line.split()[0]
                ips.add(ip)
    
    # Guardar lista ordenada
    with open(exclusion_file, 'w') as f:
        for i, ip in enumerate(sorted(ips), 1):
            f.write(f"{ip}\n")
            print(f"{i:4d}  {ip}")
    
    print(f"\nLista de exclusión guardada en: {exclusion_file}\n")
    print("Para usar esta lista, añade al script principal:\n")
    print("EXCLUDED_IPS = [")
    for ip in sorted(ips):
        print(f'    "{ip}",')
    print("]\n")
    
    return True


def retry_failed_ips(report_dir: str) -> None:
    """Reintenta escanear IPs fallidas"""
    failed_file = Path(report_dir) / 'ips_fallidas.txt'
    
    if not failed_file.exists():
        print("No se encontró archivo de IPs fallidas")
        return
    
    print_header("REINTENTANDO IPS FALLIDAS")
    
    # Extraer IPs únicas
    ips = set()
    with open(failed_file, 'r') as f:
        for line in f:
            if line.strip():
                ip = line.split()[0]
                ips.add(ip)
    
    failed_ips = sorted(ips)
    print(f"Se encontraron {len(failed_ips)} IPs con problemas\n")
    
    for ip in failed_ips:
        print(f"{BLUE}Reintentando: {ip}{NC}")
        print("Escaneo básico...")
        
        run_command(
            ['nmap', '-Pn', '-F', '--host-timeout', '20s', ip],
            timeout=60
        )
        
        print()
        response = input("¿Continuar con siguiente IP? (s/n): ").lower()
        if response != 's':
            break
        print()


def generate_stats(report_dir: str) -> None:
    """Genera estadísticas del escaneo"""
    print_header("ESTADÍSTICAS DEL ESCANEO")
    
    report_path = Path(report_dir)
    
    # Contar archivos
    total_basic = len(list(report_path.glob('*_basic.txt')))
    total_services = len(list(report_path.glob('*_services.txt')))
    total_vulns = len(list(report_path.glob('*_vulnerabilities.txt')))
    
    print("Archivos generados:")
    print(f"  - Escaneos básicos: {total_basic}")
    print(f"  - Escaneos de servicios: {total_services}")
    print(f"  - Escaneos de vulnerabilidades: {total_vulns}\n")
    
    # IPs exitosas
    success_file = report_path / 'ips_exitosas.txt'
    if success_file.exists():
        with open(success_file, 'r') as f:
            successful = len([line for line in f if line.strip()])
        print(f"IPs escaneadas exitosamente: {successful}")
    
    # IPs fallidas
    failed_file = report_path / 'ips_fallidas.txt'
    if failed_file.exists():
        with open(failed_file, 'r') as f:
            lines = [line for line in f if line.strip()]
            failed = len(lines)
        
        print(f"IPs con problemas: {failed}\n")
        
        if failed > 0:
            print("Razones de fallo más comunes:")
            reasons = {}
            for line in lines:
                for reason in ['Timeout', 'No responde', 'Falló']:
                    if reason in line:
                        reasons[reason] = reasons.get(reason, 0) + 1
            
            for reason, count in sorted(reasons.items(), key=lambda x: x[1], reverse=True):
                print(f"  {reason}: {count}")
    
    print()
    
    # Análisis de IPs problemáticas
    if failed_file.exists():
        print("Análisis de IPs problemáticas:")
        
        problem_ips = set()
        with open(failed_file, 'r') as f:
            for line in f:
                if line.strip():
                    ip = line.split()[0]
                    problem_ips.add(ip)
        
        if problem_ips:
            print(f"  - Total de IPs únicas con problemas: {len(problem_ips)}")
            
            # Rangos de red
            print("\n  Rangos de red con más problemas:")
            ranges = {}
            for ip in problem_ips:
                network = '.'.join(ip.split('.')[:2])
                ranges[network] = ranges.get(network, 0) + 1
            
            for network, count in sorted(ranges.items(), key=lambda x: x[1], reverse=True)[:5]:
                print(f"    {network}.x.x: {count} IPs")
    
    print()


def create_selective_scan(report_dir: str) -> bool:
    """Crea script de escaneo selectivo"""
    failed_file = Path(report_dir) / 'ips_fallidas.txt'
    output_script = Path(report_dir) / 'retry_selective.py'
    
    if not failed_file.exists():
        print("No se encontró archivo de IPs fallidas")
        return False
    
    print_header("CREANDO SCRIPT DE ESCANEO SELECTIVO")
    
    # Extraer IPs únicas
    ips = set()
    with open(failed_file, 'r') as f:
        for line in f:
            if line.strip():
                ip = line.split()[0]
                ips.add(ip)
    
    # Crear script Python
    script_content = f'''#!/usr/bin/env python3
"""Script generado automáticamente para reintentar IPs problemáticas"""

import subprocess
import os
from datetime import datetime
from pathlib import Path

RETRY_DIR = f"retry_scan_{{datetime.now().strftime('%Y%m%d_%H%M%S')}}"
Path(RETRY_DIR).mkdir(exist_ok=True)

FAILED_IPS = [
'''
    
    for ip in sorted(ips):
        script_content += f'    "{ip}",\n'
    
    script_content += ''']

print("=== ESCANEO SELECTIVO DE IPS PROBLEMÁTICAS ===")
print(f"Total de IPs a reintentar: {len(FAILED_IPS)}")
print()

for ip in FAILED_IPS:
    print(f"Escaneando {ip}...")
    
    # Intento 1: Ping
    result = subprocess.run(
        ['ping', '-c', '2', '-W', '5', ip],
        capture_output=True,
        timeout=10
    )
    
    output_file = Path(RETRY_DIR) / f"{ip}_retry.txt"
    
    if result.returncode == 0:
        print("  [OK] Responde a ping")
        
        # Escaneo básico rápido
        subprocess.run(
            ['nmap', '-Pn', '-F', '--host-timeout', '30s', ip, '-oN', str(output_file)],
            timeout=60
        )
    else:
        print("  [X] No responde - probando con nmap -Pn")
        
        # Escaneo forzado sin ping
        subprocess.run(
            ['nmap', '-Pn', '-F', '--max-retries', '1', '--host-timeout', '45s', 
             ip, '-oN', str(output_file)],
            timeout=90
        )
    
    print()
    import time
    time.sleep(2)

print(f"Resultados guardados en: {RETRY_DIR}")
'''
    
    with open(output_script, 'w') as f:
        f.write(script_content)
    
    os.chmod(output_script, 0o755)
    
    print(f"Script creado: {output_script}")
    print(f"Ejecuta con: python3 {output_script}")
    print()
    
    return True


def compare_scans(dir1: str, dir2: str) -> None:
    """Compara resultados entre dos escaneos"""
    path1 = Path(dir1)
    path2 = Path(dir2)
    
    if not path1.exists() or not path2.exists():
        print("Error: Ambos directorios deben existir")
        return
    
    print_header("COMPARACIÓN DE ESCANEOS")
    print(f"Directorio 1: {dir1}")
    print(f"Directorio 2: {dir2}\n")
    
    # Extraer IPs escaneadas
    def get_scanned_ips(directory):
        ips = set()
        for file in directory.glob('*_basic.txt'):
            ip = file.stem.replace('_basic', '')
            ips.add(ip)
        return ips
    
    ips1 = get_scanned_ips(path1)
    ips2 = get_scanned_ips(path2)
    
    print(f"IPs en escaneo 1: {len(ips1)}")
    print(f"IPs en escaneo 2: {len(ips2)}\n")
    
    # IPs únicas en cada escaneo
    only_in_1 = ips1 - ips2
    only_in_2 = ips2 - ips1
    common = ips1 & ips2
    
    if only_in_1:
        print("IPs solo en primer escaneo:")
        for ip in sorted(only_in_1):
            print(f"  {ip}")
    
    if only_in_2:
        print("\nIPs solo en segundo escaneo:")
        for ip in sorted(only_in_2):
            print(f"  {ip}")
    
    print(f"\nIPs comunes: Comparando diferencias...\n")
    
    # Comparar puertos abiertos en IPs comunes
    for ip in sorted(common):
        file1 = path1 / f"{ip}_basic.txt"
        file2 = path2 / f"{ip}_basic.txt"
        
        if file1.exists() and file2.exists():
            with open(file1, 'r') as f:
                ports1 = len([line for line in f if 'open' in line])
            
            with open(file2, 'r') as f:
                ports2 = len([line for line in f if 'open' in line])
            
            if ports1 != ports2:
                print(f"  {ip}: {ports1} puertos -> {ports2} puertos")


def batch_connectivity_check() -> None:
    """Verifica conectividad en batch"""
    print_header("VERIFICACIÓN BATCH DE CONECTIVIDAD")
    
    ip_file = input("Archivo con lista de IPs (una por línea): ")
    
    if not Path(ip_file).exists():
        print("Archivo no encontrado")
        return
    
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    output_file = f"connectivity_check_{timestamp}.txt"
    
    print("Verificando conectividad...\n")
    
    with open(ip_file, 'r') as f_in, open(output_file, 'w') as f_out:
        header = f"REPORTE DE CONECTIVIDAD - {datetime.now()}\n"
        header += "=" * 50 + "\n\n"
        print(header)
        f_out.write(header)
        
        for line in f_in:
            ip = line.strip()
            
            # Saltar líneas vacías o comentarios
            if not ip or ip.startswith('#'):
                continue
            
            result = f"{ip:20s} : "
            
            # Test ping
            ping_result = subprocess.run(
                ['ping', '-c', '1', '-W', '1', ip],
                capture_output=True,
                timeout=3
            )
            
            if ping_result.returncode == 0:
                status = "[OK] ACTIVA (ping)"
            else:
                # Test puerto 80
                nc_80 = subprocess.run(
                    ['nc', '-z', '-w', '1', ip, '80'],
                    capture_output=True,
                    timeout=3
                )
                if nc_80.returncode == 0:
                    status = "[OK] ACTIVA (puerto 80)"
                else:
                    # Test puerto 443
                    nc_443 = subprocess.run(
                        ['nc', '-z', '-w', '1', ip, '443'],
                        capture_output=True,
                        timeout=3
                    )
                    if nc_443.returncode == 0:
                        status = "[OK] ACTIVA (puerto 443)"
                    else:
                        # Test puerto 22
                        nc_22 = subprocess.run(
                            ['nc', '-z', '-w', '1', ip, '22'],
                            capture_output=True,
                            timeout=3
                        )
                        if nc_22.returncode == 0:
                            status = "[OK] ACTIVA (puerto 22)"
                        else:
                            status = "[X] NO RESPONDE"
            
            result += status
            print(result)
            f_out.write(result + '\n')
    
    print(f"\nReporte guardado en: {output_file}")


def show_menu() -> None:
    """Muestra el menú principal"""
    while True:
        os.system('clear' if os.name != 'nt' else 'cls')
        
        print(f"{GREEN}")
        print("=" * 59)
        print("    GESTIÓN DE IPS PROBLEMÁTICAS")
        print("=" * 59)
        print(f"{NC}\n")
        
        print("1) Diagnosticar IP específica")
        print("2) Generar estadísticas de escaneo")
        print("3) Crear lista de exclusión de IPs fallidas")
        print("4) Reintentar IPs fallidas manualmente")
        print("5) Crear script de escaneo selectivo")
        print("6) Comparar dos escaneos")
        print("7) Verificar conectividad batch de múltiples IPs")
        print("8) Salir\n")
        
        option = input("Selecciona opción [1-8]: ")
        
        try:
            if option == '1':
                ip = input("Introduce la IP a diagnosticar: ")
                diagnose_ip(ip)
            elif option == '2':
                report_dir = input("Directorio de reportes: ")
                generate_stats(report_dir)
            elif option == '3':
                report_dir = input("Directorio de reportes: ")
                create_exclusion_list(report_dir)
            elif option == '4':
                report_dir = input("Directorio de reportes: ")
                retry_failed_ips(report_dir)
            elif option == '5':
                report_dir = input("Directorio de reportes: ")
                create_selective_scan(report_dir)
            elif option == '6':
                dir1 = input("Directorio escaneo 1: ")
                dir2 = input("Directorio escaneo 2: ")
                compare_scans(dir1, dir2)
            elif option == '7':
                batch_connectivity_check()
            elif option == '8':
                sys.exit(0)
            else:
                print("Opción inválida")
        except KeyboardInterrupt:
            print("\n\nInterrumpido por usuario")
        except Exception as e:
            print(f"\nError: {e}")
        
        print()
        input("Presiona Enter para continuar...")


def main():
    """Función principal"""
    if len(sys.argv) == 1:
        show_menu()
    else:
        command = sys.argv[1]
        
        if command == 'diagnose' and len(sys.argv) > 2:
            diagnose_ip(sys.argv[2])
        elif command == 'stats' and len(sys.argv) > 2:
            generate_stats(sys.argv[2])
        elif command == 'exclude' and len(sys.argv) > 2:
            create_exclusion_list(sys.argv[2])
        elif command == 'retry' and len(sys.argv) > 2:
            retry_failed_ips(sys.argv[2])
        elif command == 'selective' and len(sys.argv) > 2:
            create_selective_scan(sys.argv[2])
        else:
            print("Uso: python3 manage_problem_ips.py [diagnose|stats|exclude|retry|selective] [argumentos]")
            print("O ejecuta sin argumentos para menú interactivo")


if __name__ == '__main__':
    main()
