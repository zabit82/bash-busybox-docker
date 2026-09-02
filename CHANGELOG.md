# Changelog

Все заметные изменения в сборочном процессе этого репозитория.

Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/).
Версионирование — [Semantic Versioning](https://semver.org/lang/ru/).

## [Unreleased]

### Изменено — `Dockerfile`

- **HTTPS + контрольная сумма загрузки.** Загрузка исходников bash и busybox
  переведена с `http://` на `https://`. Добавлена проверка целостности архивов
  через `sha256sum -c` перед распаковкой:
  - bash 5.2.37: `9599b22ecd1d5787ad7d3b7bf0c59f312b3396d1e281175dd1f8a4014da621ff`
  - busybox 1.37.0: `3311dff32e746499f4df0d5df04d7eb396382d7e108bb9250e7b519b837043a4`
- **Устойчивая загрузка `wget`**: добавлены повторы (`--tries=5`), таймаут
  (`--timeout=60`) и докачка прерванных файлов (`-c`). Актуально для
  нестабильного busybox.net, который периодически обрывает TLS-соединение.
- **Версии вынесены в `ARG`.** `DEB_BASE`, `BASH_VERSION`, `BASH_SHA256`,
  `BUSYBOX_VERSION`, `BUSYBOX_SHA256` задаются сверху файла — удобно
  переопределять из CI и корректно инвалидирует кеш слоёв.
- **Объединены `RUN`-инструкции.** `apt update` и `apt install` соединены в один
  слой с `--no-install-recommends`, после установки удаляется
  `/var/lib/apt/lists/*`.
- **Параллельная сборка.** `make` заменён на `make -j"$(nproc)"` в стадиях
  `build-bash` и `build-busybox`.
- **Убран лишний `cp -pr /tmp /relocate`** из стадии `reference` — в образ
  больше не попадает мусор из `/tmp` контейнера.
- **Добавлены метаданные `LABEL`** (`org.opencontainers.image.title` и
  `org.opencontainers.image.version`).
- **Исправлен сбой стадии `reference`**: Alpine выполняет `RUN` через
  busybox-ash, который не поддерживает brace expansion (`{a,b,c}`), из-за чего
  `cp` не находил файлы. Пути в `mkdir`/`cp` расписаны явно.
- **Исправлен сбой сборки BusyBox 1.37.0 на non-x86/ARM64**: отключены
  флаги `CONFIG_SHA1_HWACCEL` и `CONFIG_SHA256_HWACCEL`, вызывавшие ошибку
  компиляции из-за вызова x86-специфичных инструкций SHA-NI. Применение
  `CONFIG_STATIC=y` переведено на `sed` с последующим `yes "" | make oldconfig`.
- Добавлен заголовок `# syntax=docker/dockerfile:1`.

### Изменено — `.github/workflows/docker-image.yml`

- **Добавлено кеширование Buildx** (`cache-from: type=gha`, `cache-to: type=gha,mode=max,ignore-error=true`) — заметное
  ускорение повторных сборок и устойчивость к временным сбоям сервиса кеша GitHub.
- **Актуализированы версии GitHub Actions:** переход на стабильные релизы (`actions/checkout@v4`,
  `docker/login-action@v3`, `docker/setup-qemu-action@v3`, `docker/setup-buildx-action@v3`,
  `docker/build-push-action@v6`, `actions/attest-build-provenance@v2`).
- **Push ограничен только push-событиями.** На pull request теперь выполняется
  только сборка (без логина в Docker Hub и без `push: true`), чтобы в реестр не
  попадали мусорные теги вида `pr-*`.
- **Явные `permissions`:** добавлено `contents: read`.
