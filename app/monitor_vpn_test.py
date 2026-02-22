#!/usr/bin/env python3
"""
Скрипт для мониторинга логов VPN подключения в реальном времени
"""
import subprocess
import time
import sys
from datetime import datetime

def print_header(title):
    """Выводит красивый заголовок"""
    print("\n" + "=" * 80)
    print(f"  {title}")
    print("=" * 80 + "\n")

def run_command(cmd):
    """Выполняет команду и возвращает результат"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)
        return result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        return "[TIMEOUT] Command took too long"
    except Exception as e:
        return f"[ERROR] {e}"

def monitor_vpn_test():
    """Главная функция мониторинга"""
    print_header("🚀 VPN CONNECTION MONITORING")
    
    print("[*] Инструкция:")
    print("    1. Нажмите кнопку VPN в приложении на устройстве")
    print("    2. Следите за логами ниже")
    print("    3. Приложение должно подключиться за 5-10 секунд")
    print("")
    
    # Получаем ANDROID_HOME
    import os
    android_home = os.path.expandvars(r"$env:USERPROFILE\AppData\Local\Android\Sdk").replace("$env:USERPROFILE", os.path.expanduser("~"))
    adb_path = f"{android_home}\\platform-tools\\adb.exe"
    device_id = "R5CXC3DWBDV"
    
    print(f"[*] Устройство: {device_id}")
    print(f"[*] ADB path: {adb_path}")
    print("")
    
    # Очищаем логи
    print("[*] Очищаем logcat...")
    run_command(f'"{adb_path}" -s {device_id} logcat -c')
    
    print("[OK] Готово! Ожидаю действия на устройстве...")
    print("")
    print("📱 LIVE LOGS (обновляются в реальном времени):")
    print("-" * 80)
    
    # Запускаем logcat и выводим в реальном времени
    cmd = f'"{adb_path}" -s {device_id} logcat -s flutter'
    
    try:
        process = subprocess.Popen(
            cmd,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
        )
        
        last_important = time.time()
        start_time = time.time()
        
        for line in process.stdout:
            line = line.rstrip()
            
            # Пропускаем пустые строки
            if not line.strip():
                continue
            
            # Выводим строку с временем
            timestamp = datetime.now().strftime("%H:%M:%S")
            
            # Подсвечиваем важные сообщения
            if any(keyword in line for keyword in [
                "Generated WireGuard", "Creating peer", "Peer created",
                "Fetching config", "Config received", "Connecting to WireGuard",
                "connected", "ERROR", "FAIL", "Exception", "wg_public_key"
            ]):
                print(f"[{timestamp}] ⭐ {line}")
                last_important = time.time()
            else:
                print(f"[{timestamp}] {line}")
            
            # Если прошло 30 секунд без важных логов, может быть что-то ждет действия
            if time.time() - last_important > 30:
                print("")
                print("⏳ [INFO] Приложение ждет действия (нажмите кнопку VPN)")
                print("")
                last_important = time.time()
        
        process.wait()
        
    except KeyboardInterrupt:
        print("\n")
        print("-" * 80)
        print_header("🛑 Мониторинг прерван пользователем")
        process.terminate()
        sys.exit(0)
    except Exception as e:
        print(f"\n[ERROR] {e}")
        sys.exit(1)

if __name__ == "__main__":
    monitor_vpn_test()
