provider "azurerm" {
  features {}
}

#Create Azure Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = var.location
}
#Create Azure VNet Subnet
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = "VnetRG"
  virtual_network_name = "testVnet"
  address_prefixes     = ["10.0.2.0/24"]
}
#Create Azure Bastion Subnet
resource "azurerm_subnet" "AzureBastionSubnet" {
  name                ="AzureBastionSubnet"
  resource_group_name = "VnetRG"
  virtual_network_name = "testVnet"
  address_prefixes     = ["10.0.3.0/27"]
}
#Create Azure Bastion Public IP
resource "azurerm_public_ip" "BastionPublicIP" {
  name                = "BastionPublicIP"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
#Create Azure Bastion Host
resource "azurerm_bastion_host" "BastionHost" {
  name                = "bastion"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.AzureBastionSubnet.id
    public_ip_address_id = azurerm_public_ip.BastionPublicIP.id
  }
}
#Create Azure Network Interface Card
resource "azurerm_network_interface" "mytestnic" {
  name                = "mytestnic"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}
#Create Azure Network Security Group With The Appropriate Security Rules
resource "azurerm_network_security_group" "mytestnsg" {
  name                          = "mytestnsg"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name

    security_rule {
        name                       = "AllowHttpsInbound"
        priority                   = 120
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "Internet"
        destination_address_prefix = "*"
    }

}


#Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nsgassoc" {
    network_interface_id      = azurerm_network_interface.mytestnic.id
    network_security_group_id = azurerm_network_security_group.mytestnsg.id
   
}
#Create Azure VM - Standard F2 size
resource "azurerm_windows_virtual_machine" "main" {
  name                            = "${var.prefix}-vm"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_F2"
  admin_username                  = "myuser"
  admin_password                  = "P@sSW0rD12345!"
  network_interface_ids = [azurerm_network_interface.mytestnic.id]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}