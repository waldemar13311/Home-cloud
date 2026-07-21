# Переменные
# URL до gitlab сервера
variable "gitlab_url" {
  type        = string
  default     = "https://gitlab.home"
}

# id проекта, к которому хотим выдать доступ
variable "gitlab_project_id" {
  type        = string
  default     = "10" # тут нужно на свой проект заменить
}
