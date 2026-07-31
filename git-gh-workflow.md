# Git et GitHub pour LibFEM.jl — guide du débutant

Ce document explique comment travailler avec git et GitHub sur le dépôt LibFEM.jl.
Il est écrit pour un développeur Julia qui n'est pas un expert de git.
Les règles techniques (hooks, approbation, commits conventionnels) viennent de `AGENTS.md` :
lisez-le si vous voulez les détails exacts.

Deux métaphores reviennent partout dans ce guide :

- **Le commit est une photo.** Chaque commit est une photographie complète du code à un instant T, avec un numéro unique.
- **La branche est un post-it.** Une branche n'est rien d'autre qu'une étiquette collée sur un commit. Elle se déplace quand on commite.
- **La branche distante est un reflet.** `origin/master` n'est pas la réalité de GitHub, c'est le reflet (le cache) que votre machine a mémorisé au dernier `fetch`.

---

## Partie 1 — Les 4 concepts de base

### Commit

Un commit, c'est une **photo du code à un moment T**. git prend une photo complète de l'état de vos fichiers et lui donne un **numéro unique**, un hash hexadécimal court comme `fd82af9` ou `dae7080`. Ces numéros identifient le commit de façon unique, pour toujours.

Un commit **vit uniquement sur votre machine locale** tant que vous ne l'avez pas poussé. Il n'existe nulle part ailleurs. S'il n'est jamais poussé et que votre disque meurt, il est perdu.

> Exemple concret dans ce dépôt : votre `master` local était à `fd82af9` pendant que le `master` sur GitHub était à `dae7080`. Deux numéros différents, deux réalités différentes : votre machine et le serveur ne sont pas forcément d'accord.

### Push

Le **push**, c'est l'action d'**envoyer vos commits locaux vers GitHub** (le dépôt distant, le "remote").

- **Avant le push** : les commits n'existent que sur votre machine. Perdus si le disque meurt.
- **Après le push** : les commits sont sur le serveur GitHub. Ils y survivent.

En résumé : `git commit` prend la photo, `git push` l'envoie sur le serveur.

### Branch

Une **branche**, c'est une **ligne de travail parallèle**. Vous pouvez avoir plusieurs lignes d'évolution du code en même temps, qui ne se mélangent pas.

```
      D---E            ← branche "feature" (ligne de travail parallèle)
     /
A---B---C              ← branche "master" (la ligne principale)
```

Techniquement, **une branche est un pointeur, une étiquette, vers un commit**. Ce n'est pas un dossier de fichiers séparé. On y reviendra dans la Partie 2.

Il faut distinguer deux choses :

- **Une branche locale** (`feature`) : le pointeur sur **votre machine**. C'est vous qui la déplacez en committant.
- **Une branche distante** (`origin/feature`) : le **reflet en mémoire locale** de ce qui est sur GitHub. Ce reflet n'est mis à jour que par `git fetch` (ou `git pull`, qui fait fetch puis merge). Il peut être en retard sur la réalité du serveur.

### origin / origin/master / HEAD

- **`origin`** : le **nom conventionnel du dépôt distant**. Quand vous clonez le dépôt, git appelle le serveur d'origine `origin` par défaut. `git push origin master` veut dire "pousse vers le dépôt qui s'appelle origin".
- **`origin/master`** : littéralement, "**ce que je crois qu'il y a sur `master` côté GitHub, d'après mon dernier fetch**". C'est un reflet en cache, pas forcément à jour. Si quelqu'un d'autre a poussé sur GitHub et que vous n'avez pas fait de fetch, votre `origin/master` local est périmé.
- **`HEAD`** : la **branche active** en ce moment. C'est celle que vous voyez marquée d'une étoile `*` dans `git branch`. `HEAD` répond à la question "où suis-je ?".
- **`origin/HEAD -> origin/master`** : cette ligne, affichée par `git branch -a` ou `git remote show origin`, indique la **branche par défaut sur GitHub**. Ici : `master`.

---

## Partie 2 — Un commit se fait-il sur une branche ?

**Oui, toujours.** Chaque commit est fait sur une branche. Il n'existe pas de commit "flottant" dans le vide.

### Le mécanisme

Quand vous commitez, git fait deux choses :

1. Il crée le nouveau commit, avec **l'ancien commit comme parent** (chaîne de causalité : chaque commit connaît son parent).
2. Il **déplace le pointeur de la branche courante** sur ce nouveau commit.

La branche courante, c'est celle que désigne `HEAD`.

### L'image mentale

- **Le commit est gravé dans la pierre.** Une fois créé, on ne le modifie jamais, jamais. On peut seulement en créer de nouveaux.
- **La branche est un post-it collé sur un commit.** À chaque commit, le post-it se décolle et se recolle sur le nouveau commit.
- **`HEAD`, c'est "le post-it que je déplace"** : celui qui avance quand je commite.
- **`git checkout <branche>`** déplace `HEAD` sur un autre post-it. À partir de là, vos commits suivants déplacent cet autre post-it.

### Le piège : le detached HEAD

Si vous faites `git checkout <commit>` directement (avec un hash au lieu d'un nom de branche), `HEAD` ne pointe sur **aucun post-it**. On appelle ça un *detached HEAD*.

```
A---B---C---D
        ^
        HEAD directement sur le commit D, sans étiquette
```

Si vous committez dans cet état, le commit existe bien, mais **aucune branche ne le référence** : il est perdu de vue, introuvable dans `git branch`. Il reste récupérable un temps via `git reflog` (l'historique des déplacements de HEAD), mais c'est fragile et pénible.

**Règle simple : pour travailler sur un ancien commit, créez toujours une branche d'abord.**

```bash
git checkout -b ma-branche-de-travail <commit>
```

Comme ça, le post-it existe, et votre travail reste visible.

---

## Partie 3 — Fetch, PR, squash merge

### `git fetch` : mettre à jour les reflets, sans risque

Le **fetch** télécharge les commits manquants depuis GitHub et **met à jour les reflets `origin/*`** sur votre machine. C'est tout.

Il **ne touche jamais** :

- à votre branche locale ;
- à vos commits non poussés ;
- à vos fichiers de travail.

C'est une **opération sans risque** : vous pouvez la faire à n'importe quel moment, elle ne casse rien. Elle ne fait que rafraîchir votre vision de ce qui existe sur le serveur.

Deux commandes voisines :

- **`git pull`** = `git fetch` **+** `git merge`. On récupère les reflets *et* on intègre les changements dans la branche locale. C'est le fetch qui met à jour `origin/*`, le merge qui met à jour votre branche locale.
- **`git fetch --prune`** : en plus du fetch normal, `--prune` **supprime les reflets `origin/xxx` des branches qui ont été supprimées sur GitHub**. C'est très utile ici, parce que GitHub propose de supprimer les branches après chaque merge (voir plus bas). Sans `--prune`, votre machine garde des reflets fantômes de branches qui n'existent plus sur le serveur.

### Les Pull Requests (PR)

Une **Pull Request** (ou **PR**), c'est une demande : "intègre ma branche dans une autre, après l'avoir revue". C'est le mécanisme standard de collaboration sur GitHub.

Le workflow type :

```bash
git checkout -b fix/typo                 # 1. nouvelle branche
# ... corriger la typo ...
git add <fichier>
git commit -m "fix(docs): corrige une typo"
git push origin fix/typo                  # 2. pousser la branche
# 3. sur GitHub : bouton "Create Pull Request" (ou `gh pr create`)
# 4. revue de la PR par un relecteur
# 5. merge de la PR
```

Après le merge, **GitHub propose de supprimer la branche source**. C'est pour ça que les branches disparaissent du remote : la suppression proposée par GitHub est un geste normal et encouragé. Une branche fusionnée ne sert plus à rien (voir la Partie 4).

> Exemple concret dans ce dépôt : les branches locales `fix/ci-eigvals-complex-error`, `feat/kattan-problems-9-10-11` et `kattan-matlab-one-to-one-2026-07-30` ont été poussées, puis fusionnées sur GitHub via les PR #125 à #128, puis les branches distantes ont été supprimées (le geste que GitHub propose). Les branches locales correspondantes ont ensuite été supprimées comme inutiles : le travail existait déjà sur le remote.

### Le squash merge

Le **squash merge** fusionne une branche dans une autre en **écrasant TOUS ses commits en UN SEUL**.

```
Avant le squash :
  A → B → C → D → E        ← la branche feature (5 petits commits)

Après le squash (fusion dans master) :
  ... → S                  ← master, S = UN seul commit qui résume A→B→C→D→E
```

#### Les conséquences, à connaître absolument

1. **Les commits A, B, C, D, E n'existent pas dans `master`.** Ce qui existe dans master, c'est le nouveau commit `S`, avec un **numéro différent**. L'historique de la branche est aplati.
2. `git merge-base --is-ancestor <ancien-commit> origin/master` **répond NO** (code de sortie 1), même si le contenu du travail est bien présent dans master. Cet outil vérifie la filiation des commits, pas le contenu.
3. `git branch --no-merged` **liste la branche**, même si son contenu a été fusionné. Encore une fois, git raisonne en filiation de commits, pas en contenu.

#### Pourquoi s'en servir

Une **histoire propre** : sur master, un commit = une feature. Au lieu de 5 commits "wip", "correction", "oups", vous avez un seul commit net, facile à lire et à re-parcourir.

#### Le piège

**Ne jamais re-pousser une branche qui a été squashée** (ni la repousser après l'avoir amendée ou rebasée). Repousser forcerait git à réécrire des commits déjà sur le remote, ce qui casse l'historique de tout le monde. Si la branche a été fusionnée, elle est morte : on la supprime, on ne la ressuscite pas.

#### La règle

**Une branche fusionnée = une branche morte, on la supprime.**

---

## Partie 4 — Workflow simple pour développer une feature sur LibFEM.jl

Voici le cycle complet, en 7 étapes, adapté aux hooks du dépôt (vérifiés dans `AGENTS.md`).

### Étape 1 — Départ

```bash
git checkout master
git pull --ff-only origin master
```

On revient sur master et on le met à jour. `--ff-only` veut dire "fast-forward seulement" : si votre master local a divergé de l'origin, la commande refuse de fusionner, elle vous prévient. C'est une sécurité.

### Étape 2 — Branche

```bash
git checkout -b feat/mon-ajout
```

Nouvelle branche de travail. Convention de nommage du projet : `feat/` pour une feature, `fix/` pour un correctif.

### Étape 3 — Travailler et committer

```bash
git add <fichier>            # préparer un fichier
git diff --cached            # RELIRE ce qui va être committé
git commit -m "feat(scope): description"
```

Deux points importants :

- **Relisez avant de committer.** `git diff --cached` montre exactement ce qui partira dans le commit. C'est votre dernier moment de contrôle.
- **Conventional commits** : le message suit le format `type(scope): description`, par exemple `feat(solver): ajoute la fonction X` ou `fix(truss): corrige le calcul d'effort`. C'est une règle du dépôt.
- **Petits commits réguliers valent mieux** qu'un gros commit à la fin. Chaque commit est une photo nette d'une étape logique.

> Note sur les hooks du dépôt : le commit exige la variable `GIT_APPROVED`, et le push exige la ligne `Approved-by:` dans le corps du message de commit. Les hooks demandent un terminal interactif (TTY) : c'est pour ça que c'est vous qui lancez `git commit` et `git push` dans votre propre terminal, avec les commandes exactes fournies. Le détail des hooks est dans `AGENTS.md`.

### Étape 4 — Pousser

```bash
git push origin feat/mon-ajout
```

La branche (avec ses commits) part sur GitHub. C'est le moment où votre travail devient visible par tout le monde.

### Étape 5 — Pull Request

```bash
gh pr create --title "..." --body "..."
```

`gh` est l'outil en ligne de commande de GitHub. Cette commande crée la PR depuis votre branche vers `master`. Vous pouvez aussi la créer depuis le site GitHub.

### Étape 6 — Tester et merger

Une fois que la CI est verte (les tests automatisés passent, y compris la validation Octave du projet) :

```bash
gh pr merge --merge --delete-branch --admin
```

Décortiquons les options :

- `--merge` : fusionne en **gardant les commits** de la branche (fusion classique). C'est le choix proposé par le workflow du dépôt.
- `--squash` : l'alternative, qui **aplatit** tous les commits en un seul (voir Partie 3).
- `--delete-branch` : **supprime la branche sur GitHub** après la fusion. Le geste que GitHub vous propose de toute façon.
- `--admin` : contourne les protections éventuelles de la branche.
- Important : `--delete-branch` supprime la branche **sur GitHub, pas sur votre machine**. Votre branche locale reste intacte.

### Étape 7 — Nettoyage

```bash
git checkout master
git pull --ff-only origin master
git branch -d feat/mon-ajout
```

- On revient sur master et on le met à jour : il contient maintenant votre travail fusionné.
- `git branch -d` supprime la branche locale **seulement si elle a été fusionnée**. Si elle ne l'est pas, la commande **refuse** : c'est une sécurité qui vous évite de perdre du travail. Si vous tenez vraiment à supprimer une branche non fusionnée, il faudrait `git branch -D` (capital D), mais c'est à éviter.

### Le cycle en image

```
A --- B --- C                          ← master, le point de départ
          \
           D --- E --- F               ← feat/mon-ajout, votre travail

Après la PR fusionnée (étape 6) :

A --- B --- C --- C'                   ← master, C' contient tout le travail D+E+F
          \
           D --- E --- F               ← la branche feature : morte, à supprimer
```

> Exemple concret : après les fusions squash des PR #125 à #128, votre master local était resté en arrière de 7 commits (`fd82af9` local contre `dae7080` sur GitHub). Un simple `git pull --ff-only origin master` a rattrapé le retard. C'est exactement la situation des étapes 1 et 7.

### Les 3 règles d'or (règles absolues du dépôt, tirées de `AGENTS.md`)

1. **Jamais de commit, push, PR ou merge sans approbation explicite de l'utilisateur.** C'est la règle numéro un du projet. Les hooks la font respecter : le commit exige `GIT_APPROVED`, le push exige `Approved-by:` dans le corps du commit, et le tout demande un terminal interactif. (`CI=true` contourne le garde TTY, mais uniquement pour l'automatisation.) Séquence obligatoire : proposer, attendre l'approbation, exécuter.
2. **Une branche fusionnée = une branche morte.** On supprime la branche distante (via `--delete-branch` ou le bouton de GitHub) et la branche locale (`git branch -d`).
3. **`master` ne se modifie jamais directement.** Toute modification passe par une branche + une PR. On ne commite jamais directement sur master.

---

## Aide-mémoire

| Objectif | Commande |
|---|---|
| État actuel du dépôt | `git status` |
| Lister les branches (le `*` = HEAD) | `git branch` |
| Lister aussi les reflets distants | `git branch -a` |
| Créer une branche et y aller | `git checkout -b feat/mon-ajout` |
| Revenir sur master | `git checkout master` |
| Mettre à jour master (refus si divergence) | `git pull --ff-only origin master` |
| Rafraîchir les reflets distants (sans risque) | `git fetch --prune` |
| Préparer un fichier pour le commit | `git add <fichier>` |
| Relire ce qui sera committé | `git diff --cached` |
| Committer (format conventionnel, approuvé) | `GIT_APPROVED='<message-id>' git commit -m "feat(scope): description"` |
| Pousser la branche sur GitHub | `git push origin feat/mon-ajout` |
| Créer une Pull Request | `gh pr create --title "..." --body "..."` |
| Fusionner la PR (garde les commits) | `gh pr merge --merge --delete-branch --admin` |
| Fusionner la PR (aplatit en un commit) | `gh pr merge --squash --delete-branch --admin` |
| Supprimer une branche locale fusionnée | `git branch -d feat/mon-ajout` |
| Lister les branches non fusionnées | `git branch --no-merged` |
| Un commit est-il déjà dans origin/master ? | `git merge-base --is-ancestor <commit> origin/master` |
| Activer les hooks du dépôt (à faire une fois) | `git config core.hooksPath .githooks` |

En cas de doute : `git status` pour voir où vous êtes, `git log --oneline` pour voir les commits récents, et `git fetch --prune` pour rafraîchir votre vision du serveur. Rien de tout cela ne casse quoi que ce soit.
