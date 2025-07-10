#!/bin/bash

# Параметры (передаются при запуске)
VAGRANT_REPO=$1
ANSIBLE_REPO=$2

# Проверка входных данных
[ -z "$VAGRANT_REPO" ] || [ -z "$ANSIBLE_REPO" ] && { echo "Usage: $0 <vagrant_repo_url> <ansible_repo_url>"; exit 1; }

# Временная директория
WORK_DIR="/tmp/infra_deploy"

if [ ! -d "$WORK_DIR" ]; then
    mkdir -p "$WORK_DIR"
fi


cd "$WORK_DIR" || exit 1

# Функция для обработки ошибок
fail() { echo "Error: $1" >&2; exit 1; }

# 1. Клонируем и выполняем Vagrant репозиторий
echo "=== Cloning Vagrant repo ==="

if [ ! -d "vagrant/.git" ] || \
   [ "$(git -C vagrant config --get remote.origin.url)" != "$VAGRANT_REPO" ]; then
    git clone "$VAGRANT_REPO" vagrant || fail "Failed to clone vagrant repo"
fi



cd vagrant || exit

echo "=== Starting Vagrant VMs ==="
# Очистка предыдущего состояния
cleanup_vagrant() {
    echo "Cleaning up previous Vagrant environment..."
    sudo pkill -9 -f "VBox" || true
    sudo pkill -9 -f "vagrant" || true
    sudo systemctl restart vboxdrv vboxnetadp vboxnetflt 2>/dev/null || true

    vboxmanage list vms | awk '/node[1-3]/ {gsub(/[{}]/, "", $2); system("vboxmanage controlvm "$2" poweroff 2>/dev/null || true; vboxmanage unregistervm "$2" --delete 2>/dev/null || true")}'
    
    sudo rm -rf \
        ~/"VirtualBox VMs/node"* \
        /tmp/.vbox-*-ipc \
        ~/.config/VirtualBox/* \
        ~/.vagrant.d/tmp/*
        
    vagrant global-status --prune
    rm -rf .vagrant/
    unset VAGRANT_CWD
    sleep 5
}
cleanup_vagrant



echo "=== Запускаю ВМ ==="
# Запуск ВМ
vagrant up || fail "Vagrant up failed"


sync_vagrant_metadata() {
    echo "=== Синхронизация метаданных Vagrant ==="
    cd "$WORK_DIR" || exit 1
    chmod 755 "$WORK_DIR"
    # Принудительно обновляем глобальный статус
    vagrant global-status --prune
    echo "Создаём ~/.vagrant_env с содержимым:"
    echo "export VAGRANT_CWD=\"$WORK_DIR\""
    echo "alias vstatus=\"cd $WORK_DIR && vagrant status\""
    cat > ~/.vagrant_env <<EOF
export VAGRANT_CWD="$WORK_DIR"
alias vstatus="cd $WORK_DIR && vagrant status"
EOF


    if ! grep -qF "source ~/.vagrant_env" ~/.bashrc; then
        echo "source ~/.vagrant_env" >> ~/.bashrc
    fi

    # Применяем сразу
    source ~/.vagrant_env

    echo "VAGRANT_CWD установлен в: $WORK_DIR"
    echo "Теперь можешь использовать команду 'vstatus' в любом терминале"
    
    # Проверка
    echo "Текущий контекст:"
    cd "$WORK_DIR" && vagrant status
}

# Фиксируем состояние (если нужно)
sync_vagrant_metadata




echo "=== Готово! Состояние ВМ: ==="
cd "$WORK_DIR" && vagrant status


# 2. Клонируем и выполняем Ansible репозиторий
echo "=== Cloning Ansible repo ==="
cd "$WORK_DIR" || exit

if [ ! -d "vagrant/.git" ] || \
   [ "$(git -C vagrant config --get remote.origin.url)" != "$ANSIBLE_REPO" ]; then
    git clone "$ANSIBLE_REPO" vagrant || fail "Failed to clone Ansible repo"
fi


echo "=== Running Ansible playbook ==="
ansible-playbook -i hosts.ini playbook1.yml || fail "Ansible playbook failed"

echo "=== Deployment completed successfully ==="

