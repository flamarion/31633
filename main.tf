terraform {
  required_version = ">= 0.12"
}

provider "google" {
  # credentials = file("~/.config/gcloud/key.json")
  version     = "~> 3.32"
}

provider "google-beta" {
  # credentials = file("~/.config/gcloud/key.json")
  version     = "~> 3.32"
}

resource "random_id" "name" {
  byte_length = 2
}

# ------------------------------------------------------------------------------
# CREATE THE MASTER INSTANCE
#
# NOTE: We have multiple google_sql_database_instance resources, based on
# HA and replication configuration options.
# ------------------------------------------------------------------------------

resource "google_sql_database_instance" "master" {

  provider         = google-beta
  # name             = "master-${random_id.name.hex}"
  project          = "flamarion"
  region           = "europe-west4"
  database_version = "POSTGRES_11"

  settings {
    tier              = "db-f1-micro"
    activation_policy = "ALWAYS"
    availability_type = "REGIONAL"
    disk_autoresize   = true
    disk_size         = 10
    disk_type         = "PD_SSD"
    pricing_plan      = "PER_USE"

    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "all"
        value = "0.0.0.0/0"
      }
    }

    location_preference {
      zone = "europe-west4-a"
    }

    backup_configuration {
      binary_log_enabled = false
      enabled            = true
      start_time         = "11:30"
    }
  }
}

# ------------------------------------------------------------------------------
# CREATE A DATABASE
# ------------------------------------------------------------------------------

resource "google_sql_database" "default" {
  depends_on = [google_sql_database_instance.master]

  name     = "db-${random_id.name.hex}"
  project  = "flamarion"
  instance = google_sql_database_instance.master.name
}

resource "google_sql_user" "default" {
  depends_on = [google_sql_database.default]
  project    = "flamarion"
  name       = "admin"
  instance   = google_sql_database_instance.master.name
  # Postgres users don't have hosts, so the API will ignore this value which causes Terraform to attempt
  # to recreate the user each time.
  # See https://github.com/terraform-providers/terraform-provider-google/issues/1526 for more information.
  host     = null
  password = "SuperS3cret"
}


# ------------------------------------------------------------------------------
# CREATE THE READ REPLICAS
# ------------------------------------------------------------------------------

# resource "google_sql_database_instance" "read_replica" {

#   depends_on = [
#     google_sql_database_instance.master,
#     google_sql_database.default,
#     google_sql_user.default,
#   ]

#   provider         = google-beta
#   # name             = "replica-${random_id.name.hex}"
#   project          = "flamarion"
#   region           = "europe-west4"
#   database_version = "POSTGRES_11"

#   # The name of the instance that will act as the master in the replication setup.
#   master_instance_name = google_sql_database_instance.master.name

#   replica_configuration {
#     # Specifies that the replica is not the failover target.
#     failover_target = false
#   }

#   settings {
#     tier              = "db-f1-micro"
#     activation_policy = "ALWAYS"
#     availability_type = "REGIONAL"
#     disk_autoresize   = true
#     disk_size         = 10
#     disk_type         = "PD_SSD"
#     pricing_plan      = "PER_USE"

#     ip_configuration {
#       ipv4_enabled = true
#       authorized_networks {
#         name  = "all"
#         value = "0.0.0.0/0"
#       }
#     }

#     location_preference {
#       zone = "europe-west4-b"
#     }
#   }
# }


# ------------------------------------------------------------------------------
# CREATE A TEMPLATE FILE TO SIGNAL ALL RESOURCES HAVE BEEN CREATED
# ------------------------------------------------------------------------------

data "template_file" "complete" {
  depends_on = [
    google_sql_database_instance.master,
    # google_sql_database_instance.read_replica,
    google_sql_database.default,
    google_sql_user.default,
  ]

  template = true
}


output "master" {
  value = google_sql_database_instance.master
}

# output "read_reaplica" {
#   value = google_sql_database_instance.read_replica
# }
