variable "region" {
    default     = "us-west-1"
}

variable "cidr_block" {
    default     = "10.0.0.0/16"
}

variable "private_subnet_cidr_blocks" {
    type        = list
    default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_cidr_blocks" {
    type        = list
    default     = ["10.0.3.0/24", "10.0.4.0/24"]  
}   

variable "availability_zones" {
    type        = list
    default     = ["us-west-1b", "us-west-1c"]
}
