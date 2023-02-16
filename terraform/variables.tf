# Declare the data source
data "aws_availability_zones" "available" {
  state = "available"
}

variable "cluster_name" {
  type = string
  default = "eks-chatgpt"
}

variable "tags" {
  type = map(string)
  default = {
     Environment = "Dev"
     Owner       = "Bruno Olimpio"
     Project     = "Demo_ChatGPT"
  }
}

# variable "azs" {
#   type = list(string)
#   default = [
#     data.aws_availability_zones.available.names[0],
#     data.aws_availability_zones.available.names[1],
#     data.aws_availability_zones.available.names[2]
#   ]
# }

variable "azs" {
  type    = list(string)
  default = slice(data.aws_availability_zones.available.names, 0, 3)
}

variable "worker_group  s_launch_template" {
  type = list(object({
    instance_type = string
    asg_desired_capacity = number
    asg_max_size = number
  }))
  default = [
    {
      instance_type = "t2.small"
      asg_desired_capacity = 2
      asg_max_size = 4
    }
  ]
}

variable "vpc_name" {
  type = string
  default = "my-vpc-chatgpt"
}

variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16"
}

variable "private_subnets" {
  type = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  type = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}