# Generate a random database password instead of hard-coding one.
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "aws_db_instance" "database" {
  allocated_storage = 20
  engine            = "postgres" # NOTE: the engine name is "postgres", not "postgresql"
  engine_version    = "16"
  instance_class    = "db.t4g.micro" # current-gen Graviton burstable class
  identifier        = "${var.project}-db-instance"

  db_name  = "series"
  username = "series"
  password = random_password.password.result

  db_subnet_group_name   = var.vpc.database_subnet_group
  vpc_security_group_ids = [var.sg.db]
  skip_final_snapshot    = true
  storage_encrypted      = true

  # The generated password lands in the state file — protect the state (see the
  # backend / securing-state chapters later in this series).
}
