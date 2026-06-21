# Q&A: Linux Systems Administration at Scale

Pairs with: [01-linux-systems-administration-at-scale.md](../01-linux-systems-administration-at-scale.md)

> 10 interview-grade questions on running thousands of Linux hosts.

---

## Q1. How do you bootstrap thousands of bare metal Linux hosts from scratch?
**Answer:**  
- Use **PXE boot** with a DHCP/TFTP server to load a small installer image.  
- The installer pulls a **kickstart**, **preseed**, or **cloud-init** file describing partitioning, base packages, users, and network.  
- After OS install, the host registers with **configuration management** (Chef, Ansible, Puppet) and converges to its role.  
- Tooling examples: **Foreman**, **MAAS**, **Cobbler**, or vendor BMC tooling.  
- Final step: the host registers with the inventory/CMDB and joins the monitoring fleet.

## Q2. What is the difference between immutable infrastructure and configuration management?
**Answer:**  
- **Immutable infrastructure**: hosts are never modified after deploy; you replace them by deploying a new image.  
- **Configuration management**: hosts are mutable, and a tool (Chef, Ansible) continuously enforces desired state.  
- Trade-offs:
  - Immutable is cleaner for cloud and stateless workloads.
  - Config management is often more practical for long-lived bare metal where reimaging is expensive.
- Many fleets use a hybrid: golden images plus config management for last-mile state.

## Q3. How do you handle SSH access for thousands of hosts safely?
**Answer:**  
- Avoid sharing static SSH keys.  
- Use a **central identity provider** (LDAP/AD/SSO) with SSSD for user accounts.  
- Use **short-lived SSH certificates** signed by a central CA (HashiCorp Vault, OpenSSH CA, Teleport).  
- Restrict access by **role and host group**; enforce sudo rules in code.  
- Log every session (auditd, OpenSSH audit, Teleport recording).  
- Rotate keys and certificates regularly; revoke instantly on departure.

## Q4. How do you keep the OS patched across a large fleet without causing outages?
**Answer:**  
- Maintain an **internal mirror** of OS repositories for reproducibility.  
- Pin package versions for production.  
- Roll out in **waves**: dev → canary → small percent → fleet, with health checks between waves.  
- Drain workloads from each host before patching when needed.  
- Reboot in waves for kernel updates; use **kpatch / kexec / live patching** where appropriate to minimize reboots.  
- Track patch compliance per host in a dashboard.

## Q5. What is configuration drift, and how do you detect it?
**Answer:**  
- Drift is when the actual state of a host diverges from the desired state in code.  
- Causes: emergency manual fixes, ad hoc scripts, package auto-updates.  
- Detection:
  - `chef-client --why-run` or Chef compliance reports.
  - `ansible --check --diff` or AWX reports.
  - File integrity tools (`aide`, `tripwire`) for security-critical files.
- Remediation: re-run config management, or rebuild the host if drift is significant.

## Q6. How do you manage thousands of hosts in inventory?
**Answer:**  
- Maintain a **CMDB** as the source of truth: hostname, role, environment, rack/AZ, owner, lifecycle state, hardware details.  
- Integrate the CMDB with:
  - Monitoring (alerts know who owns what).
  - Config management (dynamic inventory).
  - Capacity planning.
  - Security scanning.
- Examples: NetBox, ServiceNow CMDB, internal databases.  
- Update lifecycle states (`provisioning`, `in-service`, `draining`, `decommissioned`) automatically from pipelines.

## Q7. How do you treat hosts as "cattle, not pets"?
**Answer:**  
- Every host can be replaced by running the pipeline against a fresh machine.  
- No special handcrafted state lives only on one host.  
- Workloads are designed to tolerate the loss of any single host.  
- Manual fixes are written back into config management, not left on the host.  
- The fleet survives the loss of N% of hosts without paging humans.

## Q8. What is the role of golden images in fleet management?
**Answer:**  
- A **golden image** is a pre-baked OS image with base packages, security hardening, agents, and tools already installed.  
- Benefits:
  - Faster provisioning (less to install at boot).
  - Reduced variability across hosts.
  - Easier security and compliance baselines.
- Build pipelines (Packer, vendor tools) produce a new image version on each change.  
- Pair golden images with config management for last-mile state.

## Q9. How do you safely decommission a host?
**Answer:**  
1. Mark the host as **draining** in the inventory.  
2. Migrate workloads off; cordon and drain Kubernetes nodes or rebalance storage.  
3. Disable monitoring and alerting for the host.  
4. Securely wipe data: `nvme format`, `blkdiscard`, ATA secure erase, or physical destruction per policy.  
5. Remove from configuration management, DNS, load balancers.  
6. Update CMDB to `decommissioned` with disposal record.  
7. Confirm asset disposal matches policy.

## Q10. What signals tell you that your fleet management is mature?
**Answer:**  
- Time-to-provision a new host is measured in minutes, not days.  
- Drift is detected automatically and remediated.  
- Patch compliance is reported and consistently high.  
- No engineer needs to SSH into a host to fix problems in normal operations.  
- Host loss is handled by the system, not by paging humans.  
- Inventory is current and trustworthy for capacity, security, and incident response.
