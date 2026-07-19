output "config" {
  value = {
    user     = aws_db_instance.database.username
    password = aws_db_instance.database.password
    database = aws_db_instance.database.db_name
    hostname = aws_db_instance.database.address
    port     = aws_db_instance.database.port
  }
  sensitive = true
}
