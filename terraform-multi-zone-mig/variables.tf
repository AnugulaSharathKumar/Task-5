variable "project" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
}

variable "zones" {
  type        = list(string)
  description = "List of zones for multi-zone MIG"
  default     = ["us-central1-a", "us-central1-b"]
}

variable "machine_type" {
  type    = string
  default = "e2-medium"
}

variable "image" {
  type    = string
  default = "ubuntu-os-cloud/ubuntu-2204-lts"
}
