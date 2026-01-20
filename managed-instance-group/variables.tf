variable "project" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "zone" {
  description = "GCP Zone"
  type        = string
}

variable "machine_type" {
  description = "Machine type for instances"
  type        = string
  default     = "e2-medium"
}

variable "image" {
  description = "Ubuntu OS image"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}
