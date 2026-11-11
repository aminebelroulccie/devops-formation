# Inventaire Kubespray généré par Terraform — ne pas modifier à la main, relancer terraform apply.
# ansible_host : IP flottante (accès depuis votre poste) ; ip / access_ip : IP privée (trafic du cluster).
all:
  hosts:
%{ for n in nodes ~}
    ${n.name}:
      ansible_host: ${n.fip}
      ip: ${n.ip}
      access_ip: ${n.ip}
      ansible_user: ${ssh_user}
%{ endfor ~}
  children:
    kube_control_plane:
      hosts:
        ${nodes[0].name}:
    kube_node:
      hosts:
%{ for n in nodes ~}
        ${n.name}:
%{ endfor ~}
    etcd:
      hosts:
%{ for n in nodes ~}
        ${n.name}:
%{ endfor ~}
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
    calico_rr:
      hosts: {}
