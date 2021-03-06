resource "google_compute_network" "pcf-virt-net" {
  name = "${var.prefix}-virt-net"
}

// Ops Manager & Jumpbox
resource "google_compute_subnetwork" "subnet-ops-manager" {
  name          = "infra"
  ip_cidr_range = "${var.cidr_ops}"
  network       = "${google_compute_network.pcf-virt-net.self_link}"
}

// ERT
resource "google_compute_subnetwork" "subnet-ert" {
  name          = "ert"
  ip_cidr_range = "${var.cidr_ert}"
  network       = "${google_compute_network.pcf-virt-net.self_link}"
}

// Services Tile
resource "google_compute_subnetwork" "subnet-services-1" {
  name          = "svcs"
  ip_cidr_range = "${var.cidr_svc}"
  network       = "${google_compute_network.pcf-virt-net.self_link}"
}

// Dynamic Services Tile
resource "google_compute_subnetwork" "subnet-dynamic-services-1" {
  name          = "dyn-svcs"
  ip_cidr_range = "${var.cidr_dynsvc}"
  network       = "${google_compute_network.pcf-virt-net.self_link}"
}
