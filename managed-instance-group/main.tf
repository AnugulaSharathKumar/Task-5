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
# FIREWALL RULE (FIXED NAME)
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

############################################
# INSTANCE TEMPLATE (UBUNTU)
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
    echo "MIG Instance: $(hostname)" > /var/www/html/index.html
  EOF

  tags = ["mig"]
}

############################################
# MANAGED INSTANCE GROUP
############################################

resource "google_compute_instance_group_manager" "mig" {
  name               = "ubuntu-mig"
  base_instance_name = "ubuntu"
  zone               = var.zone
  target_size        = 1

  version {
    instance_template = google_compute_instance_template.template.id
  }
}

############################################
# AUTOSCALER (CPU BASED)
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