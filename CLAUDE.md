# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An Ansible playbook that bootstraps a fresh Ubuntu machine into a KinD (Kubernetes-in-Docker)
development environment: Docker, kubectl/kind/helm/kustomize/kubie, Tekton/ko, Terraform, a
Node/nvm toolchain, Claude Code, dotfile/shell config, a GNOME tiling extension, and dnsmasq
(package only -- per-project KinD DNS entries, e.g. wildcard routing for a specific project's
local domain, are each project's own responsibility to provision, not this playbook's; they used
to live here and collided with at least one downstream project managing the same config path).
`bootstrap.sh` is the public entry point that a fresh machine curls and runs; it installs Ansible
and hands off to `playbook.yml`.

## Commands

Validate the playbook without a target machine (this is the equivalent of "build" here — there
are no compiled artifacts or unit tests):

```bash
ansible-playbook -i localhost, -c local playbook.yml --syntax-check
ansible-playbook -i localhost, -c local playbook.yml --list-tasks
```

Note: in some sandboxed shells `ansible-playbook` fails immediately with `Ansible requires
blocking IO on stdin/stdout/stderr` because the fds are non-blocking. Work around it by clearing
`O_NONBLOCK` on fds 0/1/2 before exec'ing, e.g.:

```bash
python3 -c "
import fcntl, os, subprocess, sys
for fd in (0,1,2):
    flags = fcntl.fcntl(fd, fcntl.F_GETFL)
    fcntl.fcntl(fd, fcntl.F_SETFL, flags & ~os.O_NONBLOCK)
sys.exit(subprocess.call(['ansible-playbook','-i','localhost,','-c','local','playbook.yml','--syntax-check']))
"
```

Run the full playbook for real (only makes sense on an actual Ubuntu box you intend to
provision/mutate — it installs packages, edits `/etc`, and modifies `~/.bashrc`):

```bash
ansible-playbook -i localhost, -c local playbook.yml -K
```

`-K` prompts once for the become (sudo) password and reuses it for every task that needs root;
tasks without `become: true` run as the invoking user. There's no lint/test suite configured in
this repo beyond the syntax-check above.

## Architecture

- **`playbook.yml`** is a single play against `localhost` (`connection: local`) that only lists
  `pre_tasks` and a role order — no task logic lives here. Roles run in the listed order and later
  roles can depend on earlier ones having already run (e.g. `shell_config`'s prompt template reads
  `~/.local/share/kube-ps1.sh`, which the `kubie` role installs earlier).
- **`group_vars/all.yml`** holds every shared variable: pinned tool versions, and `target_user`/
  `target_home`, which resolve to whoever invoked Ansible (`ansible_user_id` /
  `ansible_env.HOME`) — there is no `sudo`-based user-switching, so these are just the current
  user.
- **Privilege escalation is per-task, not per-play.** Each role's tasks set `become: true`
  individually only where root is actually required (apt, `/usr/local/bin`, `/etc/*`, services).
  Tasks that write into the invoking user's home directory (dotfiles, nvm, Kubie config, Claude
  Code, git config) intentionally have no `become` at all.
- **The `pre_tasks` block in `playbook.yml` works around a sudo-rs incompatibility.** Some Ubuntu
  releases point `update-alternatives`' `/usr/bin/sudo` at `sudo-rs`, whose prompt output Ansible's
  become plugin can't parse, causing `-K` runs to hang and time out on the very first privileged
  task. If classic GNU sudo is present at `/usr/bin/sudo.ws` (as it is when both packages are
  installed side by side), a `stat` + `set_fact` repoints `ansible_become_exe` at it for the rest
  of the run; on hosts without `sudo-rs` this block is a no-op.
- **Roles are one-per-concern, not one-per-file-from-the-old-monolith.** `kubernetes_tools` bundles
  kind/kubectl/helm/kustomize plus the inotify sysctl tuning kind needs; `kubie` is split out on
  its own because it also owns Kubie's config, bash completion, and the `kube-ps1` prompt helper;
  `tekton` bundles `tkn` + `ko` since both are Tekton-adjacent CLIs; `kind_dns` just installs the
  `dnsmasq`/`dnsutils` packages now -- it used to also write a generic `*.devkit` wildcard config
  and a matching systemd-resolved routing domain, but that collided with at least one downstream
  project (tektoncd) managing the same `/etc/dnsmasq.d/devkit.conf` path itself with a more
  specific config, so per-project DNS entries were dropped from this role entirely; each project
  now owns provisioning its own local DNS routing. When adding a new tool, prefer extending an existing
  role's `tasks/main.yml` if it fits one of these groupings rather than creating a new role for a
  single task.
- **Large inline shell content lives outside `tasks/main.yml`.** The kubie bash-completion script
  is a static file at `roles/kubie/files/kubie-completion.bash`; the two `.bashrc` blocks
  (`shell_config`) are Jinja templates under `roles/shell_config/templates/` so `target_home`
  substitution still works. Follow this pattern rather than growing another long inline `content:`
  block in a tasks file.
- **`bootstrap.sh`** installs Ansible via apt, then does the one piece of privileged setup Ansible
  itself can't do without root (`sudo mkdir -p /opt/kind-cluster-setup && sudo chown` so the repo
  can live under `/opt` but be cloned/owned by the invoking user), then clones and runs
  `ansible-playbook ... -K` unprivileged. Any change to where the repo is cloned or how it's
  invoked needs to stay in sync with this script, not just `playbook.yml`.
