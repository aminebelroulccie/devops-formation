variable "region" {
  type        = string
  description = "Région AWS de la formation"
  default     = "eu-west-3" # Paris
}

variable "owner" {
  type        = string
  description = "Votre prénom (minuscules, sans accent) : sert aux tags et au nom des ressources"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.owner))
    error_message = "owner : lettres minuscules, chiffres et tirets uniquement (2 à 20 caractères)."
  }
}

variable "instance_type" {
  type        = string
  description = "Type d'instance EC2"
  default     = "t3.micro"
}

variable "public_key_path" {
  type        = string
  description = "Chemin de la clé publique SSH créée au jour 1"
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_allowed_cidr" {
  type        = string
  description = "Plage autorisée à se connecter en SSH (idéalement votre IP publique en /32)"
  default     = "0.0.0.0/0"
}

variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.42.1.0/24"
}
