# ---------------------------------------------------------------------------
# Formation DevOps Formini — Jour 4
# Un réseau, un sous-réseau public, un serveur Ubuntu accessible en SSH.
# À détruire en fin d'atelier : terraform destroy
# ---------------------------------------------------------------------------

# ----- Réseau ---------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "formini-${var.owner}-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"

  tags = { Name = "formini-${var.owner}-public" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "formini-${var.owner}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "formini-${var.owner}-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ----- Pare-feu -------------------------------------------------------------
resource "aws_security_group" "web" {
  name        = "formini-${var.owner}-web"
  description = "SSH et application Formini Tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "Formini Tasks"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "formini-${var.owner}-web" }
}

# ----- Clé SSH (celle du jour 1) -------------------------------------------
resource "aws_key_pair" "formini" {
  key_name   = "formini-${var.owner}"
  public_key = file(pathexpand(var.public_key_path))
}

# ----- Image Ubuntu 24.04 la plus récente ----------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ----- Serveur --------------------------------------------------------------
resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = aws_key_pair.formini.key_name
  associate_public_ip_address = true
  user_data                   = file("${path.module}/user_data.sh")

  root_block_device {
    volume_size = 16
    volume_type = "gp3"
  }

  tags = { Name = "formini-${var.owner}-web" }
}
