terraform {
    required_version = ">= 0.13"
}

provider "aws" {
    profile         = "default"
    region          = var.region
}

module "vpc" {
    source                      = "./vpc-defination"
    vpc_name                    = "parvez_vpc"       
    cidr_block                  = var.cidr_block
    private_subnet_cidr_blocks  = var.private_subnet_cidr_blocks
    public_subnet_cidr_blocks   = var.public_subnet_cidr_blocks
    availability_zones          = var.availability_zones
}
