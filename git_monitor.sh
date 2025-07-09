#!/bin/bash

REPO_DIR="."
COMMAND_TO_RUN="./deploy-infra.sh git@github.com:soldatviktimnosti/VagrantMachine.git git@github.com:soldatviktimnosti/ansible.git"

cd "$REPO_DIR" || exit 1

echo "=== Мониторинг запущен ==="
echo "Репо: $(pwd)"
echo "Ветка: $(git branch --show-current)"
echo "Origin URL: $(git remote get-url origin)"
echo "========================="

# Инициализация - запоминаем последний обработанный коммит
LAST_PROCESSED=$(git rev-parse origin/main)

while true; do
    echo -n "$(date) - Проверка изменений... "

    # Обновляем информацию о удалённом репозитории
    git fetch origin >/dev/null 2>&1

    # Получаем текущий коммит в удалённой ветке
    CURRENT_REMOTE=$(git rev-parse origin/main)

    if [ "$LAST_PROCESSED" != "$CURRENT_REMOTE" ]; then
        echo "Обнаружены новые коммиты!"
        echo "Последний обработанный: $(git log -1 --pretty='%h %s' $LAST_PROCESSED)"
        echo "Текущий удалённый:     $(git log -1 --pretty='%h %s' $CURRENT_REMOTE)"

        # Выполняем команду
        echo "Выполняю: $COMMAND_TO_RUN"
        if eval "$COMMAND_TO_RUN"; then
            # Если команда выполнена успешно - обновляем последний обработанный коммит
            LAST_PROCESSED=$CURRENT_REMOTE
            echo "Успешно выполнено. Теперь отслеживаем коммит: $LAST_PROCESSED"
        else
            echo "Ошибка выполнения команды! Повторная попытка через 1 минуту."
        fi
    else
        echo "Изменений нет (последний коммит: $(git log -1 --pretty='%h %s' $LAST_PROCESSED))"
    fi

    sleep 60
done

