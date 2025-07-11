# terraform.tf file content ----------------------------------------
terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "6.2.0"
        }
        random = {
            source = "hashicorp/random"
            version = "3.7.2"
        }
    }
}

# provider.tf -------------------

provider "aws" {
    region = var.region
}

# variables.tf -------------------------
variable "region" {
    type = string
    default = "ap-south-1"
}

variable "environment" {
    type = string
    default = "prod"
}

variable "ami_id" {
    type = string
    default = "ami-0d03cb826412c6b0f"
}

variable "instance_type" {
    default = "t2.micro"
    type = string   
}

variable "root_block_device_config" {
    type = object({
      v_size = number
      v_type = string 
    })
    default = {
      v_size = 20
      v_type = "gp3"
    }
}

variable "bill-mode" {
    type = string
    default = "PAY_PER_REQUEST"
  
}

# vpc.tf ---------------------------------
module "my-vpc" {
    source = "terraform-aws-modules/vpc/aws"

    name = "${var.environment}-terra-vpc"

    cidr = "10.100.0.0/16"
    azs = ["ap-south-1b"]

    public_subnets = ["10.100.1.0/24"]
    private_subnets = ["10.100.2.0/24"]

    enable_nat_gateway = true
    single_nat_gateway = true

    enable_vpn_gateway = true

    map_public_ip_on_launch = true

    enable_dns_support = true
    enable_dns_hostnames = true

    tags = {
        Name = "${var.environment}-terra-vpc"
        Environment = var.environment
    }  
}

# security_group.tf -------------------------
module "my-sg" {
    source = "terraform-aws-modules/security-group/aws"
    name = "${var.environment}-terra-sg"

    vpc_id = module.my-vpc.vpc_id
    ingress_with_cidr_blocks = [
        {
            from_port = 22
            to_port = 22 
            protocol = "tcp"
            cidr_blocks = "0.0.0.0/0" 
        },
        {
            from_port = 80
            to_port = 80 
            protocol = "tcp"
            cidr_blocks = "0.0.0.0/0" 
        },
        {
            from_port = 443
            to_port = 443 
            protocol = "tcp"
            cidr_blocks = "0.0.0.0/0" 
        }
    ]

    egress_rules = ["all-all"]

    tags = {
        Name = "${var.environment}-terra-sg"
        Environment = var.environment
    }
}

# key_pair.tf --------------------

resource "aws_key_pair" "my-key" {
    key_name = "${var.environment}-my-key-pair"
    public_key = file("my-key-pair.pub")

    tags = {
        Name = "${var.environment}-my-key-pair"
        Environment = var.environment
    }  
}

# ec2.tf ----------------------

resource "aws_instance" "my-server" {
    ami = var.ami_id

    instance_type = var.instance_type

    vpc_security_group_ids = [module.my-sg.security_group_id]
    subnet_id = module.my-vpc.public_subnets[0]

    key_name = aws_key_pair.my-key.key_name

    root_block_device{
        volume_type = var.root_block_device_config.v_type
        volume_size = var.root_block_device_config.v_size
        delete_on_termination = true
    }
    user_data = file("install_nginx.sh")  

    tags = {
        Name = "${var.environment}-my-instance"
        Environment = var.environment
    }  
}

# s3.tf -----------------
resource "random_id" "my-random-no" {
    byte_length = 10
}

resource "aws_s3_bucket" "my-bucket" {
    bucket = "${var.environment}-s3-bucket-testing-${random_id.my-random-no.dec}"
    
    tags = {
        Name = "${var.environment}-s3-bucket-testing-${random_id.my-random-no.dec}"
        Environment = var.environment
    } 
}

# dynamodb.tf ------------------------
resource "aws_dynamodb_table" "my-dynamodb-table" {

    name = "${var.environment}-my-dynamodb-table-testing-${random_id.my-random-no.dec}"

    billing_mode = var.bill-mode

    hash_key = "LockID"

    attribute {
      name = "LockID"
      type = "S"
    }
    tags = {
        Name = "${var.environment}-my-dynamodb-table-testing-${random_id.my-random-no.dec}"
        Environment = var.environment
    } 
}

# outputs.tf -----------------------------------------

output "instance_public_ip" {
    value = aws_instance.my-server.public_ip
}

output "instance_public_dns" {
    value = aws_instance.my-server.public_dns
}

output "instance_private_ip" {
    value = aws_instance.my-server.private_ip
}

output "instance_type" {
    value = aws_instance.my-server.instance_type
}

output "root_block_device_config" {
    value = aws_instance.my-server.root_block_device
}

output "s3_bucket" {
    value = aws_s3_bucket.my-bucket.bucket
}

output "dynamodb" {
    value = aws_dynamodb_table.my-dynamodb-table.name
  
}
output "environment" {
    value = var.environment
}

output "region" {
    value = var.region
}

output "vpc_name" {
    value = module.my-vpc.name
}

output "security_group" {
    value = module.my-sg.security_group_name
}