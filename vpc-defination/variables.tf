variable "region" {
    default     = ""
}

variable "cidr_block" {
    default     = ""
}

variable "private_subnet_cidr_blocks" {
    #type        = list
    default     = ""
}

variable "public_subnet_cidr_blocks" {
    #type        = list
    default     = "" 
}   

variable "availability_zones" {
    #type        = list
    default     = ""
}

variable "vpc_name" {
    default = ""
}

variable "PublicSubnet" {
    default = ""
}

variable "PrivateSubnet" {
    default = ""
}

variable "ec2_count" {
  default = "1"
}

variable "ami_id" {
    // Amazon Linux 2 AMI (HVM), SSD Volume Type in us-west-1
    default = "ami-03ab7423a204da002"
}

variable "instance_type" {
  default = "t2.micro"
}