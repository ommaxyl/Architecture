/********
variables
*********/

variable "vpc_cidr" {
  description = "Large CIDR private block"
  default     = "10.0.0.0/16"
}

variable "rt_wide_route" {
  description = "Unrestricted route"
  default     = "0.0.0.0/0"
}

variable "public_cidrs" {
  description = "Narrow Subnet CIDR Blocks"
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
}

variable "private_cidrs" {
  description = "Internal Subnet CIDR Blocks"
  default = [
    "10.0.3.0/24",
    "10.0.4.0/24"
  ]
}

variable "flask_app_image" {
  description = "Dockerhub image for flask-app"
  default = ""
}

variable "flask_app_port" {
  description = "inbound port"
  default = 5000
}

variable "flask_env" {
  # description = "FLASK ENV variable"
  default = "production"
}

variable "flask_app" {
  # description = "FLASK APP variable"
  default = "app"
}

variable "app_home" {
  description = "APP HOME variable"
  # default = "flask-postgres/src/"
  default = "./src/"
}

