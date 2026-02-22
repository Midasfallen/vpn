#!/usr/bin/env python3
"""
Скрипт для развертывания backend изменений на production сервер 146.103.99.70
"""
import subprocess
import sys
import os

def run_command(cmd, description=""):
    """Выполняет команду и логирует результат"""
    if description:
        print(f"\n[*] {description}...")
    print(f"[CMD] {cmd}")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    
    if result.stdout:
        print(f"[OUT] {result.stdout.strip()}")
    if result.stderr:
        print(f"[ERR] {result.stderr.strip()}")
    
    return result.returncode == 0, result.stdout, result.stderr

def main():
    """Главная функция развертывания"""
    print("=" * 70)
    print("🚀 Backend Deployment Script")
    print("=" * 70)
    
    # 1. Проверяем что мы в правильной папке
    if not os.path.exists("backend_api/peers.py"):
        print("[ERROR] peers.py не найден! Убедитесь что находитесь в корне репозитория.")
        sys.exit(1)
    
    print("[OK] Находимся в корне репозитория")
    
    # 2. Проверяем, есть ли локальные изменения
    success, stdout, _ = run_command("git status --porcelain", "Проверяем статус репозитория")
    if stdout.strip():
        print("[WARN] Есть локальные изменения:")
        print(stdout)
    
    # 3. Получаем хеш текущего коммита
    success, commit_hash, _ = run_command("git rev-parse HEAD", "Получаем хеш коммита")
    commit_hash = commit_hash.strip()
    print(f"[OK] Текущий коммит: {commit_hash[:8]}")
    
    # 4. Проверяем, какие файлы изменены в нашем коммите
    success, files_changed, _ = run_command(
        "git diff-tree --no-commit-id --name-only -r HEAD",
        "Получаем список измененных файлов"
    )
    print(f"[OK] Файлы для развертывания:")
    for line in files_changed.strip().split('\n'):
        if 'backend_api' in line or 'PHASE' not in line:
            print(f"    - {line}")
    
    # 5. Рекомендуем развертывание
    print("\n" + "=" * 70)
    print("📋 ИНСТРУКЦИЯ ДЛЯ РАЗВЕРТЫВАНИЯ НА СЕРВЕР 146.103.99.70:")
    print("=" * 70)
    
    print("\n🔹 Способ 1: Через Git (если сервер имеет git репозиторий)")
    print("""
ssh root@146.103.99.70 << 'EOF'
cd /srv/vpn-api
git fetch origin
git checkout main
git reset --hard origin/main
# или конкретный коммит:
# git reset --hard e8ca3b7

# Перезагружаем сервис
systemctl restart vpn-api
systemctl status vpn-api
EOF
    """)
    
    print("\n🔹 Способ 2: Через прямое копирование файла")
    print("""
# На локальной машине:
scp backend_api/peers.py root@146.103.99.70:/srv/vpn-api/backend_api/

# Или скопируй весь backend_api:
scp -r backend_api/ root@146.103.99.70:/srv/vpn-api/

# Затем на сервере:
ssh root@146.103.99.70 << 'EOF'
cd /srv/vpn-api
systemctl restart vpn-api
systemctl status vpn-api
EOF
    """)
    
    print("\n🔹 Способ 3: Выполнить развертывание сейчас (если у вас есть SSH доступ)")
    print("""
# Сначала проверьте SSH доступ:
ssh root@146.103.99.70 "echo ✅ SSH работает"

# Если работает, выполните развертывание:
./deploy_backend.py --deploy
    """)
    
    # 6. Проверяем, передан ли флаг --deploy
    if "--deploy" in sys.argv:
        print("\n" + "=" * 70)
        print("⚠️  АВТОМАТИЧЕСКОЕ РАЗВЕРТЫВАНИЕ")
        print("=" * 70)
        
        # Копируем peers.py на сервер
        success, stdout, stderr = run_command(
            "scp -o StrictHostKeyChecking=no backend_api/peers.py root@146.103.99.70:/srv/vpn-api/vpn_api/peers.py",
            "Копируем peers.py на сервер"
        )
        
        if not success:
            print("[ERROR] Не удалось скопировать peers.py!")
            print(stderr)
            sys.exit(1)
        
        print("[OK] peers.py успешно скопирован")
        
        # Проверяем наличие .env.production локально
        env_file = ".env.production"
        if not os.path.exists(env_file):
            print(f"[WARN] {env_file} не найден локально - пропускаем загрузку")
        else:
            print(f"[OK] Найден {env_file} - загружаем на сервер")
            
            # Загружаем .env.production
            success, stdout, stderr = run_command(
                f"type {env_file} | ssh -o StrictHostKeyChecking=no root@146.103.99.70 \"cat > /tmp/.env.production.upload\"",
                "Загружаем .env.production на сервер"
            )
            
            if success:
                print("[OK] .env.production загружен")
                
                # Перемещаем и перезагружаем docker
                deploy_cmd = 'ssh -o StrictHostKeyChecking=no root@146.103.99.70 "cd /srv/vpn-api && mv /tmp/.env.production.upload .env.production && chmod 600 .env.production && echo \'[OK] .env.production готов\' && echo \'---\' && echo \'[*] Перезагружаем docker compose...\' && docker compose up -d --no-deps --build web && sleep 3 && echo \'---\' && echo \'[*] Статус контейнеров:\' && docker compose ps web"'
                
                success, stdout, stderr = run_command(
                    deploy_cmd,
                    "Перемещаем .env.production и перезагружаем docker"
                )
                
                if success:
                    print("[OK] Docker контейнер успешно перезагружен")
                    print(stdout)
                else:
                    print("[WARN] Возможны проблемы при перезагрузке docker:")
                    print(stdout)
                    if stderr:
                        print(stderr)
            else:
                print("[WARN] Не удалось загрузить .env.production")
                print(stderr)
        
        # Проверяем, работает ли API
        print("\n[*] Проверяем доступность API...")
        success, stdout, stderr = run_command(
            'ssh -o StrictHostKeyChecking=no root@146.103.99.70 "curl -s -m 5 http://localhost:8000/docs | head -c 100"',
            "Проверяем доступность API на localhost:8000"
        )
        
        if success and stdout:
            print("[OK] API доступен и работает")
        else:
            print("[INFO] API может еще инициализироваться (Docker restart может занять время)")
    
    else:
        print("\n💡 Чтобы выполнить развертывание автоматически, запустите:")
        print("   python deploy_backend.py --deploy")
    
    print("\n" + "=" * 70)
    print("✅ Скрипт завершен")
    print("=" * 70)

if __name__ == "__main__":
    main()
