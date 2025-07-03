provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "instance_sg" {
  name        = "instance-sg"
  description = "Allow traffic from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
}

resource "aws_lb_target_group" "tg" {
  name     = "my-targets"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_instance" "microservice1" {
  ami           = "ami-0c55b159cbfafe1f0" 
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_b.id
  security_groups = [aws_security_group.instance_sg.name]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3 pip
              pip3 install flask boto3

              cat <<EOPY > /home/ec2-user/app.py
              from flask import Flask, request, jsonify
              import boto3

              app = Flask(__name__)
              sqs = boto3.client('sqs', region_name='us-east-1') 
              QUEUE_URL = "${aws_sqs_queue.my_queue.id}"

              @app.route("/ingest", methods=["POST"])
              def ingest():
                  data = request.get_json()
                  if not data:
                      return jsonify({"error": "Invalid JSON"}), 400

                  try:
                      sqs.send_message(
                          QueueUrl=QUEUE_URL,
                          MessageBody=str(data)
                      )
                      return jsonify({"status": "Message sent"}), 200
                  except Exception as e:
                      return jsonify({"error": str(e)}), 500

              if __name__ == "__main__":
                  app.run(host="0.0.0.0", port=80)
              EOPY

              nohup python3 /home/ec2-user/app.py &
              EOF
}

resource "aws_instance" "microservice2" {
  ami           = "ami-0c55b159cbfafe1f0" 
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_b.id
  security_groups = [aws_security_group.instance_sg.name]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello from instance" > /var/www/html/index.html
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              EOF
}

resource "aws_lb_target_group_attachment" "attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.microservice1.id
  port             = 80
}
