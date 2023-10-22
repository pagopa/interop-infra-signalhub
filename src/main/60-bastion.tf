locals {
  user_data = <<-EOT
    #!/bin/bash
    sudo amazon-linux-extras install -y postgresql10
  EOT
}


module "bastion" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "${local.project}-bastion"

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  availability_zone           = element(module.vpc.azs, 0)
  subnet_id                   = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  disable_api_stop            = false
  key_name                    = aws_key_pair.generated_key.key_name

  create_iam_instance_profile = true
  iam_role_description        = "IAM role for EC2 instance"
  iam_role_policies = {
    AdministratorAccess = "arn:aws:iam::aws:policy/AdministratorAccess"
  }

  user_data_base64            = base64encode(local.user_data)
  user_data_replace_on_change = true

  tags = var.tags
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["*amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "bastion_sg" {
  description = "Bastion SG"
  name        = "${local.project}-bastion-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name = "Security Group"
    },
    var.tags
  )
}

resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "${local.project}-bastion-keypair"
  public_key = tls_private_key.key_pair.public_key_openssh

  provisioner "local-exec" {
    command = "echo '${tls_private_key.key_pair.private_key_pem}' > ./bastion_private_key.pem"
  }
}