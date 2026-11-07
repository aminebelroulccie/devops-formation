output "public_ip" {
  description = "Adresse IP publique du serveur"
  value       = aws_instance.web.public_ip
}

output "ssh" {
  description = "Commande de connexion"
  value       = "ssh -i ~/.ssh/id_ed25519 ubuntu@${aws_instance.web.public_ip}"
}

output "app_url" {
  description = "URL de l'application une fois le playbook Ansible joué"
  value       = "http://${aws_instance.web.public_ip}:5000"
}

output "ansible_inventory" {
  description = "Ligne à coller dans ansible/inventory.ini"
  value       = "${aws_instance.web.public_ip} ansible_user=ubuntu"
}
