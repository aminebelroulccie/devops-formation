# AWS access for the training (day 4)

_English version · la version française est dans [`README.md`](README.md)_

## To prepare (D-7)

1. **Dedicated IAM user** `formini-devops-formation` with programmatic access (access key) and, if possible, console access. Attach the `iam-policy-formation.json` policy (EC2, VPC, EKS, limited IAM and limited S3 rights, locked to **eu-west-3** and to small instance types).
2. **Budget alert**: AWS Budgets → monthly budget (e.g. 50 USD) with e-mail alerts at 50%, 80% and 100%.
3. **Quotas**: check that the account can launch at least *2 × number of participants* `t3.micro` instances in eu-west-3 (Service Quotas → EC2 → Running On-Demand Standard instances, vCPU).
4. Test `ateliers/jour4-iac-kubernetes/solution/terraform` yourself: `init`, `apply`, `destroy` (≈ 5 minutes).

## On the day

Hand out the keys **verbally or on paper**, never through Gitea. Each participant loads them into their shell:

```bash
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=eu-west-3
export TF_VAR_owner="firstname"       # Owner tag on every resource
aws sts get-caller-identity           # must display the account
```

## Every evening

```bash
bash cleanup-check.sh
```

Nothing must be left behind: instances, VPCs, Elastic IPs, volumes. Resources are tagged `Project=formation-devops` and `Owner=<firstname>`, so you can quickly find out who forgot something.

## After the training

- Deactivate, then delete the IAM user's access keys.
- Check the bill in Cost Explorer, filtered on the `Project` tag.
