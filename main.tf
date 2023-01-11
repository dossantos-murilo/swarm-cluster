# Linha responsável por setar em qual provider cloud vamos aplicar essa infraestrutura, assim como a região desejada.
provider "aws" {
  region = "us-east-1"
}
# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 4.0"
#     }
#   }
# }

# Linha responsável por criar uma chave de acesso na AWS (swarm-key) configurando a chave pública da minha máquina, ou seja o equipamento que estamos conectando na API da AWS.
resource "aws_key_pair" "swarm-key" {
  key_name   = "swarm-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCerg/dLHqMXs1yMp/LQak1bpywChmCp+fj87AqIUUDa8wu41Tskferz/MnDJOi7fOPNmGJm3cjGRr0f+5myqpVkrgcukPedct7milc4neZ17qk+TOk5JMp57vpOT5ZMwRUt7rc/pzXL5HOxzS1LLa4DZgYzs0dMuMMM8DzIkejbKciDtYyJm5TPI/MEjG/cTkPbqvNrmvhL4FRkuqMqzZnBuEvt/w8ib5Ar53E9O/OvtDQmOVGoGIaRKwiqh08yMeHCEoFGyB8InSr6fX05Q5H7xbQ0hqTBYBnUVuUDTSRiiExX2fs8tSABQn8ILzgK/eJqMWLZPvmGLTp6yCguzFzAOnf9Zs2GS6qZ8NiGHMbo3V1NnVORqlwU31YtsWGGmmCY6qwuOMQ3k8ferilKKJD0x0bYEbSkOI9h6yxVLpG8UkOO6TiO32WhaQzsfWMTmGa+IEytXEilJ5hZb3JhAXMhL+AOO65od6IGhYCNS1maN1EXa/soRLaGeid54gRa4s= ubuntu@DESKTOP-97NMB5L"
}

# Linha de código responsável por criar uma VPC chamada “swarm-vpc” configurando um range de ips interno a serem distribuídos às instâncias provisionadas. Está sendo configurado também o suporte ao DNS interno e externo.
resource "aws_vpc" "swarm-vpc" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Main VPC"
  }
}

#Linha de código responsável por criar uma sub-rede interna dentro do range informado na VPC, assim como configurar a zona de disponibilidade dessa rede.
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.swarm-vpc.id
  cidr_block        = "172.16.0.0/16"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Private Subnet"
  }
}

# Linha de código responsável por criar um internet gateway dentro da VPC, para criação de rotas de saída da rede para a internet.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.swarm-vpc.id

  tags = {
    Name = "Main IGW"
  }
}

# Linha de código responsável por criar uma rota default de saída para a internet dentro da VPC.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.swarm-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Private Route Table"
  }
}

# Linha de código responsável por vincular a rota criada anteriormente à nossa sub-rede.
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Linha de código responsável por criar um grupo de segurança e configurar regras de entrada permitindo o tráfego SSH e conexões de qualquer IP. Regras de saída liberando todo o tráfego de saída da rede.
resource "aws_security_group" "swarm_sg" {
  vpc_id = aws_vpc.swarm-vpc.id
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
}

# # Linha de código responsável pela criação de dois discos de armazenamento de 10 GB adicionais para realizar o vínculo na instância do NFS Server.
# resource "aws_volume_attachment" "volume_disc1" {
#   device_name = "/dev/xvdb"
#   volume_id   = aws_ebs_volume.disc1.id
#   instance_id = aws_instance.nfs-server.id
# }

# resource "aws_volume_attachment" "volume_disc2" {
#   device_name = "/dev/xvdc"
#   volume_id   = aws_ebs_volume.disc2.id
#   instance_id = aws_instance.nfs-server.id
# }

# resource "aws_ebs_volume" "disc1" {
#   availability_zone = "us-east-1a"
#   size              = 10
# }

# resource "aws_ebs_volume" "disc2" {
#   availability_zone = "us-east-1a"
#   size              = 10
# }

# # Linha de código responsável pela criação da instância do NFS Server. Junto a instância está sendo vinculado à mesma zona de disponibilidade que os discos adicionais foram criados, vínculo a subnet criada, especificação da ami do sistema operacional desejado, configuração do tipo de hardware a ser usado, vínculo da chave de acesso, configuração de um IP privado fixo, vínculo ao grupo de segurança criado e a configuração das tags de identificação.
# resource "aws_instance" "nfs-server" {
#   availability_zone           = "us-east-1a"
#   subnet_id                   = aws_subnet.private.id
#   ami                         = "ami-052efd3df9dad4825"
#   instance_type               = "t2.micro"
#   key_name                    = "swarm-key"
#   private_ip                  = "172.16.0.200"
#   vpc_security_group_ids      = ["${aws_security_group.swarm_sg.id}"]
#   associate_public_ip_address = true
#   tags = {
#     name = "swarm"
#     type = "nfs"
#     Name = "nfs-server"
#   }

#   root_block_device {
#     volume_type = "gp2"
#     volume_size = 128
#   }
# }

# Linha de código responsável pela criação da instância Master do swarm. Junto a instância está sendo vinculado a subnet criada, especificação da ami do sistema operacional desejado, configuração do tipo de hardware a ser usado, vínculo da chave de acesso, vínculo ao grupo de segurança criado e a configuração das tags de identificação.
resource "aws_instance" "swarm-master" {
  subnet_id                   = aws_subnet.private.id
  ami                         = "ami-052efd3df9dad4825"
  instance_type               = "t2.micro"
  key_name                    = "swarm-key"
  count                       = 1
  vpc_security_group_ids      = ["${aws_security_group.swarm_sg.id}"]
  associate_public_ip_address = true
  tags = {
    name = "swarm"
    type = "master"
    Name = "swarm-master"
  }
}

# Linha de código responsável pela criação das instâncias Workers do swarm. Junto a instância está sendo vinculado a subnet criada, especificação da ami do sistema operacional desejado, configuração do tipo de hardware a ser usado, vínculo da chave de acesso, vínculo ao grupo de segurança criado e a configuração das tags de identificação.
resource "aws_instance" "swarm-worker" {
  subnet_id                   = aws_subnet.private.id
  ami                         = "ami-052efd3df9dad4825"
  instance_type               = "t2.micro"
  key_name                    = "swarm-key"
  count                       = 3
  vpc_security_group_ids      = ["${aws_security_group.swarm_sg.id}"]
  associate_public_ip_address = true
  tags = {
    name = "swarm"
    type = "worker"
    Name = "swarm-worker"
  }
}