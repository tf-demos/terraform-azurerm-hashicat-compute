# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: Apache-2.0

output "vm_ips" {
  value = azurerm_network_interface.catapp-nic.private_ip_addresses
}
