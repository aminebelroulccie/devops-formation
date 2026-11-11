# Terraform sur AWS — trois nœuds prêts pour Kubespray

_English version: [`README.en.md`](README.en.md)_

Trois machines Ubuntu 24.04 dans **le même sous-réseau**, reliées à Internet par une **Internet
Gateway** (le routeur du VPC), chacune avec une **Elastic IP** (l'IP flottante d'AWS : fixe,
détachable, réattribuable), et un inventaire Kubespray généré automatiquement.

```
                 Internet
                    │
          ┌─────────┴─────────┐
          │ Internet Gateway  │   route 0.0.0.0/0 du sous-réseau ; DNAT des Elastic IP
          └─────────┬─────────┘
   VPC 10.42.0.0/16 · sous-réseau public 10.42.1.0/24 (un seul, commun)
      │              │              │
   node1 .11      node2 .12      node3 .13      ← IP privées fixes
   EIP 1          EIP 2          EIP 3          ← Elastic IP, une par nœud
   control plane  worker         worker
   etcd           etcd           etcd
```

| Fichier | Contenu |
|---------|---------|
| `versions.tf` | providers `aws ~> 5.0` et `local`, tags par défaut (`Project`, `Owner`, `ManagedBy`) |
| `variables.tf` | `owner`, `node_count` (3), `instance_type` (`t3.medium`), `admin_cidr`, CIDR… |
| `main.tf` | VPC, sous-réseau, Internet Gateway, table de routage, groupe de sécurité, clé, 3 instances, 3 Elastic IP, inventaire |
| `cloud-init.yaml` | préparation des nœuds : nom d'hôte, swap désactivé, modules et sysctl Kubernetes |
| `inventory.tpl` | gabarit de l'inventaire Kubespray (`hosts.yaml`) rempli par Terraform |
| `outputs.tf` | Elastic IP, IP privées, commandes `ssh`, chemin de l'inventaire, URL de l'API |

Ce que crée `terraform apply` :

1. **Réseau** : un VPC `10.42.0.0/16`, un sous-réseau `10.42.1.0/24`, l'Internet Gateway et la
   route par défaut qui y mène.
2. **Pare-feu** (groupe de sécurité) : tout le trafic **entre nœuds** (etcd, kubelet, CNI,
   IP-in-IP), et depuis `admin_cidr` seulement : SSH 22, API Kubernetes 6443, NodePorts 30000-32767.
3. **Clé SSH** : votre clé publique du jour 1.
4. **Trois nœuds** `node1`, `node2`, `node3` (`t3.medium`, 30 Go gp3) aux IP privées prévisibles
   `.11`, `.12`, `.13`, préparés par cloud-init, `source_dest_check` désactivé pour Calico.
5. **Trois Elastic IP**, une par nœud, associées aux instances.
6. **`inventory/hosts.yaml`** : l'inventaire Kubespray, écrit par Terraform à partir des IP réelles.

## 1. Créer l'infrastructure

```bash
cd ateliers/jour4-iac-kubernetes/exemples/terraform-kubespray
cp terraform.tfvars.example terraform.tfvars && nano terraform.tfvars   # owner, admin_cidr
aws sts get-caller-identity                                              # mêmes identifiants qu'au jour 4
terraform init
terraform plan
terraform apply            # 2 à 3 minutes
terraform output           # Elastic IP, commandes ssh, chemin de l'inventaire
```

Testez : `ssh ubuntu@<EIP de node1>` puis, depuis node1, `ping 10.42.1.12` (les nœuds se voient
par leurs IP privées) et `curl -I https://deb.debian.org` (sortie Internet par la gateway).

## 2. Installer Kubernetes avec Kubespray

Depuis votre poste ou la VM Formini (Python 3.10+, accès SSH aux trois Elastic IP) :

```bash
git clone --branch v2.26.0 --depth 1 https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# l'inventaire généré par Terraform + la configuration par défaut de Kubespray
cp -r inventory/sample inventory/formini
cp ../terraform-kubespray/inventory/hosts.yaml inventory/formini/hosts.yaml
ansible -i inventory/formini/hosts.yaml all -m ping           # les trois nœuds répondent "pong"

# 15 à 25 minutes
ansible-playbook -i inventory/formini/hosts.yaml cluster.yml -b -v

# récupérer le kubeconfig depuis le control plane et le faire pointer sur l'Elastic IP
ssh ubuntu@<EIP node1> 'sudo cat /etc/kubernetes/admin.conf' > ~/.kube/formini.conf
sed -i 's#https://10.42.1.11:6443#https://<EIP node1>:6443#' ~/.kube/formini.conf
export KUBECONFIG=~/.kube/formini.conf
kubectl get nodes -o wide
```

Réglages Kubespray utiles avant de lancer `cluster.yml` (fichiers dans `inventory/formini/group_vars/`) :

- `k8s_cluster/k8s-cluster.yml` : `kube_network_plugin: calico` (défaut), `cluster_name: formini.local`,
  `supplementary_addresses_in_ssl_keys: [<EIP node1>]` pour que le certificat de l'API accepte
  l'Elastic IP (sinon `kubectl` doit utiliser `--insecure-skip-tls-verify`).
- `k8s_cluster/addons.yml` : `metrics_server_enabled: true`, `ingress_nginx_enabled: true`.

Ensuite, la pile Go + React du jour 4 se déploie telle quelle :
`kubectl apply -k ../exemples/go-react/k8s/` ; le Service NodePort 30081 est joignable sur
`http://<EIP de n'importe quel nœud>:30081` (le port 30081 est dans la plage ouverte par le pare-feu).

Pour partager ce cluster entre les étudiants, un namespace et un kubeconfig chacun :
[`../namespaces-etudiants/`](../namespaces-etudiants/README.md).

## 3. Détruire

```bash
terraform destroy
```

Trois `t3.medium` et trois Elastic IP coûtent de l'argent à l'heure (et une Elastic IP non
associée est facturée même instance arrêtée) : on détruit en fin de séance, et le formateur
vérifie avec `setup/aws/cleanup-check.sh`.

## Ce qu'il faut observer

- **L'Elastic IP est une ressource à part** (`aws_eip`), associée à l'instance par
  `aws_eip_association` : on peut remplacer une instance et lui rendre la même adresse publique.
  `associate_public_ip_address = false` évite une deuxième IP publique éphémère inutile.
- **`cidrhost(var.subnet_cidr, 11 + count.index)`** : des adresses calculées, pas écrites en dur,
  et le même code pour 3 ou 5 nœuds (`node_count`).
- **`templatefile` + `local_file`** : Terraform génère l'inventaire Ansible ; l'infrastructure et
  son inventaire ne divergent jamais.
- **Trafic interne par référence au groupe** (`referenced_security_group_id`), pas par plage
  d'adresses : un nœud ajouté est automatiquement autorisé.
- **`source_dest_check = false`** : sans lui, AWS jette le trafic des pods que Calico route
  (adresse source différente de celle de l'instance).

## Exercices

1. Passez `node_count` à 5, `terraform apply` : que change l'inventaire ? Que faut-il relancer
   côté Kubespray (`scale.yml`) ?
2. Ajoutez un output `ssh_config` qui génère un bloc `Host node1 … node3` pour `~/.ssh/config`.
3. Mettez l'état dans un backend S3 (bucket du formateur) pour que l'équipe partage le même état.
4. Restreignez `admin_cidr` à votre IP publique `/32` et vérifiez qu'un coéquipier ne peut plus
   joindre le port 6443.
