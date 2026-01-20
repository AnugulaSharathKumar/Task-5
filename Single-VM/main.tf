resource "google_compute_instance" "ubuntu_vm" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.image
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"

    access_config {
      # Enables external IP
    }
  }

  tags = ["ubuntu", "terraform"]

  metadata = {
    enable-oslogin = "TRUE"
  }

  labels = {
    env = "dev"
  }
}
