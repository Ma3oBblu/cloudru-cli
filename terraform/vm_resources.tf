// Ресурсы варианта A: одна ВМ под docker compose.
// Провижининг — по SSH после создания (user_data через API площадка не принимает;
// вход настраивается слотами метаданных образа: login + public_key).

resource "cloudru_evolution_compute_security_group" "web" {
  project_id  = var.project_id
  name        = "${var.name_prefix}-web"
  description = "finances: SSH с домашнего IP, HTTP/HTTPS всем"

  zone = {
    name = var.vm_zone
  }
}

resource "cloudru_evolution_compute_security_group_rule" "ssh" {
  security_group_id = cloudru_evolution_compute_security_group.web.id
  direction         = "TRAFFIC_DIRECTION_INGRESS"
  ether_type        = "ETHER_TYPE_IPV4"
  ip_protocol       = "IP_PROTOCOL_TCP"
  port_range        = "22"
  remote_ip_prefix  = var.ssh_source_cidr
  description       = "ssh с домашнего адреса"
}

resource "cloudru_evolution_compute_security_group_rule" "http" {
  security_group_id = cloudru_evolution_compute_security_group.web.id
  direction         = "TRAFFIC_DIRECTION_INGRESS"
  ether_type        = "ETHER_TYPE_IPV4"
  ip_protocol       = "IP_PROTOCOL_TCP"
  port_range        = "80"
  remote_ip_prefix  = "0.0.0.0/0"
  description       = "http (ACME + редирект на https)"
}

resource "cloudru_evolution_compute_security_group_rule" "https" {
  security_group_id = cloudru_evolution_compute_security_group.web.id
  direction         = "TRAFFIC_DIRECTION_INGRESS"
  ether_type        = "ETHER_TYPE_IPV4"
  ip_protocol       = "IP_PROTOCOL_TCP"
  port_range        = "443"
  remote_ip_prefix  = "0.0.0.0/0"
  description       = "https"
}

resource "cloudru_evolution_compute_security_group_rule" "egress" {
  security_group_id = cloudru_evolution_compute_security_group.web.id
  direction         = "TRAFFIC_DIRECTION_EGRESS"
  ether_type        = "ETHER_TYPE_IPV4"
  ip_protocol       = "IP_PROTOCOL_ANY"
  port_range        = ""
  remote_ip_prefix  = "0.0.0.0/0"
  description       = "исходящий трафик (docker pull, apt, ACME)"
}

resource "cloudru_evolution_compute_disk" "boot" {
  project_id = var.project_id
  name       = "${var.name_prefix}-boot"
  size       = var.vm_disk_gb
  bootable   = true

  zone = {
    name = var.vm_zone
  }

  disk_type = {
    name = "SSD"
  }

  image = {
    id = local.base_image.id
  }
}

resource "cloudru_evolution_compute_interface" "nic" {
  project_id = var.project_id
  name       = "${var.name_prefix}-nic"

  zone = {
    name = var.vm_zone
  }

  subnet = {
    id = local.subnet_ids[0]
  }

  type                       = "INTERFACE_TYPE_REGULAR"
  interface_security_enabled = true

  security_groups = [
    { id = cloudru_evolution_compute_security_group.web.id }
  ]
}

resource "cloudru_evolution_compute_external_ip" "eip" {
  project_id = var.project_id
  name       = "${var.name_prefix}-eip"

  zone = {
    name = var.vm_zone
  }

  network_interface = {
    id = cloudru_evolution_compute_interface.nic.id
  }
}

resource "cloudru_evolution_compute_vm" "main" {
  project_id  = var.project_id
  name        = "${var.name_prefix}-vm"
  description = "finances: api + web + postgres в docker compose"

  zone = {
    name = var.vm_zone
  }

  flavor = {
    id = var.vm_flavor_id
  }

  disks = [
    { id = cloudru_evolution_compute_disk.boot.id }
  ]

  network_interfaces = [
    { id = cloudru_evolution_compute_interface.nic.id }
  ]

  // Логин и SSH-ключ передаются слотами метаданных образа (у Ubuntu-24.04 это
  // поля "name" и "public_key"); user_data в API Compute не поддерживается.
  image_metadata = {
    (local.meta_login_id) = {
      string_value = var.vm_login
    }
    (local.meta_public_key_id) = {
      string_value = file(pathexpand(var.ssh_public_key_path))
    }
    (local.meta_hostname_id) = {
      string_value = "${var.name_prefix}-vm"
    }
  }
}
