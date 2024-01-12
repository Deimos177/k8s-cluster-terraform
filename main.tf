provider "aws" {
  region  = "sa-east-1"
  profile = "default"
}

resource "aws_instance" "control-plane" {
  ami                    = "ami-08721da16b7931382" #Replace these field with your AMI ID
  instance_type          = "t3.medium" #Replace these field with your prefered instance_type
  key_name               = "control-plane" #Replace these field with your private-key file
  monitoring             = true
  vpc_security_group_ids = ["sg-078c4155707cbd1f5"] #Replace these field with your security group ID
  subnet_id              = "subnet-099e843146bf4e39e" #Replace these field with your Subnet ID

  tags = {
    Terraform   = "true"
    Environment = "study"
    Autor       = "Bruce Vieira"
    node = "control-plane"
  }
}

resource "aws_instance" "worker-1" {

  depends_on = [aws_instance.control-plane]

  ami                    = "ami-08721da16b7931382" #Replace these field with your AMI ID
  instance_type          = "t3.medium" #Replace these field with your prefered instance_type
  key_name               = "workers" #Replace these field with your private-key file
  monitoring             = true
  vpc_security_group_ids = ["sg-078c4155707cbd1f5"] #Replace these field with your security group ID
  subnet_id              = "subnet-099e843146bf4e39e" #Replace these field with your Subnet ID

  tags = {
    Terraform   = "true"
    Environment = "study"
    Autor       = "Bruce Vieira"
    node = "worker-1"
  }
}

#Wait time for the control-plane get ready to run commands

resource "time_sleep" "wait_instance" {
  depends_on = [aws_instance.control-plane, aws_instance.worker-1]

  create_duration = "90s"
}

resource "null_resource" "initial_commands_control_plane" {

  depends_on = [time_sleep.wait_instance]

  provisioner "file" {
    source      = "./control-plane.sh"
    destination = "/home/ubuntu/control-plane.sh"
  }

  provisioner "file" {
    source      = "../workers.pem" #Replace the source private key file with the path for your local private key file
    destination = "/home/ubuntu/.ssh/workers.pem"
  }

  connection {
    user        = "ubuntu"
    private_key = file("../control-plane.pem") #Replace the source private key file with the path for your local private key file
    host        = aws_instance.control-plane.public_dns

  }
}

resource "null_resource" "run_commands_control_plane" {

  depends_on = [null_resource.initial_commands_control_plane]

  provisioner "remote-exec" {
    inline = [
      "bash /home/ubuntu/control-plane.sh && touch /home/ubuntu/script_complete"
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
    private_key = file("../control-plane.pem") #Replace the source private key file with the path for your local private key file
    host        = aws_instance.control-plane.public_dns

  }
}

##`Worker node`

resource "null_resource" "initial_commands_worker" {

  depends_on = [time_sleep.wait_instance, null_resource.run_commands_control_plane]

  provisioner "file" {
    source      = "./worker-node.sh"
    destination = "/home/ubuntu/worker-node.sh"
  }

  connection {
    user        = "ubuntu"
    private_key = file("../workers.pem") #Replace the source private key file with the path for your local private key file
    host        = aws_instance.worker-1.public_dns

  }
}

resource "null_resource" "run_commands_worker" {

  depends_on = [null_resource.initial_commands_worker]

  provisioner "remote-exec" {
    inline = [
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
    private_key = file("../workers.pem") #Replace the source private key file with the path for your local private key file
    host        = aws_instance.worker-1.public_dns
  }
}

#join worker-node

#This step isn't working, for while will stand commented until i discover the problem

# resource "null_resource" "join_node" {

#   depends_on = [null_resource.run_commands_worker]


#   provisioner "remote-exec" {
#     inline = [
#       "echo \"Run join command to worker-1\"",
#       "export JOIN_COMMAND=$(sudo kubeadm token create --print-join-command)",
#       "ssh -o StrictHostKeyChecking=accept-new -i /home/ubuntu/.ssh/workers.pem ubuntu@${aws_instance.worker-1.public_dns} \"sudo bash -s\" <<< \"$JOIN_COMMAND\""
#     ]
#   }

#   connection {
#     user        = "ubuntu"
#     private_key = file("../control-plane.pem")
#     host        = aws_instance.control-plane.public_dns

#   }
# }