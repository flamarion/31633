terraform {
  required_version = ">= 0.12"
}

provider "google" {
  credentials = file("~/.config/gcloud/key.json")
  project     = "flamarion"
  region      = "europe-west4"
  zone        = "europe-west4-a"
  version     = "~> 3.32"
}

resource "google_sql_database_instance" "master" {
  name             = "master"
  database_version = "POSTGRES_11"

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled = true
    }
    backup_configuration {
      enabled            = true
      #binary_log_enabled = true
    }
    availability_type = "ZONAL"
  }
}

resource "google_sql_database" "default" {
  depends_on = [google_sql_database_instance.master]
  name       = "my_db"
  instance   = google_sql_database_instance.master.name
}

resource "google_sql_user" "default" {
  depends_on = [google_sql_database.default]
  name       = "flamarion"
  instance   = google_sql_database_instance.master.name
  password   = "SuperS3cret"
}


resource "google_sql_database_instance" "failover_replica" {
  depends_on = [
    google_sql_database_instance.master,
    google_sql_database.default,
    google_sql_user.default,
  ]

  name             = "master-failover"
  database_version = "POSTGRES_11"

  # The name of the instance that will act as the master in the replication setup.
  master_instance_name = google_sql_database_instance.master.name

  replica_configuration {
    # Specifies that the replica is the failover target.
    failover_target = true
  }
  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled = true
    }
    backup_configuration {
      enabled            = true
      #binary_log_enabled = true
    }
    availability_type = "ZONAL"
  }
}


output "master_instance_name" {
  description = "The name of the master database instance"
  value       = google_sql_database_instance.master.name
}

output "master_public_ip_address" {
  description = "The public IPv4 address of the master instance."
  value       = google_sql_database_instance.master.public_ip_address
}

output "db" {
  description = "Self link to the default database"
  value       = google_sql_database.default.self_link
}

output "db_name" {
  description = "Name of the default database"
  value       = google_sql_database.default.name
}

output "failover_instance_name" {
  description = "The name of the failover database instance"
  value       = join("", google_sql_database_instance.failover_replica.*.name)
}

output "failover_public_ip_address" {
  description = "The public IPv4 address of the failover instance."
  value       = join("", google_sql_database_instance.failover_replica.*.public_ip_address)
}
