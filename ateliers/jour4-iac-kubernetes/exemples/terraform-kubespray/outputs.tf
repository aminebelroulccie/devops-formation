output "floating_ips" {
  description = "Elastic IP de chaque nœud (node1, node2, node3)"
  value       = { for i, n in local.nodes : n => aws_eip.node[i].public_ip }
}

output "private_ips" {
  description = "IP privées des nœuds dans le sous-réseau commun"
  value       = { for i, n in local.nodes : n => aws_instance.node[i].private_ip }
}

output "ssh" {
  description = "Connexion à chaque nœud"
  value       = [for i, n in local.nodes : "ssh ubuntu@${aws_eip.node[i].public_ip}   # ${n}"]
}

output "kubespray_inventory" {
  description = "Inventaire prêt pour Kubespray"
  value       = local_file.kubespray_inventory.filename
}

output "kube_api" {
  description = "Adresse de l'API Kubernetes une fois Kubespray terminé"
  value       = "https://${aws_eip.node[0].public_ip}:6443"
}
