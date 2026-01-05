output "ami_id" {
  value = module.myapp-webserver.aws_ami_id
}

output "ec2_public_ip" {
  value = module.myapp-webserver.instance.public_ip
}
