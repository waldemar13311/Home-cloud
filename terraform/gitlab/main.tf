##### Настройки пользователя
# Ищем системного пользователя root по его юзернейму
data "gitlab_user" "root" {
  username = "root"
}

# Устанавливаем ему аватарку
resource "gitlab_user_avatar" "root_avatar" {
  user_id = data.gitlab_user.root.id
  avatar  = "${path.module}/files/Profile.jpg"
}

# Добавляем SSH-ключ для root
resource "gitlab_user_sshkey" "root_ssh_key" {
  user_id = data.gitlab_user.root.id
  title   = "Admin SSH Key"
  key     = file("~/.ssh/id_ed25519.pub")
}
