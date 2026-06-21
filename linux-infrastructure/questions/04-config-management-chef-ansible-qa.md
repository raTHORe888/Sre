# Q&A: Configuration Management (Chef and Ansible)

Pairs with: [04-config-management-chef-ansible.md](../04-config-management-chef-ansible.md)

> 10 interview-grade questions on Chef and Ansible.

---

## Q1. What is the difference between push and pull configuration management?
**Answer:**  
- **Push** (Ansible): a control machine connects over SSH and runs tasks on targets. No agent needed.  
- **Pull** (Chef, Puppet): an agent on each host periodically pulls the latest configuration and converges to it.  
- Push is great for quick changes, ad hoc tasks, and fleets that come and go.  
- Pull is great for long-lived hosts where continuous enforcement matters and you don't want to manage SSH access centrally.

## Q2. What does idempotency mean in configuration management?
**Answer:**  
- Running the same configuration multiple times produces the **same end state**, with **no changes** after the first successful run.  
- A non-idempotent task always reports `changed`, which hides real drift and pollutes change logs.  
- In Chef, use built-in resources (`package`, `service`, `file`, `template`) which are idempotent.  
- In Ansible, use modules instead of `shell` or `command`; if you must use a shell command, guard it with `creates`, `removes`, or `changed_when`.

## Q3. How do you test Chef cookbooks and Ansible roles before deploying to production?
**Answer:**  
- **Chef**: 
  - `cookstyle` for linting.
  - **ChefSpec** for unit tests.
  - **Test Kitchen** with Docker, Vagrant, or cloud drivers to spin up a real VM and converge.
  - **InSpec** for compliance and post-converge checks.
- **Ansible**:
  - `ansible-lint` for static analysis.
  - **Molecule** for role-level testing in Docker or VMs.
  - `ansible-playbook --check --diff` for dry runs.
- Run all of these in CI before merging.

## Q4. How do you handle secrets in Chef and Ansible?
**Answer:**  
- **Never** commit plaintext secrets to Git.  
- **Chef Vault** encrypts data bag items for specific nodes.  
- **Ansible Vault** encrypts variables files; integrates with `ansible-playbook --ask-vault-pass` or external password managers.  
- For larger fleets, integrate with external secret stores: **HashiCorp Vault**, **AWS Secrets Manager**, **AWS SSM Parameter Store**.  
- Rotate secrets regularly; ensure the rotation flow updates the secret store and triggers a redeploy.

## Q5. How does Ansible inventory work, and what are dynamic inventories?
**Answer:**  
- A **static inventory** is an INI or YAML file listing hosts and groups.  
- A **dynamic inventory** is a script or plugin that fetches hosts from a source: AWS EC2, Azure, GCP, vCenter, CMDB, Kubernetes.  
- Dynamic inventory keeps the playbook target list **in sync** with reality.  
- Use **group vars** and **host vars** to separate per-environment configuration from playbook logic.

## Q6. What is a Chef role versus an environment versus a policyfile?
**Answer:**  
- **Role**: a named set of recipes and default attributes assigned to a node (e.g., `web-server`).  
- **Environment**: a logical grouping like `dev`, `staging`, `prod` with environment-specific attribute overrides and cookbook version constraints.  
- **Policyfile**: the modern replacement for roles + environments + Berkshelf; pins exact cookbook versions for reproducible deploys.  
- Policyfiles are recommended over roles+environments for new Chef setups.

## Q7. How do you safely roll out a risky configuration change across thousands of hosts?
**Answer:**  
- Make the change in a branch and open a PR.  
- Run CI: linting, unit tests, kitchen/molecule.  
- Deploy to a **single canary host** first.  
- Validate metrics and logs for a defined bake time.  
- Roll out in **waves**: 1% → 10% → 50% → 100%.  
- Watch SLO burn during the rollout.  
- Have a **rollback plan**: revert the PR and re-converge, or apply a remediation playbook.

## Q8. How do you detect that a host has drifted from its desired configuration?
**Answer:**  
- Chef reports each run; aggregate reports in Chef Automate or a custom dashboard.  
- Ansible reports task results; aggregate runs through AWX, Tower, or pipeline logs.  
- Schedule periodic `--check` runs to detect drift without applying.  
- Use **file integrity** monitoring (`aide`, `tripwire`) for security-critical files.  
- Alert on hosts that have not converged in the last N hours; they may be offline or broken.

## Q9. How do you avoid the "Ansible spaghetti" anti-pattern in a growing playbook?
**Answer:**  
- Break logic into **roles** with clear, single responsibilities.  
- Use `defaults/main.yml` for safe defaults and `vars/main.yml` for role-internal constants.  
- Keep playbooks short; they should mostly call roles.  
- Use **tags** sparingly; prefer separate playbooks over giant tag matrices.  
- Lint and test roles independently.  
- Version roles in Git or Ansible Galaxy and pin versions.

## Q10. When would you choose Chef over Ansible (or vice versa)?
**Answer:**  
- **Choose Ansible when**:
  - You want agentless deploys and quick adoption.
  - You manage a mix of OS, network, and SaaS systems.
  - Your team is more comfortable with YAML than Ruby.
  - You need fast ad hoc operations.
- **Choose Chef when**:
  - You have long-lived hosts that need continuous convergence.
  - You want a richer programmatic DSL (Ruby) for complex logic.
  - You need policy-based pinning of dependencies (Policyfiles).
- Many organizations use both: Chef for long-lived baselines, Ansible for ad hoc operations and orchestration.
