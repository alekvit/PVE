param(
    [Parameter(Mandatory=$true)]
    [string]$Target
)

$config = @{
    "github"  = @{ User = "alekvit"; Repo = "PVE"; Host = "github.com" }
    "gitverse" = @{ User = "alekvit"; Repo = "PVE"; Host = "gitverse.ru" }
}

if (-not $config.ContainsKey($Target)) {
    Write-Host "Неизвестный таргет: $Target. Доступные: $($config.Keys -join ', ')" -ForegroundColor Red
    exit 1
}

$c = $config[$Target]
$url = "git@$($c.Host):$($c.User)/$($c.Repo).git"

if (-not (Test-Path .git)) {
    Write-Host "Ошибка: текущая папка не является git-репозиторием." -ForegroundColor Red
    exit 1
}

# Проверяем, есть ли уже такой remote
$remotes = git remote
if ($remotes -contains $Target) {
    Write-Host "Remote '$Target' уже существует. Обновляем URL..." -ForegroundColor Cyan
    git remote set-url $Target $url
} else {
    Write-Host "Добавляем новый remote '$Target': $url" -ForegroundColor Cyan
    git remote add $Target $url
}

Write-Host "Готово. Текущие remotes:" -ForegroundColor Green
git remote -v
