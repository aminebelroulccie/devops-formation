# ---------------------------------------------------------------------------
# Formation DevOps Formini — Jour 4, exemple Terraform / AWS
# Trois nœuds Ubuntu dans le même sous-réseau public, une Internet Gateway (le
# « routeur » vers Internet), une Elastic IP (l'« IP flottante » d'AWS) par nœud.
# Prêts pour Kubespray (inventaire généré dans inventory/).
# À détruire après usage : terraform destroy  — 3 × t3.medium + 3 EIP coûtent de l'argent.
# ---------------------------------------------------------------------------

locals {
  prefix = "formini-${var.owner}"
  nodes  = [for i in range(var.node_count) : "node${i + 1}"]
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# ----- Réseau : VPC, sous-réseau, « routeur » Internet ----------------------
resource "aws_vpc" "k8s" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.prefix}-vpc" }
}

resource "aws_subnet" "k8s" {
  vpc_id            = aws_vpc.k8s.id
  cidr_block        = var.subnet_cidr
  availability_zone = "${var.region}a"

  tags = { Name = "${local.prefix}-subnet" }
}

resource "aws_internet_gateway" "k8s" {
  vpc_id = aws_vpc.k8s.id

  tags = { Name = "${local.prefix}-igw" }
}

resource "aws_route_table" "k8s" {
  vpc_id = aws_vpc.k8s.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s.id
  }

  tags = { Name = "${local.prefix}-rt" }
}

resource "aws_route_table_association" "k8s" {
  subnet_id      = aws_subnet.k8s.id
  route_table_id = aws_route_table.k8s.id
}

# ----- Pare-feu --------------------------------------------------------------
resource "aws_security_group" "k8s" {
  name        = "${local.prefix}-k8s"
  description = "Noeuds Kubernetes Formini : SSH, API, tout le trafic entre noeuds"
  vpc_id      = aws_vpc.k8s.id

  tags = { Name = "${local.prefix}-k8s" }
}

# Tout le trafic entre membres du groupe (etcd, kubelet, CNI, IP-in-IP, VXLAN…)
resource "aws_vpc_security_group_ingress_rule" "internal" {
  security_group_id            = aws_security_group.k8s.id
  referenced_security_group_id = aws_security_group.k8s.id
  ip_protocol                  = "-1"
  description                  = "Trafic interne du cluster"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.k8s.id
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  description       = "SSH"
}

resource "aws_vpc_security_group_ingress_rule" "kube_api" {
  security_group_id = aws_security_group.k8s.id
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
  description       = "API Kubernetes"
}

resource "aws_vpc_security_group_ingress_rule" "nodeports" {
  security_group_id = aws_security_group.k8s.id
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 30000
  to_port           = 32767
  description       = "Services NodePort"
}

resource "aws_vpc_security_group_ingress_rule" "icmp" {
  security_group_id = aws_security_group.k8s.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  description       = "ping"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.k8s.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ----- Clé SSH ---------------------------------------------------------------
resource "aws_key_pair" "admin" {
  key_name   = "${local.prefix}-key"
  public_key = file(pathexpand(var.public_key_path))
}

# ----- Trois nœuds, trois Elastic IP -----------------------------------------
resource "aws_instance" "node" {
  count = var.node_count

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.k8s.id
  private_ip             = cidrhost(var.subnet_cidr, 11 + count.index) # .11, .12, .13
  vpc_security_group_ids = [aws_security_group.k8s.id]
  key_name               = aws_key_pair.admin.key_name
  # pas d'IP publique éphémère : c'est l'Elastic IP qui joue le rôle de l'IP flottante
  associate_public_ip_address = false

  root_block_device {
    volume_size = var.root_volume_gb
    volume_type = "gp3"
  }

  # Calico/kube-proxy routent du trafic qui n'a pas l'IP de l'instance comme source
  source_dest_check = false

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    hostname = local.nodes[count.index]
  })

  tags = {
    Name = "${local.prefix}-${local.nodes[count.index]}"
    Role = "k8s-node"
  }
}

resource "aws_eip" "node" {
  count  = var.node_count
  domain = "vpc"

  tags = { Name = "${local.prefix}-${local.nodes[count.index]}" }

  depends_on = [aws_internet_gateway.k8s]
}

resource "aws_eip_association" "node" {
  count = var.node_count

  instance_id   = aws_instance.node[count.index].id
  allocation_id = aws_eip.node[count.index].id
}

# ----- Inventaire Kubespray --------------------------------------------------
resource "local_file" "kubespray_inventory" {
  filename        = "${path.module}/inventory/hosts.yaml"
  file_permission = "0644"
  content = templatefile("${path.module}/inventory.tpl", {
    ssh_user = "ubuntu"
    nodes = [for i in range(var.node_count) : {
      name = local.nodes[i]
      fip  = aws_eip.node[i].public_ip
      ip   = aws_instance.node[i].private_ip
    }]
  })
}
