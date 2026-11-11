# Un namespace par étudiant, avec tous les droits dedans et aucun ailleurs

_English version: [`README.en.md`](README.en.md)_

Pour un cluster **partagé** (celui de [`terraform-kubespray/`](../terraform-kubespray/README.md),
ou le kind du formateur) : chaque étudiant reçoit son namespace, un kubeconfig qui n'ouvre que
celui-ci, un quota, et des limites par défaut. Six étudiants par défaut (`students.txt`), les
logins Formini `formini-a1` … `formini-b3`.

```
students.txt ──generate.sh──► generated/<login>.yaml ──kubectl apply──► cluster
                                                                            │
                                                     make-kubeconfigs.sh ◄──┘
                                                            │
                                                  kubeconfigs/<login>.conf  → à remettre à chaque étudiant
                                                            │
                                                        verify.sh  (auth can-i : oui chez soi, non ailleurs)
```

| Objet créé par étudiant | Rôle |
|-------------------------|------|
| Namespace `<login>` | son espace, étiqueté `student=<login>` |
| ServiceAccount `<login>` | son identité |
| Secret `<login>-token` | jeton durable du ServiceAccount (valable toute la semaine, révocable en supprimant le Secret) |
| RoleBinding `<login>-admin` → ClusterRole **`admin`** | **accès complet dans le namespace** : Deployments, StatefulSets, Services, Secrets, ConfigMaps, PVC, Ingress, Roles et RoleBindings… ; **rien en dehors** : pas de lecture des autres namespaces, pas de nœuds, pas de création ni suppression de namespace, pas de modification du quota |
| ResourceQuota `quota` | 2 CPU / 4 Gi demandés, 4 CPU / 8 Gi limites, 30 pods, 2 NodePorts, 4 PVC, 10 Gi |
| LimitRange `defaults` | requests et limits appliquées aux conteneurs qui n'en déclarent pas (sinon le quota les refuserait) |

Pourquoi le ClusterRole `admin` fourni par Kubernetes plutôt qu'un Role `*` maison : il est
maintenu avec les versions de Kubernetes, il couvre tout ce dont un développeur a besoin dans
son namespace, et il exclut exactement ce qu'un étudiant ne doit pas toucher (le Namespace
lui-même, les ResourceQuotas, les LimitRanges).

## Mise en place (formateur, avec le kubeconfig administrateur du cluster)

```bash
cd ateliers/jour4-iac-kubernetes/exemples/namespaces-etudiants
nano students.txt                      # un login par ligne
bash generate.sh --apply               # crée les 6 × 6 objets
bash make-kubeconfigs.sh https://<IP de l'API vue par les étudiants>:6443
bash verify.sh                         # 11 vérifications par étudiant, toutes "ok"
```

Pour le cluster Kubespray sur AWS, l'URL de l'API est `https://<Elastic IP de node1>:6443`
(ajoutez-la dans `supplementary_addresses_in_ssl_keys` avant de lancer Kubespray). Pour un kind
sur la VM du formateur, recréez le cluster avec `networking.apiServerAddress: "<IP de la VM>"`
dans `kind-config.yaml`, sinon l'API n'écoute que sur `127.0.0.1`.

Puis remettez à chaque étudiant **son** fichier, et uniquement le sien :

```bash
scp kubeconfigs/formini-a1.conf devops@<VM de formini-a1>:~/.kube/config
```

## Côté étudiant

```bash
kubectl config current-context        # formini-a1
kubectl get pods                      # son namespace par défaut : vide, pas d'erreur
kubectl get pods -n formini-a2        # Error from server (Forbidden)
kubectl get namespaces                # Forbidden
kubectl apply -k ../go-react/k8s/     # refusé : les manifestes visent le namespace formini-go
```

Pour déployer la pile Go + React dans **son** namespace, l'étudiant change une ligne de
`k8s/kustomization.yaml` (`namespace: formini-a1`) et retire `namespace.yaml` des `resources`,
puis `kubectl apply -k`. Les deux StatefulSets, les quatre Services et les ConfigMaps tiennent
dans le quota ; le Service NodePort 30081 ne peut être pris que par un seul étudiant du cluster :
les autres utilisent `kubectl port-forward svc/frontend 8081:80` ou changent `nodePort`.

## Ce qu'il faut observer

- **RoleBinding, pas ClusterRoleBinding** : le même ClusterRole `admin` lié dans un namespace ne
  donne des droits que là. Un ClusterRoleBinding donnerait `admin` sur tout le cluster.
- **Le quota se voit** : `kubectl describe quota` dans son namespace montre l'utilisation.
  Un `kubectl scale --replicas=50` est refusé avec un message explicite.
- **Le LimitRange rend le quota vivable** : sans lui, tout pod sans `resources` serait refusé
  par le quota `requests.cpu`.
- **Un jeton = un Secret** : `kubectl -n formini-a1 delete secret formini-a1-token` révoque
  l'accès à l'instant ; `generate.sh --apply` le recrée (nouveau jeton, nouveau kubeconfig).
- **Pas d'isolation réseau ici** : les pods d'un namespace peuvent joindre ceux d'un autre par
  leur nom DNS complet (`api.formini-a2.svc`). L'isoler demande des NetworkPolicies et un CNI
  qui les applique (Calico sur Kubespray, oui ; kindnet sur kind, non).

## Exercices

1. Ajoutez un septième login, relancez les trois scripts : rien n'est modifié pour les six autres
   (`kubectl apply` est idempotent).
2. Remplacez `admin` par `edit` dans le gabarit pour un étudiant : que ne peut-il plus faire ?
   (`kubectl auth can-i create rolebindings`).
3. Ajoutez une NetworkPolicy « deny depuis les autres namespaces » au gabarit et testez-la sur
   le cluster Kubespray avec `kubectl run -n formini-a2 curl --image=curlimages/curl -- …`.
4. Donnez au formateur un accès lecture seule à tous les namespaces avec un ClusterRoleBinding
   sur le ClusterRole `view`.

## Nettoyage

```bash
kubectl delete -f generated/all.yaml       # supprime les namespaces, donc tout leur contenu
rm -rf kubeconfigs/                        # les jetons ne valent plus rien, mais on ne les laisse pas traîner
```
