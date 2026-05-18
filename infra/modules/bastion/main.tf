# -----------------------------------------------------------------------------
# Azure Bastion Module
# -----------------------------------------------------------------------------
# Creates Azure Bastion for secure RDP/SSH access to VMs without public IPs.
# Wraps the Azure Verified Module for Bastion while keeping the explicit public
# IP and audit diagnostic setting already used by this repo.
# -----------------------------------------------------------------------------

data "azurerm_resource_group" "current" {
  name = var.resource_group_name
}

# Public IP for Bastion (required)
resource "azurerm_public_ip" "bastion" {
  name                    = "${var.app_name}-bastion-pip"
  location                = var.location
  resource_group_name     = var.resource_group_name
  allocation_method       = var.public_ip_allocation_method
  sku                     = var.public_ip_sku
  sku_tier                = var.public_ip_sku_tier
  ip_version              = var.public_ip_version
  idle_timeout_in_minutes = var.public_ip_idle_timeout_in_minutes
  ddos_protection_mode    = var.public_ip_ddos_protection_mode

  tags = var.common_tags
  lifecycle {
    ignore_changes = [tags]
  }
}

module "main" {
  source  = "Azure/avm-res-network-bastionhost/azurerm"
  version = "0.9.0"

  enable_telemetry       = false
  name                   = "${var.app_name}-bastion"
  location               = var.location
  parent_id              = data.azurerm_resource_group.current.id
  sku                    = var.bastion_sku
  tunneling_enabled      = var.tunneling_enabled
  copy_paste_enabled     = var.copy_paste_enabled
  file_copy_enabled      = var.file_copy_enabled
  ip_connect_enabled     = var.ip_connect_enabled
  shareable_link_enabled = var.shareable_link_enabled
  scale_units            = var.scale_units

  ip_configuration = {
    name                 = "configuration"
    subnet_id            = var.bastion_subnet_id
    create_public_ip     = false
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tags = var.common_tags
}

resource "azurerm_monitor_diagnostic_setting" "bastion_audit" {
  name                       = "${var.app_name}-bastion-audit"
  target_resource_id         = module.main.resource_id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "BastionAuditLogs"
  }
}
