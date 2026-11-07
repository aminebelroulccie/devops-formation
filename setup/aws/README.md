# Accès AWS pour la formation (jour 4)

## À préparer (J-7)

1. **Utilisateur IAM dédié** `formini-devops-formation` avec accès programmatique (clé d'accès) et, si possible, accès console. Attachez la politique `iam-policy-formation.json` (droits EC2, VPC, EKS, IAM limité, S3 limité, verrouillée sur **eu-west-3** et sur les petits types d'instance).
2. **Alerte budgétaire** : AWS Budgets → budget mensuel (ex. 50 USD) avec alerte e-mail à 50 %, 80 %, 100 %.
3. **Quotas** : vérifiez que le compte peut lancer au moins *2 × nombre de participants* instances `t3.micro` dans eu-west-3 (Service Quotas → EC2 → Running On-Demand Standard instances, vCPU).
4. Testez vous-même `ateliers/jour4-iac-kubernetes/solution/terraform` : `init`, `apply`, `destroy` (≈ 5 minutes).

## Le jour J

Distribuez les clés **oralement ou sur fiche papier**, jamais dans Gitea. Chaque participant les charge dans son shell :

```bash
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=eu-west-3
export TF_VAR_owner="prenom"          # tag Owner sur toutes les ressources
aws sts get-caller-identity           # doit afficher le compte
```

## Chaque soir

```bash
bash cleanup-check.sh
```

Rien ne doit rester : instances, VPC, IP élastiques, volumes. Les ressources sont taguées `Project=formation-devops` et `Owner=<prénom>` : retrouvez vite le responsable d'un oubli.

## Après la formation

- Désactivez puis supprimez les clés d'accès de l'utilisateur IAM.
- Vérifiez la facture dans Cost Explorer filtrée sur le tag `Project`.
