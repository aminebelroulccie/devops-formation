# Solution — Jour 3 : pipeline CI/CD

Fichiers à copier à la racine du dépôt `formini-tasks` :

```
.gitea/
├── workflows/
│   ├── ci.yml          # test → build (scan + publication) à chaque push / PR
│   └── release.yml     # publication d'une version sur tag v*
└── pull_request_template.md
```

Adapter dans les deux workflows la variable `IMAGE` au nom de votre organisation.

## Secrets à créer

Les workflows lisent deux secrets. Sans eux, le step « Connexion au registre » échoue
avec `unauthorized`.

### 1. Jeton d'accès Gitea

Avatar → **Paramètres** → **Applications** → *Gérer les jetons d'accès* → *Générer un jeton* :

| Champ | Valeur |
|-------|--------|
| Nom du jeton | `ci-registry` |
| Permissions | **package** : *Read and Write* (tout le reste : *No access*) |

Copier le jeton immédiatement : Gitea ne l'affiche qu'une fois.

> Le jeton a les droits de l'utilisateur qui le crée. Pour publier dans les paquets
> de l'organisation `equipe-a`, cet utilisateur doit être membre de l'organisation
> avec le droit d'écriture sur les paquets (équipe *Owners* ou équipe avec l'unité
> *Paquets* en écriture).

### 2. Secrets du dépôt (ou de l'organisation)

Dépôt → **Paramètres** → **Actions** → **Secrets** :

| Nom | Valeur |
|-----|--------|
| `REGISTRY_USER` | le nom d'utilisateur Gitea (le login, pas l'e-mail) |
| `REGISTRY_TOKEN` | le jeton créé ci-dessus |

Déclarés au niveau de l'organisation (Organisation → Paramètres → Actions → Secrets),
ils sont disponibles dans tous les dépôts de l'équipe.

## Vérifications sur la VM qui porte le runner

```bash
sudo systemctl status act_runner          # actif ?
node --version                            # requis par actions/checkout
docker info | grep -A1 'Insecure Registries'   # doit lister gitea.formini.local:3000
trivy --version
echo "<JETON>" | docker login gitea.formini.local:3000 -u <login> --password-stdin && docker logout gitea.formini.local:3000
```

## Protection de branche

Dépôt → **Paramètres** → **Branches** → règle `main` :

- *Activer le push* : décoché
- *Activer la vérification de statut* : coché, motif `CI / test*`
  (le contexte publié par Gitea Actions est `CI / test (pull_request)`)
- *Approbations requises* : 1

## Pourquoi un seul job `build` ?

En mode host, chaque job est confié à **un runner libre parmi ceux de l'équipe**.
Si `scan` et `publish` étaient des jobs distincts, ils pourraient être exécutés par
une autre VM que celle qui a construit l'image, et `trivy image` ou `docker push`
échoueraient avec *image not found*. Un seul job garantit que tous les steps
partagent le même démon Docker. Avec un unique runner, ou un registre intermédiaire
(push de l'image avant le scan), la découpe en trois jobs redevient possible.
