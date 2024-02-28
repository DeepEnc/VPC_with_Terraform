variable "cidr" {
  default = "10.0.0.0/16"
}

variable "region" {
  default = "us-east-1"  
}

variable "instance_type" {
  default = "t2.micro"  
}

variable "ami" {
  default = "ami-0c7217cdde317cfec"  
}
