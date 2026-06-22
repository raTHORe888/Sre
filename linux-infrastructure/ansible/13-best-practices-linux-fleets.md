# 13. Best Practices for Linux Fleet Automation

> A consolidated checklist for running Ansible on real Linux fleets in production.

## Project structure

A predictable layout reduces cognitive load:

```
ansible-platform/
├── ansible.cfg
├── requirements.yml           # collections and external roles
├── inventory/
│   ├── prod.yml
│   ├── staging.yml
│   ├── group_vars/
│   │   ├── all.yml
│   │   ├── web.yml
│   │   ├── prod/
│   │   │   ├── vars.yml
│   │   │   └── vault.yml
│   │   └── staging/
│   └── host_vars/
├── playbooks/
│   ├── site.yml
│   ├── web.yml
│   ├── db.yml
│   └── maintenance/
│       ├── patch.yml
│       └── reboot.yml
├── roles/
│   ├── common/
│   ├── nginx/
│   └── postgres/
├── collections/               # installed via requirements.yml in CI
└── molecule/                  # scenario tests
```

## Naming and conventions

- Always use **fully-qualified module names** (`ansible.builtin.copy`, not `copy`).
- Always name tasks. Output and debugging depend on it.
- Use **snake_case** for variables and roles.
- Group variables by **purpose**: `nginx_*`, `postgres_*`, `aws_*`.
- Prefix vault variables with `vault_`.
- Use **lowercase** group names; environments first, then function: `prod_web`, `staging_db`.

## Idempotency

- Every task should be safe to run twice.
- Avoid `shell` and `command` when a real module exists.
- For shell tasks, set `creates:`, `removes:`, `changed_when:`, and `failed_when:` so the change/fail semantics are honest.
- Verify with **two consecutive runs**: the second should report `changed=0`.
- Use Molecule's idempotence step in CI.

## Variables and data

- **Defaults** in roles, environment data in `group_vars`, exceptions in `host_vars`.
- **No magic numbers** in tasks; pull them from vars.
- **No secrets** in plain Git; use Vault or an external store.
- Keep a clear split between `vars.yml` (plain) and `vault.yml` (encrypted) per environment.

## Roles and reuse

- A role should do **one job well**: install + configure + run a single service or subsystem.
- Roles you reuse across teams belong in a **collection** with semantic versioning.
- Pin third-party roles and collections to specific versions.
- Document required variables in `roles/<role>/README.md`.

## Safe rollouts

- Use `serial:` for any change that touches running services.
- Combine with `max_fail_percentage:` to stop the run if too many hosts fail.
- Wrap risky operations in `block` / `rescue` / `always`.
- Notify a chat channel automatically on failure.
- Maintain a `--check --diff` step in CI.

## Secrets

- Encrypt with `ansible-vault`, separate vault files per environment.
- Provide passphrases via a password script that reads from a CI secret store.
- Pull dynamic, rotating secrets at runtime from HashiCorp Vault, AWS Secrets Manager, or similar.
- Always set `no_log: true` on tasks that touch secrets.

## Testing

- Run `yamllint` and `ansible-lint` on every PR.
- Add a Molecule scenario to every role.
- Include both **converge** and **idempotence** checks.
- Add a verify step that hits the actual service (port open, HTTP 200, etc.).
- For full playbooks, run `--check --diff` against a staging inventory.

## CI/CD

- Every change to playbooks, roles, or inventory is a PR.
- CI runs lint, syntax check, Molecule, and a staging dry-run.
- Production applies are triggered through **AWX/AAP** or a controlled pipeline, never from a laptop.
- Each run records: who triggered it, which commit, which inventory, full job log.

## Operating at scale

- Tune `forks`, pipelining, and ControlPersist as in [12-performance-tuning-at-scale.md](12-performance-tuning-at-scale.md).
- Use list-form module calls instead of per-item loops.
- Cache facts or skip fact gathering where you don't need them.
- Place controllers near the hosts (network-wise) to reduce SSH latency.
- For thousands of hosts, distribute work across multiple execution nodes.

## Drift control

- Schedule periodic playbook runs that re-converge configuration.
- Run `--check` mode regularly to surface drift without changing state.
- Alert on hosts that haven't been touched by Ansible in N hours.
- Treat manual changes as bugs; back-port to roles immediately.

## Observability

- Use a structured callback in CI (`json`, `junit`).
- Mirror logs to disk (`log_path` in `ansible.cfg`).
- Emit per-run metrics (duration, changed count, failures) to your monitoring system.
- Send Slack/email notifications on failures and on prod runs.

## Security

- Use SSH keys or certs, never passwords.
- Use a least-privilege sudoers configuration.
- Restrict who can run prod playbooks via RBAC in AWX/AAP.
- Audit `ansible.log` and AWX job logs.
- Rotate Vault passphrases periodically.

## Documentation

- Every project has a README explaining how to run it.
- Every role has a README explaining inputs and outputs.
- Maintain a runbook index that maps "I want to do X" → "use playbook/job template Y".
- Postmortems for any prod-impacting Ansible incident go into the docs.

## Common patterns for Linux fleets

| Need | Pattern |
|---|---|
| Patch the OS fleet | Playbook with `serial:`, drain → patch → reboot → validate per batch |
| Rotate SSH keys | Playbook that updates `authorized_keys` from a known source-of-truth |
| Deploy a new app version | Workflow: build → push artifact → roll out with health checks |
| Onboard a new host | Trigger a Job Template from cloud-init: install agents, register monitoring, run base role |
| Compliance scan | Scheduled `--check` run with structured output, fed to a dashboard |
| Emergency mitigation | Pre-built playbook with explicit scope and approval prompt |

### Example: patch the OS fleet safely

```yaml
# playbooks/maintenance/patch.yml
- name: Patch web fleet in waves
  hosts: web
  become: true
  serial:
    - 1
    - "10%"
    - "50%"
    - "100%"
  max_fail_percentage: 5
  tasks:
    - name: Drain host from load balancer
      ansible.builtin.uri:
        url: "http://lb/api/drain/{{ inventory_hostname }}"
        method: POST
      delegate_to: localhost

    - name: Upgrade all packages
      ansible.builtin.package:
        name: "*"
        state: latest
        update_cache: true

    - name: Reboot if needed
      ansible.builtin.reboot:
        msg: "Reboot after patching"
        reboot_timeout: 600

    - name: Wait for app port
      ansible.builtin.wait_for:
        host: "{{ inventory_hostname }}"
        port: 8080
        timeout: 300
      delegate_to: localhost

    - name: Re-add host to load balancer
      ansible.builtin.uri:
        url: "http://lb/api/enable/{{ inventory_hostname }}"
        method: POST
      delegate_to: localhost
```

### Example: rotate authorized_keys from a source of truth

```yaml
# playbooks/maintenance/rotate-keys.yml
- name: Sync deploy user keys
  hosts: all
  become: true
  tasks:
    - name: Ensure deploy user exists
      ansible.builtin.user:
        name: deploy
        shell: /bin/bash
        state: present

    - name: Push authorized keys
      ansible.posix.authorized_key:
        user: deploy
        key: "{{ lookup('file', 'files/deploy_authorized_keys') }}"
        exclusive: true
        state: present
```

### Example: emergency mitigation playbook with approval

```yaml
# playbooks/emergency/disable-feature.yml
- name: Disable risky feature globally
  hosts: web
  become: true
  vars_prompt:
    - name: confirm
      prompt: "Type DISABLE to confirm disabling the feature in prod"
      private: false
  pre_tasks:
    - name: Hard stop if not confirmed
      ansible.builtin.fail:
        msg: "Aborting: confirmation not provided"
      when: confirm != "DISABLE"

  tasks:
    - name: Flip feature flag
      ansible.builtin.lineinfile:
        path: /etc/myapp/feature_flags.conf
        regexp: "^risky_feature="
        line: "risky_feature=false"
      notify: reload app

  handlers:
    - name: reload app
      ansible.builtin.service:
        name: myapp
        state: reloaded
```

### Example: scheduled compliance scan

```yaml
# playbooks/compliance/sshd-baseline.yml
- name: SSHD baseline compliance check
  hosts: all
  become: true
  gather_facts: false
  tasks:
    - name: Read sshd_config
      ansible.builtin.slurp:
        src: /etc/ssh/sshd_config
      register: sshd_raw

    - name: Decode content
      ansible.builtin.set_fact:
        sshd_content: "{{ sshd_raw.content | b64decode }}"

    - name: Check PermitRootLogin
      ansible.builtin.assert:
        that:
          - "'PermitRootLogin no' in sshd_content"
        fail_msg: "PermitRootLogin must be 'no'"
        success_msg: "PermitRootLogin compliant"
```

Schedule it from AWX with `--check` semantics to detect drift without changing anything.

## What good looks like

- Engineers describe production changes by linking to a PR, not by listing manual steps.
- Reviewers can read a `group_vars/prod.yml` and a playbook and understand the change.
- Idempotency is enforced by CI.
- Prod is touched only via AWX/AAP with audit logs.
- Drift is detected and corrected automatically.
- New hosts join the fleet in minutes by running the same pipeline.

## Anti-patterns to retire

- "Just SSH and fix it; we'll update the playbook later."
- Vault passphrases in chat history.
- Shared sudo passwords typed into the AWX UI by hand.
- `ignore_errors: true` everywhere to "make CI green".
- Untested roles published to a shared collection.

## Recap of the learning path

```mermaid
flowchart LR
    A[01 Fundamentals] --> B[02 Setup + Inventory]
    B --> C[03 Ad-hoc + Modules]
    C --> D[04 Playbooks]
    D --> E[05 Vars + Facts + Templates]
    E --> F[06 Control Flow]
    F --> G[07 Roles + Collections]
    G --> H[08 Vault + Secrets]
    H --> I[09 Error Handling + Debug]
    I --> J[10 Testing with Molecule]
    J --> K[11 AWX / Automation Platform]
    K --> L[12 Performance at Scale]
    L --> M[13 Best Practices]
```

You now have a complete Ansible learning path tailored to Linux fleet engineering. Next steps:

- Pick a real workload and convert it to roles in your lab.
- Add Molecule tests and wire CI.
- Stand up AWX in a small VM and import a project.
- Time your runs and apply the performance levers.
- Keep iterating: every fix to a production host should become a PR.
