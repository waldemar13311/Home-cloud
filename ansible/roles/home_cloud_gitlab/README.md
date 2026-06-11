# Ansible Role: Home Cloud GitLab

Эта Ansible-роль предназначена для развертывания и полной автоматической настройки **GitLab CE** и локального **GitLab Runner** (Docker-executor) в вашей домашней лаборатории или приватном облаке (Home Cloud).

Роль полностью идемпотентна, поддерживает фиксацию версий пакетов и не оставляет после себя временных токенов авторизации, используя системный токен регистрации.

## Особенности роли

* Гарантирует установку конкретных (зафиксированных) версий GitLab CE и GitLab Runner.
* Автоматически настраивает конфигурацию Omnibus пакета (`/etc/gitlab/gitlab.rb`).
* Ожидает полной готовности веб-интерфейса GitLab перед дальнейшими шагами.
* Безопасно настраивает детерминированный системный **Instance Runner Registration Token** через `gitlab-rails`.
* Автоматически регистрирует локальный Docker-раннер с пробросом корневых сертификатов (Root CA) для работы по HTTPS.

## Лицензия

This project is licensed under the **AGPL-3.0-or-later**.

## Требования

* **Минимальная версия Ansible:** `2.15`
* **Поддерживаемые ОС:**
  * Ubuntu 22.04 (Jammy)
  * Ubuntu 24.04 (Noble)
* **Пространство на диске:** Минимум 10-15 ГБ свободного места и от 4 ГБ оперативной памяти (рекомендуется 8 ГБ) на целевом хосте.

## Переменные роли (Variables)

Все основные переменные и версии зафиксированы в `defaults/main.yml`. Ниже приведены ключевые параметры, которые вы можете переопределить:

| Переменная | Значение по умолчанию | Описание |
| :--- | :--- | :--- |
| `home_cloud_gitlab_ce_version` | `"17.0.1-ce.0"` | Фиксированная версия пакета GitLab CE |
| `home_cloud_gitlab_runner_version` | `"17.0.1-1"` | Фиксированная версия GitLab Runner |
| `home_cloud_gitlab_external_url` | `"https://gitlab.home"` | Внешний URL вашего инстанса |
| `home_cloud_gitlab_https_enable` | `true` | Включение/выключение HTTPS |
| `home_cloud_gitlab_runner_registration_token` | `"hct-HomeCloudRunnerRegistrationToken123"` | Детерминированный системный токен регистрации воркеров |
| `home_cloud_gitlab_docker_runner_image` | `"docker:24-dind"` | Дефолтный образ для Docker-раннера |
| `home_cloud_gitlab_root_ca_crt_path` | `"/etc/ssl/certs/root_ca.crt"` | Путь к вашему Root CA для проброса в контейнеры |

## Структура задач роли (Tasks Structure)

Роль выполняет шаги в строгой и прозрачной последовательности:
1. `gitlab_install.yml` — Добавление официального репозитория и установка пакета GitLab CE нужной версии.
2. `gitlab_configure.yml` — Применение шаблона конфигурации и запуск `gitlab-ctl reconfigure`.
3. `setup_gitlab_registration_token.yml` — Безопасная инициализация системного токена регистрации через `gitlab-rails runner`.
4. `gitlab_runner_install.yml` — Установка зафиксированной версии `gitlab-runner`.
5. `gitlab_runner_registration.yml` — Проверка состояния и автоматическая регистрация Docker-раннера.

## Пример использования (Playbook Example)

```yaml
- hosts: gitlab_servers
  become: true
  roles:
    - role: waldemar13311.home_cloud_gitlab
      vars:
        home_cloud_gitlab_external_url: "http://gitlab.my-home.local"
        home_cloud_gitlab_runner_registration_token: "my-super-secure-token-xyz"
