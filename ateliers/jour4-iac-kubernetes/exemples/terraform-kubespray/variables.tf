variable "region" {
  type        = string
  description = "Région AWS de la formation"
  default     = "eu-west-3" # Paris
}

variable "owner" {
  type        = string
  description = "Votre identifiant Formini (minuscules, sans accent) : tags et préfixe des ressources"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.owner))
    error_message = "owner : lettres minuscules, chiffres et tirets uniquement (2 à 20 caractères)."
  }
}

variable "node_count" {
  type        = number
  description = "Nombre de nœuds Kubernetes"
  default     = 3

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 9
    error_message = "node_count : entre 1 et 9."
  }
}

variable "instance_type" {
  type        = string
  description = "Type d'instance : Kubespray exige au moins 2 vCPU et 4 Go (t3.medium), pas t3.micro"
  default     = "t3.medium"
}

variable "root_volume_gb" {
  type        = number
  description = "Taille du disque racine (images de conteneurs, etcd)"
  default     = 30
}

variable "public_key_path" {
  type        = string
  description = "Clé publique SSH créée au jour 1"
  default     = "~/.ssh/id_ed25519.pub"
}

variable "admin_cidr" {
  type        = string
  description = "Plage autorisée en SSH et sur l'API Kubernetes (idéalement votre IP publique en /32)"
  default     = "0.0.0.0/0"
}

variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "Sous-réseau public commun aux trois nœuds"
  default     = "10.42.1.0/24"
}
