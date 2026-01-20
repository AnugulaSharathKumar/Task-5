############################################
# 1️⃣ VPC & Subnet
############################################

resource "google_compute_network" "vpc" {
  name                    = "multi-zone-lb-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "multi-zone-lb-subnet"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.40.0.0/24"
}

############################################
# 2️⃣ Firewall Rules
############################################

resource "google_compute_firewall" "allow_ssh" {
  name    = "multi-zone-allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

resource "google_compute_firewall" "allow_http" {
  name    = "multi-zone-allow-http"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

resource "google_compute_firewall" "allow_health_check" {
  name    = "multi-zone-allow-health-check"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["web"]
}

############################################
# 3️⃣ Health Check
############################################

resource "google_compute_health_check" "http_health_check" {
  name                = "multi-zone-http-health-check"
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
# 4️⃣ Instance Template
############################################

resource "google_compute_instance_template" "template" {
  name_prefix  = "multi-zone-web-template-"
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
    echo "Multi-Zone MIG Instance: $(hostname)" > /var/www/html/index.html
  EOF

  tags = ["web"]
}

############################################
# 5️⃣ Multi-Zone MIG
############################################

resource "google_compute_region_instance_group_manager" "mig" {
  name               = "multi-zone-web-mig"
  base_instance_name = "multi-web"
  region             = var.region
  target_size        = 2

  version {
    instance_template = google_compute_instance_template.template.id
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.http_health_check.id
    initial_delay_sec = 60
  }

  distribution_policy_zones = var.zones
}

############################################
# 6️⃣ Backend Service
############################################

resource "google_compute_backend_service" "backend" {
  name                  = "multi-zone-web-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 10
  health_checks         = [google_compute_health_check.http_health_check.id]

  backend {
    group = google_compute_region_instance_group_manager.mig.instance_group
  }
}

############################################
# 7️⃣ URL Map
############################################

resource "google_compute_url_map" "url_map" {
  name            = "multi-zone-web-url-map"
  default_service = google_compute_backend_service.backend.id
}

############################################
# 8️⃣ Target HTTP Proxy
############################################

resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "multi-zone-web-http-proxy"
  url_map = google_compute_url_map.url_map.id
}

############################################
# 9️⃣ Global Forwarding Rule
############################################

resource "google_compute_global_forwarding_rule" "http_forwarding_rule" {
  name       = "multi-zone-web-http-forwarding-rule"
  port_range = "80"
  target     = google_compute_target_http_proxy.http_proxy.id
}
############################################