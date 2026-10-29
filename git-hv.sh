#!/usr/bin/env bash

set -e

target="$1"

# --- НАСТРОЙКА: user и repo для каждой площадки ---
declare -A user
declare -A repo

user["github"]="alekvit"
repo["github"]="PVE"

user["gitverse"]="alekvit"
repo["gitverse"]="PVE"

# user["gitlab"]="my-gitlab-user"
# repo["gitlab"]="my-repo"

if [[ -z "${user[$target]}" || -z "${repo[$target]}" ]]; then
  echo "Неизвестный таргет: $target. Доступные: ${!user[@]}" >&2
  exit 1
fi

# Формируем URL через case — удобно добавлять новые площадки
case "$target" in
  "github")
    url="git@github.com:${user[$target]}/${repo[$target]}.git"
    ;;
  "gitlab")
    url="git@gitlab.com:${user[$target]}/${repo[$target]}.git"
    ;;
  "gitverse")
    url="git@gitverse.ru:${user[$target]}/${repo[$target]}.git"
    ;;
  *)
    echo "Неподдерживаемая площадка: $target" >&2
    exit 1
    ;;
esac

# Проверка git-репозитория
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Ошибка: текущая папка не является git-репозиторием." >&2
  exit 1
fi

# echo "Меняем remote origin на: ${url%:*@*}"
# git remote set-url origin "$url"

# Логика: если remote с таким именем уже есть — обновляем URL, если нет — добавляем
if git remote | grep -q "^${target}$"; then
  echo "Remote '$target' уже существует. Обновляем URL..."
  git remote set-url "$target" "$url"
else
  echo "Добавляем новый remote '$target': $url"
  git remote add "$target" "$url"
fi

echo "Готово. Проверка (токен скрыт):"
git remote -v | sed 's/:.*@/:***@/'
