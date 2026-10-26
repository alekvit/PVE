#!/usr/bin/env bash

# cat /usr/local/bin/update-traefik.sh 

# Приложение обновляет Traefik до последней версии из GitHub Release

# Исполнитель: Александр Витальевич
# Площадки: [GitHub](https://github.com/alekvit), [GitVerse](https://gitverse.ru/alekvit), [личный сайт](https://зодчий.москва)
# Лицензия: MIT — бери и применяй!
# SPDX-License-Identifier: MIT
# Просьба: сохранять упоминание об исполнителе.

# требования:
# ОС: linux
# "curl" "jq" "tar" "sha256sum" "file"

# ===============================================
# 1. ОБЩИЕ ПОСТОЯННЫЕ/ПЕРЕМЕННЫЕ И НАСТРОЙКИ
# ===============================================

# Включаем строгий режим сразу:
# -e: выход при любой ошибке
# -o pipefail: ошибка в "стволе" ломает исполнение приложения
# Это защищает от "тихих" сбоев в начале
set -eo pipefail

# --- Объявление переменных среды ---

# Пути
LOG_FILE="/var/log/traefik/traefik-updater.log"
BINARY_PATH="/usr/local/bin/traefik"
BACKUP_PATH="/usr/local/bin/traefik.bak"
LATEST_API_URL="https://api.github.com/repos/traefik/traefik/releases/latest"

# Цвета для вывода информации
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Переменные среды
TMP_DIR=""
CURRENT_VERSION=""
# SERVICE_NAME=""

# --- Функции логирования ---
log() {
    local msg
    msg="[$(date '+%H:%M:%S')] $1"
    echo -e "${GREEN}$msg${NC}"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

warn() {
    local msg
    msg="[$(date '+%H:%M:%S')] $1"
    echo -e "${YELLOW}$msg${NC}"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

error_exit() {
    local msg
    msg="[$(date '+%H:%M:%S')] $1"
    echo -e "${RED}$msg${NC}" >&2
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
    
    # Очистка при ошибке (удалить временную папку, игнорируя ошибки удаления)
    rm -rf "$TMP_DIR" 2>/dev/null || true
    exit 1
}

info() {
    local msg
    msg="[$(date '+%H:%M:%S')] $1"
    echo -e "${BLUE}$msg${NC}"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}


# --- Функция сравнения версий (ОБЯЗАТЕЛЬНО ЗДЕСЬ, ДО ЛЮБОГО ИСПОЛЬЗОВАНИЯ) ---
# Возвращает 0 (true), если $1 >= $2
version_greater_equal() {
    # local ver_a=(${1//./ })
    # local ver_b=(${2//./ })
    local -a ver_a
    IFS=. read -ra ver_a <<< "$1"
    local -a ver_b
    IFS=. read -ra ver_b <<< "$2"
    for ((i=0; i<3; i++)); do
        a=${ver_a[i]:-0}
        b=${ver_b[i]:-0}
        if (( a < b )); then return 1; fi
        if (( a > b )); then return 0; fi
    done
    return 0
}


# ==========================================
# 2. ПРОВЕРКА ОС И ПРАВ "ROOT"
# ==========================================


# Проверка типа ОС: приложения работает ТОЛЬКО на Linux
OS_TYPE=$(uname -s)
if [[ "$OS_TYPE" != "Linux" ]]; then
    echo -e "${RED}[ERROR] Это приложение предназначен исключительно для Linux.${NC}"
    echo "Вы запустили его на системе: $OS_TYPE."
    echo ""
    
	case "$OS_TYPE" in
        "Darwin")
            echo "Для macOS используйте: brew install traefik"
            ;;
        "FreeBSD"|"OpenBSD")
            echo "Для BSD используйте: pkg install traefik"
            ;;
        *)
            # Сюда попадут MSYS2 (MINGW64), Cygwin и др.
            echo "Это не чистый Linux-дистрибутив."
            echo "В вашей среде пакеты ставятся иначе (например, pacman в MSYS2)."
            echo "Пожалуйста, используйте родной менеджер пакетов вашей среды."
            ;;
    esac

    exit 1
fi

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
    error_exit "Требуется запуск с правами root. Примените команду: sudo ./update-traefik.sh"
fi

log "✅ Тип ОС подтвержден: $OS_TYPE (Linux)"

# Создаем папку для отчетов ТОЛЬКО ПОСЛЕ проверки прав root
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || error_exit "Возникла ошибка при создании папки для отчетов: $(dirname "$LOG_FILE")"
log "📁 Папка для отчетов готова: $LOG_FILE"


# ===================================================
# 3. ПРОВЕРКА И АВТОМАТИЧЕСКАЯ УСТАНОВКА ЗАВИСИМОСТЕЙ
# ===================================================

# --- Функция выполнения проверки установленных программ
# check_dependencies
# --- Функция проверки и установки программ
# check_and_install_dependencies

check_dependencies() { 
    local missing=() 
    
    # Список необходимых утилит 
    local tools=("curl" "jq" "tar" "sha256sum" "file") 
    
    # Проверяем наличие каждой утилиты 
    for tool in "${tools[@]}"; do 
        if ! command -v "$tool" &> /dev/null; then 
            missing+=("$tool") 
        fi 
    done 
    
    # Если список зависимостей пуст (например, tools не объявлен), выходим 
    if [[ -z "${tools[*]:-}" ]]; then 
        echo "⚠️ Список необходимых утилит (tools) не определен." 
        return 1 
    fi 
    
    # Если все зависимости на месте — сообщаем об успехе 
    if [[ ${#missing[@]} -eq 0 ]]; then 
        echo "✅ Все зависимости (${tools[*]}) найдены." 
        return 0 
    fi 
    
    # Если чего-то не хватает — выводим подробную инструкцию 
    echo "⚠️ Обнаружены отсутствующие утилиты: ${missing[*]}" 
    echo "" 
    echo "Для работы приложения необходимо установить их вручную." 
    echo "" 
    
    # Определяем менеджер пакетов только для вывода подсказки 
    local pkg_hint="(не определен)" 
    if command -v apk &> /dev/null; then 
        pkg_hint="Alpine (apk)" 
    elif command -v apt-get &> /dev/null || [[ -f /etc/debian_version ]]; then 
        pkg_hint="Debian/Ubuntu (apt)" 
    elif command -v dnf &> /dev/null; then 
        pkg_hint="Fedora/RHEL (dnf)" 
    elif command -v yum &> /dev/null; then 
        pkg_hint="CentOS/RHEL (yum)" 
    fi 
    
    echo "💡 Подсказка для вашей системы (${pkg_hint}):" 
    echo "" 
    
    case "$pkg_hint" in 
        "Alpine (apk)") 
            echo " apk update" 
            echo " # Утилиты могут быть в разных пакетах, например:" 
            echo " apk add curl jq tar coreutils file" 
            ;; 
        "Debian/Ubuntu (apt)") 
            echo " apt update" 
            echo " apt install -y ${missing[*]}" 
            ;; 
        "Fedora/RHEL (dnf)") 
            echo " dnf check-update" 
            echo " dnf install -y ${missing[*]}" 
            ;; 
        "CentOS/RHEL (yum)") 
            echo " yum check-update" 
            echo " yum install -y ${missing[*]}" 
            ;; 
        "(не определен)") 
            echo "❌ Не удалось определить менеджер пакетов (apk, apt, dnf или yum)." 
            echo "" 
            echo "Вам нужно установить утилиты вручную, подходящие для вашего дистрибутива:" 
            echo "" 
            echo "Примеры для популярных систем:" 
            echo " Arch Linux: pacman -S ${missing[*]}" 
            echo " openSUSE: zypper install ${missing[*]}" 
            echo " NixOS: nix-env -iA ${missing[*]}" 
            echo " macOS (brew): brew install ${missing[*]}" 
            echo "" 
            echo "Если вашей ОС нет в списке, найдите в поисковике: 'как установить ${missing[*]} в <название_вашей_ОС>'" 
            ;; 
        *) 
            # Фоллбэк на случай, если переменная содержит неожиданные символы 
            echo "⚠️ Состояние менеджера пакетов не распознано: '$pkg_hint'" 
            echo "Попробуйте установить вручную: ${missing[*]}" 
            ;; 
    esac

    echo "" 
    echo "После установки отсутствующих полезнушек перезапустите приложение." 
    
    # Завершаем работу с ошибкой, так как дальнейшая работа невозможна 
    return 1 
}


check_and_install_dependencies() {
    local missing=()
    
    # Список необходимых утилит
    local tools=("curl" "jq" "tar" "sha256sum" "file")
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [[ ${#missing[@]} -eq 0 ]]; then
        log "✅ Все зависимости установлены."
        return 0
    fi

    warn "⚠️ Программа обновления требует наличия следующих полезнушек: ${missing[*]}. Начинается автоматическая установка..."
    echo ""

    local pkg_cmd=""
    local install_cmd=""
    local update_cmd=""
    local fix_cmd=""

    # 1. Проверка Alpine (apk) - приоритет, так как часто в контейнерах
    if command -v apk &> /dev/null; then
        pkg_cmd="apk"
        update_cmd="apk update"
        fix_cmd="apk fix" # В Alpine нет классического fix broken, но apk сам чинит зависимости при установке
    # 2. Проверка Debian/Ubuntu (apt)
    elif command -v apt-get &> /dev/null || [[ -f /etc/debian_version ]]; then
        pkg_cmd="apt"
        update_cmd="apt update"
        fix_cmd="apt -f install"
    # 3. Проверка Fedora/RHEL8+ (dnf)
    elif command -v dnf &> /dev/null; then
        pkg_cmd="dnf"
        update_cmd="dnf makecache"
        fix_cmd="dnf autoremove"
    # 4. Проверка CentOS7/RHEL7 (yum)
    elif command -v yum &> /dev/null; then
        pkg_cmd="yum"
        update_cmd="yum makecache"
        fix_cmd="yum resolve-deps"
    else
        # pkg_cmd="unknown"
        error_exit "❌ Не удалось определить менеджер пакетов. Невозможно установить зависимости автоматически."
    fi


    case "$pkg_cmd" in
        "apk")
            echo "🐳 Система: Alpine Linux (apk)"
            echo ""
            echo "Команда установки:"
            echo "  ${update_cmd} && apk add ${missing[*]}"
            echo ""
            echo "Примечание: В Alpine утилиты могут быть в разных пакетах."
            echo "Например, sha256sum находится в coreutils, file в file."
            ;;
        "apt")
            echo "🐧 Система: Debian/Ubuntu (apt)"
            echo ""
            echo "Быстрый вариант:"
            echo "  apt install -y ${missing[*]}"
            echo ""
            echo "Если пакеты не найдены или есть ошибки зависимостей:"
            echo "  ${update_cmd} && apt install -y ${missing[*]}"
            echo "  # Если ошибка зависимостей: ${fix_cmd}"
            ;;
        "dnf")
            echo "🐄 Система: Fedora/RHEL (dnf)"
            echo ""
            echo "Рекомендуемая команда:"
            echo "  ${update_cmd} && dnf install -y ${missing[*]}"
            ;;
        "yum")
            echo "🐂 Система: CentOS 7 (yum)"
            echo ""
            echo "Рекомендуемая команда:"
            echo "  ${update_cmd} && yum install -y ${missing[*]}"
            ;;
        *)
            echo "⚠️ Не удалось определить менеджер пакетов."
            echo "Вам нужно установить вручную: ${missing[*]}"
            echo ""
            echo "Примеры для разных систем:"
            echo "  Alpine:       apk add <пакет>"
            echo "  Debian/Ubuntu: apt install <пакет>"
            echo "  RHEL/Fedora:  dnf install <пакет>"
            ;;
    esac
    
    # echo ""
    # error_exit "Установка невозможна без этих утилит."

    info "📦 Обнаружена система: $pkg_cmd. Выполняю установку..."
    
    # Выполнение установки
    if eval "$update_cmd" && eval "$install_cmd ${missing[*]}"; then
        log "✅ Зависимости успешно установлены."
    else
        error_exit "❌ Ошибка при автоматической установке зависимостей через $pkg_cmd"
    fi
}

# check_dependencies
check_and_install_dependencies

# ==========================================
# 4. ОПРЕДЕЛЕНИЕ АРХИТЕКТУРЫ
# ==========================================

# --- Автоматическое определение архитектуры ---
ARCH=""
case "$(uname -m)" in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        # Если архитектура неизвестна, скрипт сразу падает с понятным сообщением
        error_exit "Неподдерживаемая архитектура: $(uname -m). Приложение поддерживает установку целевого ПО только для архитектуры системы: amd64 и arm64."
        ;;
esac

log "🖥️ Определена архитектура системы: $ARCH"

TMP_DIR=$(mktemp -d)
mkdir -p "$(dirname "$BINARY_PATH")" 2>/dev/null || true

# ==========================================
# 5. ПРОВЕРКА ТЕКУЩЕЙ ВЕРСИИ
# ==========================================

# --- Получение текущей установленной версии ---
if [[ -f "$BINARY_PATH" ]]; then
    RAW_VER=$($BINARY_PATH version --short 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)
    CURRENT_VERSION=${RAW_VER:-unknown}
    log "Текущая версия Traefik: $CURRENT_VERSION"
else
    warn "📦 Traefik не найден по пути $BINARY_PATH. Будет выполнена чистая установка."
fi

# =============================================
# 5. ЗАПРОС К GITHUB API И ПРОВЕРКА НА ЧЕРНОВИК
# =============================================

# --- Запрос последней версии через GitHub API ---
info "🌐 Запрос к GitHub API для получения последней версии..."
LATEST_JSON=$(curl -s --retry 3 --retry-delay 2 "$LATEST_API_URL") || error_exit "Ошибка запроса к GitHub API"

# ВАЖНО: Проверка, не вернул ли GitHub ошибку (например, Rate Limit)
if echo "$LATEST_JSON" | grep -q '"message"' || [[ -z "$LATEST_JSON" ]]; then
    error_exit "Ошибка GitHub API. Ответ: $LATEST_JSON"
fi

IS_DRAFT=$(echo "$LATEST_JSON" | jq -r '.draft // false')
if [[ "$IS_DRAFT" == "true" ]]; then
    warn "⚠️ Последний релиз помечен как ЧЕРНОВИК (Draft). Пропускаем его."
    rm -rf "$TMP_DIR"
    exit 0
fi

TARGET_TAG=$(echo "$LATEST_JSON" | jq -r '.tag_name // empty')
if [[ -z "$TARGET_TAG" || "$TARGET_TAG" == "null" ]]; then
    error_exit "Не удалось распарсить tag_name из ответа API."
fi

TARGET_CLEAN="${TARGET_TAG#v}"
log "🚀 Последняя доступная версия: $TARGET_CLEAN"


# --- Сравнение версий ---
if [[ "$CURRENT_VERSION" != "unknown" ]]; then
    if version_greater_equal "$CURRENT_VERSION" "$TARGET_CLEAN"; then
        log "✅ У вас уже установлена актуальная версия ($CURRENT_VERSION >= $TARGET_CLEAN). Обновление не требуется."
        rm -rf "$TMP_DIR"
        exit 0
    else
        log "⬇️ Доступна новая версия: $TARGET_CLEAN (у вас $CURRENT_VERSION)"
    fi
fi


# =========================================================================================
# 6. ПОИСК (запрос заголовков HEAD), СКАЧИВАНИЕ, ПРОВЕРКА СУЩЕСТВОВАНИЯ И РАСПАКОВКА АРХИВА
# =========================================================================================

DOWNLOAD_URL=""
ARCHIVE_NAME=""

CHECKSUM_URL=""

EXPECTED_SHA="" 
EXPECTED_SHA_URL=""

# 1. Находим URL архива для нашей архитектуры

# Получаем список всех ассетов (имена и URL)
ASSETS_LIST=$(echo "$LATEST_JSON" | jq -r '.assets[] | "\(.name)|\(.browser_download_url)"')

# Ищем файл, содержащий: linux_${ARCH} и заканчивающийся на .tar.gz
# while IFS='|' read -r asset_name asset_url; do
while IFS= read -r line; do
    # Разбиваем строку "name|url"
    asset_name=$(echo "$line" | cut -d'|' -f1)
    asset_url=$(echo "$line" | cut -d'|' -f2)
    # Проверка: содержит ли имя нужную архитектуру и является ли tar.gz
    if [[ "$asset_name" == *"linux_${ARCH}"* ]] && [[ "$asset_name" == *.tar.gz ]]; then
        # Дополнительная страховка: убедимся, что это именно бинарник, а не что-то лишнее
        if [[ "$asset_name" == traefik* ]]; then
            DOWNLOAD_URL="$asset_url"
            ARCHIVE_NAME="$asset_name"
            log "💾 Найден архив: $asset_name"
            break
        fi
    fi
done <<< "$ASSETS_LIST"

if [[ -z "$DOWNLOAD_URL" ]]; then
    error_exit "Не удалось найти архив для архитектуры $ARCH в списке релизов. Проверьте страницу релизов вручную."
fi

# 2. Ищем файл checksums.txt в assets
CHECKSUM_URL=$(echo "$LATEST_JSON" | jq -r '.assets[] | select(.name == "traefik_v'"$TARGET_CLEAN"'_checksums.txt") | .browser_download_url')

if [[ -z "$CHECKSUM_URL" || "$CHECKSUM_URL" == "null" ]]; then
    error_exit "❌ Критическая ошибка: не найден файл checksums.txt для версии $TARGET_CLEAN. Без проверки целостности установка невозможна."
fi

log "🔐 Скачивание файла контрольных сумм: checksums.txt..."
cd "$TMP_DIR"
curl -s -L -o "checksums.txt" "$CHECKSUM_URL" || error_exit "Ошибка скачивания checksums.txt"

# 3. Извлекаем SHA256 именно для нашего файла
EXPECTED_SHA=$(grep "$ARCHIVE_NAME" "checksums.txt" | awk '{print $1}')

if [[ -z "$EXPECTED_SHA" ]]; then
    error_exit "❌ Ошибка проверки: хеш для файла '$ARCHIVE_NAME' не найден в checksums.txt. Возможно, файл повреждён или версия не соответствует."
fi

log "🔐 Ожидаемый SHA256 для $ARCHIVE_NAME: $EXPECTED_SHA"

cd "$TMP_DIR"

# --- 4. Скачивание архива... ---
log "⬇️ Скачивание $DOWNLOAD_URL..."
    # --fail гарантирует ошибку при 404
    # -o явно задаёт имя файла. 
curl -L --fail --progress-bar -o "$ARCHIVE_NAME" "$DOWNLOAD_URL" || error_exit "Скачивание завершилось с ошибкой (код возврата curl)"

# ПРОВЕРКА 1: Файл существует и не пустой?
if [[ ! -f "$ARCHIVE_NAME" ]] || [[ $(stat -c%s "$ARCHIVE_NAME") -eq 0 ]]; then
    error_exit "Файл $ARCHIVE_NAME не был создан после скачивания или пуст (размер 0 байт). Возможно, это ошибка сервера!"
fi

# ПРОВЕРКА 2: Проверка типа файла (gzip)?
if ! file "$ARCHIVE_NAME" | grep -qi "gzip compressed"; then
    warn "Скачанный файл НЕ является gzip-архивом. Скорее всего, это HTML-страница с ошибкой от GitHub."
    # Используем cat, чтобы точно увидеть текст, даже если head ругается
    # warn "Вывод первых 200 символов содержимого файла:"
    head -c 200 "$ARCHIVE_NAME" || echo "(не удалось прочитать содержимое)"
    error_exit "Прервано: файл не является правильным архивом."
fi

log "✅ Скачаный архив успешно проверен."

# --- 5. Считаем реальный хеш и сравниваем ---
CALCULATED_SHA=$(sha256sum "$ARCHIVE_NAME" | awk '{print $1}')

if [[ "$CALCULATED_SHA" != "$EXPECTED_SHA" ]]; then
    log "❌ НЕСОВПАДЕНИЕ КОНТРОЛЬНЫХ СУММ!"
    log "Ожидалось: $EXPECTED_SHA"
    log "Получено:   $CALCULATED_SHA"
    error_exit "Целостность файла нарушена. Установка прервана."
else
    log "✅ SHA256 подтвержден. Файл не повреждён."
fi

# --- Распаковка и проверка содержимого ---
log "📦 Распаковка архива: $ARCHIVE_NAME..."
tar xzf "$ARCHIVE_NAME" || error_exit "❌ Не удалось распаковать архив (ошибка tar). Проверьте целостность файла."

log "✅ Архив успешно распакован."

[[ -f "./traefik" ]] || error_exit "❌ Двоичный файл 'traefik' не найден внутри архива. Структура архива нарушена."
log "✅ Найден исполняемый файл: ./traefik"

# ==========================================
# 8. УСТАНОВКА И ПРОВЕРКА
# ==========================================
# --- Установка ---
log "💾 Создание резервной копии текущего бинарника..."
cp -a "$BINARY_PATH" "$BACKUP_PATH" 2>/dev/null || warn "Не удалось создать резервную копию (файл мог отсутствовать)"

log "🚚 Установка новой версии..."
mv "./traefik" "$BINARY_PATH"
# chmod +x "$BINARY_PATH"
chmod 755 "$BINARY_PATH" "$BACKUP_PATH"
chown root:root "$BINARY_PATH" "$BACKUP_PATH"

# --- Заключительная проверка ---
NEW_RAW_VER=$($BINARY_PATH version --short 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)
NEW_VERSION=${NEW_RAW_VER:-failed}

if ! version_greater_equal "$NEW_VERSION" "$TARGET_CLEAN"; then
    error_exit "❌ Критическая ошибка установки. Целевая: $TARGET_CLEAN, текущая после установки: $NEW_VERSION"
fi

log "✅ Успешно обновлено до Traefik $NEW_VERSION"
rm -rf "$TMP_DIR"

# Автоматический перезапуск службы (без запроса ввода)
if systemctl is-active --quiet traefik.service 2>/dev/null; then
    log "🔄 Перезапуск службы traefik.service..."
    
    if systemctl restart traefik.service; then
        sleep 2
        
        if systemctl is-active --quiet traefik.service; then
            log "✅ Служба traefik.service успешно перезапущена."
        else
            warn "⚠️ Служба выключена после перезапуска. Попытка исправить..."
            systemctl daemon-reload

            if systemctl restart traefik.service; then
                log "✅ Исправлено: служба перезапущена приёмом daemon-reload."
            else
                error_exit "❌ Не удалось перезапустить службу даже после daemon-reload. Проверьте journalctl -u traefik.service"
            fi
        fi
    else
        warn "⚠️ Ошибка команды systemctl restart. Пытаемся daemon-reload..."
        systemctl daemon-reload
        
        if systemctl restart traefik.service; then
            log "✅ Исправлено через daemon-reload."
        else
            error_exit "❌ Не удалось восстановить работу службы."
        fi
    fi
else
    warn "ℹ️ Служба traefik.service не активна (возможно, это контейнер или ручная установка). Пропущен перезапуск."
fi

# --- ДОПОЛНИТЕЛЬНЫЙ БЛОК: АВТО-СТАРТ, ЕСЛИ СЛУЖБА БЫЛА ОСТАНОВЛЕНА ---
if systemctl is-enabled --quiet traefik.service 2>/dev/null; then
    if ! systemctl is-active --quiet traefik.service 2>/dev/null; then
        log "🆙 Служба была неактивна. Пытаюсь запустить её после обновления..."
        if systemctl start traefik.service; then
            sleep 2
            if systemctl is-active --quiet traefik.service; then
                log "✅ Служба успешно запущена."
            else
                warn "⚠️ Служба не запустилась. Проверьте journalctl -u traefik.service"
            fi
        else
            warn "❌ Не удалось выполнить systemctl start."
        fi
    fi
else
    warn "ℹ️ Служба не включена (disabled) в systemd. Авто-старт пропущен."
fi

rm -rf "$TMP_DIR"

# ==========================================
# 9. ИТОГОВЫЙ ОТЧЁТ 
# ==========================================
echo ""
echo "=========================================="
echo "📋 ИТОГОВЫЙ ОТЧЁТ ОБНОВЛЕНИЯ"
echo "=========================================="

# Вывод версии
echo ""
echo "Версия Traefik:"
"$BINARY_PATH" version

# Вывод статуса службы
echo ""
echo "Статус службы traefik.service:"
systemctl status traefik --no-pager 2>/dev/null || echo "Служба не найдена или не управляется systemd (возможно, это WSL/Alpine/container)."

echo "=========================================="
echo "🎉 Обновление завершено!"
echo "=========================================="