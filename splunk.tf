locals {
  public_ip = jsondecode(data.http.my_public_ip.body).ip
}

# Get Availability zones in the Region
data "aws_availability_zones" "AZ" {}


# Get My Public IP
data "http" "my_public_ip" {
  url = "https://ipinfo.io/json"
  request_headers = {
    Accept = "application/json"
  }
}


data "aws_ami" "splunk" {
  most_recent = true
  owners      = ["679593333241"] ## Splunk Account 

  filter {
    name   = "name"
    values = ["splunk_AMI*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


resource "aws_iam_role" "splunk-ec2-role" {
  name               = "splunk-ec2-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


resource "aws_iam_role_policy" "splunk_iam_role_policy" {
  name   = "splunk_iam_role_policy"
  role   = aws_iam_role.splunk-ec2-role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ssm:StartSession", "ssm:TerminateSession"],
      "Resource":"*"
    },
    {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams"
            ],
            "Resource": [
                "arn:aws:logs:*:*:*"
            ]
        }
  ]
}
EOF
}


resource "aws_iam_instance_profile" "splunk-ec2-role" {
  name = "splunk-ec2-role"
  role = aws_iam_role.splunk-ec2-role.name
}

resource "aws_iam_role_policy_attachment" "ssm-policy-splunk" {
  role       = aws_iam_role.splunk-ec2-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


data "template_file" "splunk_user_data" {
  template = file("userdata-scripts/splunk_user_data.sh")
  # count = var.deploy_mongo  == "yes" ? 1 : 0
  vars = {
    aws_region = var.region
  }
}


resource "aws_instance" "splunk" {
  ami                    = data.aws_ami.splunk.id
  instance_type          = "t3.small"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.allow_ssh_and_tls.id]
  #   associate_public_ip_address = false
  user_data_replace_on_change = true
  user_data                   = data.template_file.splunk_user_data.rendered
  iam_instance_profile        = aws_iam_instance_profile.splunk-ec2-role.name
  lifecycle {
    create_before_destroy = true
  }
  #   key_name                    = "2023-key"
  availability_zone = data.aws_availability_zones.AZ.names[0]
  tags = {
    Name = "splunk"
  }
}

resource "aws_eip" "splunk_public_ip" {
  #   instance = aws_instance.splunk.id
  vpc = true
  tags = {
    Name = "splunk_public_ip"
  }
  lifecycle {
    create_before_destroy = "true"
  }
}

resource "aws_eip_association" "splunk_public_ip-eip-association" {
  instance_id   = aws_instance.splunk.id
  allocation_id = aws_eip.splunk_public_ip.id
  lifecycle {
    create_before_destroy = "true"
  }
}

resource "aws_security_group" "allow_ssh_and_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "API Access"
    from_port   = 8089
    to_port     = 8089
    protocol    = "tcp"
    cidr_blocks = ["${local.public_ip}/32"]
  }


  ingress {
    description = "HEC Access"
    from_port   = 8088
    to_port     = 8088
    protocol    = "tcp"
    cidr_blocks = ["${local.public_ip}/32"]
  }

  ingress {
    description = "UI Access"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["${local.public_ip}/32"]
  }

  ingress {
    description = "UI Access"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["${local.public_ip}/32"]
  }

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${local.public_ip}/32"]
  }
  ingress {
    description = "letsencrypt-dns-validation-delete-later"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HEC Access-Public-test and Delete"
    from_port   = 8088
    to_port     = 8088
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "UI Access-Public-test and Delete"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ### To be more accurate, we could specify the Terraform Cloud public IP ranges used for API communications. Uncomment the line below and the ip_ranges datasource and public_ip_range locals if required.
    //cidr_blocks      = local.public_ip_range.api

    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Splunk-Ports"
  }
}

