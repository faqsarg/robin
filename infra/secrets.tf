resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "db" {
  name = "${var.project_name}/db-credentials"
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = "robin"
    password = random_password.db.result
    host     = aws_db_instance.main.address
    port     = "5432"
    dbname   = "robin"
  })
}
