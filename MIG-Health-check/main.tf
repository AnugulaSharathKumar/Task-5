############################################
# VPC & SUBNET
############################################

resource "google_compute_network" "vpc" {
  name                    = "mig-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "mig-subnet"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.20.0.0/24"
}

############################################
# FIREWALL RULES
############################################

resource "google_compute_firewall" "allow_ssh" {
  name    = "mig-allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["mig"]
}

resource "google_compute_firewall" "allow_http" {
  name    = "mig-allow-http"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  # GCP health check IP ranges
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["mig"]
}

############################################
# HEALTH CHECK
############################################

resource "google_compute_health_check" "http_health_check" {
  name                = "mig-http-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port         = 80
    request_path = "/"
  }
}

############################################
# INSTANCE TEMPLATE
############################################

resource "google_compute_instance_template" "template" {
  name_prefix  = "ubuntu-template-"
  machine_type = var.machine_type

  disk {
    source_image = var.image
    boot         = true
    auto_delete  = true
  }

  network_interface {
    network    = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {}
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y apache2
    systemctl start apache2
    echo "Healthy MIG Instance: $(hostname)" > /var/www/html/index.html
  EOF

  tags = ["mig"]
}

############################################
# MANAGED INSTANCE GROUP (AUTO-HEALING)
############################################

resource "google_compute_instance_group_manager" "mig" {
  name               = "ubuntu-mig"
  base_instance_name = "ubuntu"
  zone               = var.zone
  target_size        = 1

  version {
    instance_template = google_compute_instance_template.template.id
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.http_health_check.id
    initial_delay_sec = 60
  }
}

############################################
# AUTOSCALER
############################################

resource "google_compute_autoscaler" "autoscaler" {
  name   = "mig-autoscaler"
  zone   = var.zone
  target = google_compute_instance_group_manager.mig.id

  autoscaling_policy {
    min_replicas = 1
    max_replicas = 5

    cpu_utilization {
      target = 0.6
    }
  }
}
############################################