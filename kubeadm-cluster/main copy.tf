provider "aws" {
  region  = "sa-east-1"
  profile = "default"
}

resource "aws_instance" "control-plane" {
  ami                    = "ami-08721da16b7931382"
  instance_type          = "t3.medium"
  key_name               = "control-plane"
  monitoring             = true
  vpc_security_group_ids = ["sg-078c4155707cbd1f5"]
  subnet_id              = "subnet-099e843146bf4e39e"

  tags = {
    Terraform   = "true"
    Environment = "study"
    Autor       = "Bruce Vieira"
    node        = "control-plane"
  }
}

resource "aws_instance" "worker-1" {

  depends_on = [aws_instance.control-plane]

  ami                    = "ami-02604e7a56907ba3a"
  instance_type          = "t3.medium"
  key_name               = "workers"
  monitoring             = true
  vpc_security_group_ids = ["sg-078c4155707cbd1f5"]
  subnet_id              = "subnet-099e843146bf4e39e"

  tags = {
    Terraform   = "true"
    Environment = "study"
    Autor       = "Bruce Vieira"
    node        = "worker-1"
  }
}

#Wait time for the control-plane get ready to run commands

resource "time_sleep" "wait_instance" {
  depends_on = [aws_instance.control-plane, aws_instance.worker-1]

  create_duration = "150s"
}

resource "null_resource" "initial_commands_control_plane" {

  depends_on = [time_sleep.wait_instance]

  provisioner "file" {
    source      = "C:/Users/Deimos/.ssh/workers.pem"
    destination = "/home/ubuntu/.ssh/workers.pem"
  }


  provisioner "file" {
    source = "./control-plane.sh"
    destination = "/home/ubuntu/control-plane.sh"
  }

  connection {
    user        = "ubuntu"
    private_key = file("C:/Users/Deimos/.ssh/control-plane.pem")
    host        = aws_instance.control-plane.public_dns

  }
}

resource "null_resource" "run_commands_control_plane" {

  depends_on = [null_resource.initial_commands_control_plane]

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /home/ubuntu/control-plane.sh",
      "sudo chown -R ubuntu:ubuntu /home/ubuntu/.ssh/workers.pem",
      "bash /home/ubuntu/control-plane.sh && touch /home/ubuntu/script_complete"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /home/ubuntu/script_complete ]; do echo 'Command did not complete'; sleep 60; done",
      "echo 'Script execution completed.'"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "export JOIN_COMMAND=$(sudo kubeadm token create --print-join-command)",
      "printf \"sudo %s --v=5\" \"$JOIN_COMMAND\" >> /home/ubuntu/join.sh",
      "echo join.sh",
      "scp -o StrictHostKeyChecking=accept-new -i /home/ubuntu/.ssh/workers.pem /home/ubuntu/join.sh ubuntu@${aws_instance.worker-1.public_dns}:/home/ubuntu"
    ]
  }

  connection {
    user        = "ubuntu"
    private_key = file("C:/Users/Deimos/.ssh/control-plane.pem")
    host        = aws_instance.control-plane.public_dns

  }
}

##`Worker node`

resource "null_resource" "initial_commands_worker" {

  depends_on = [null_resource.run_commands_control_plane]

  provisioner "file" {
    source      = "./worker-node.sh"
    destination = "/home/ubuntu/worker-node.sh"
  }

  connection {
    user        = "ubuntu"
    private_key = file("C:/Users/Deimos/.ssh/workers.pem")
    host        = aws_instance.worker-1.public_dns

  }
}

resource "null_resource" "run_commands_worker" {

  depends_on = [null_resource.initial_commands_worker]

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /home/ubuntu/worker-node.sh",
      "sudo chmod +x /home/ubuntu/join.sh",
      "bash /home/ubuntu/worker-node.sh && touch /home/ubuntu/script_complete"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /home/ubuntu/script_complete ]; do echo 'Command did not complete'; sleep 60; done",
      "echo 'Script execution completed.'"
    ]
  }

  connection {
    user        = "ubuntu"
    private_key = file("C:/Users/Deimos/.ssh/workers.pem")
    host        = aws_instance.worker-1.public_dns
  }
}

resource "time_sleep" "wait_worker" {
  depends_on = [null_resource.run_commands_worker]

  create_duration = "10s"
}

resource "null_resource" "intialize_nginx_ingress_controller" {

  depends_on = [time_sleep.wait_worker]

  provisioner "remote-exec" {
    inline = [
      "helm install nginx-ingress oci://ghcr.io/nginxinc/charts/nginx-ingress --version 1.1.2 -n nginx-ingress --create-namespace "
    ]
  }
  

  connection {
    user        = "ubuntu"
    private_key = file("C:/Users/Deimos/.ssh/control-plane.pem")
    host        = aws_instance.control-plane.public_dns

  }
}