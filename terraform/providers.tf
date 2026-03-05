terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # State is stored locally.
  # To migrate to remote state (Azure Storage, Terraform Cloud, etc.),
  # add a backend block here.
  backend "local" {}
}

provider "azurerm" {
  features {}
}
