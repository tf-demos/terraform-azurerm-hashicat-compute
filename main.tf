# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.9.0"
    }
  }
}

#######################
#      Public IP      #
#######################
resource "azurerm_public_ip" "mgmt-pip" {
  name                = "${var.prefix}-mgmt-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  domain_name_label   = "${var.prefix}-mgmt"
}

#######################
# Network interfaces  #
#######################
# NIC1 for http access:
resource "azurerm_network_interface" "catapp-nic" {
  name                = "${var.prefix}-catapp-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "${var.prefix}-ipconfig"
    subnet_id                     = var.vm_subnet_id 
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mgmt-pip.id
  }
}

#######################
#     Hashicat VM     #
#######################

resource "azurerm_linux_virtual_machine" "catapp" {
  name                            = "${var.prefix}-meow"
  location                        = var.location
  resource_group_name             = var.resource_group_name    
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.catapp-nic.id]      

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = "60"

  }

  tags = {}

  # Added to allow destroy to work correctly.
  depends_on = [azurerm_network_interface_security_group_association.catapp-nic-sg-ass]
}

# NSG association to the NIC:

resource "azurerm_network_interface_security_group_association" "catapp-nic-sg-ass" {
  network_interface_id      = azurerm_network_interface.catapp-nic.id
  network_security_group_id = var.security_group_id
}

# We're using a little trick here so we can run the provisioner without
# destroying the VM. Do not do this in production.

# If you need ongoing management (Day N) of your virtual machines a tool such
# as Chef or Puppet is a better choice. These tools track the state of
# individual files and can keep them in the correct configuration.

# Here we do the following steps:
# Sync everything in files/ to the remote VM.
# Set up some environment variables for our script.
# Add execute permissions to our scripts.
# Run the deploy_app.sh script.

resource "null_resource" "configure-cat-app" {
  depends_on = [
    azurerm_linux_virtual_machine.catapp,
  ]
  triggers = {
    build_number = timestamp()
  }

  provisioner "file" {
    source      = "${path.module}/files/"
    destination = "/home/${var.admin_username}/"

    connection {
      type     = "ssh"
      user     = var.admin_username
      password = var.admin_password
      host     = azurerm_public_ip.mgmt-pip.fqdn
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt -y update",
      "sleep 15",
      "sudo apt -y update",
      "sudo apt -y install apache2",
      "sudo systemctl start apache2",
      "sudo chown -R ${var.admin_username}:${var.admin_username} /var/www/html",
      "chmod +x *.sh",
      "sudo apt -y install jq",
      "export response=$(curl -H 'X-Vault-Token: ${var.vault_app_token}' -H 'X-Vault-Namespace: admin/' -X GET ${var.vault_addr}/v1/secrets/data/example-secret)",
      "export data=$(echo $response | jq '.data.data')",
      "PLACEHOLDER=${var.placeholder} WIDTH=${var.width} HEIGHT=${var.height} PREFIX=${var.prefix} SECRET=$data ./deploy_app.sh",
      "sudo apt -y install cowsay",
      "cowsay Mooooooooooo!",
    ]

    connection {
      type     = "ssh"
      user     = var.admin_username
      password = var.admin_password
      host     = azurerm_public_ip.mgmt-pip.fqdn
    }
  }
}
