# Q&A: Git Workflows and Collaboration

Pairs with: [10-git-workflows-collaboration.md](../10-git-workflows-collaboration.md)

---

## Q1. Why are Git workflows important for SRE?
**Answer:**  
- All changes are reviewed and auditable.  
- Rollback is just a revert.  
- IaC, app code, and runbooks all benefit from version control.  
- Pipelines and reviews build a culture of safety.

## Q2. What is trunk-based development, and why do high-performing teams prefer it?
**Answer:**  
- A workflow where every developer integrates **small, frequent changes** into a single main branch.  
- Branches are short-lived (hours to a day), reducing merge conflicts and drift.  
- Incomplete features hide behind **feature flags** instead of long-lived feature branches.  
- Why high-performing teams (per DORA research) prefer it:
  - Faster lead time for changes.
  - Lower change failure rate.
  - Easier rollback (small diffs).
  - Cleaner CI signal (main is always releasable).
- Works best when paired with strong CI, fast tests, and feature flags.

## Q3. What is GitFlow?
**Answer:**  
A branching model with develop, feature, release, and hotfix branches. It can be heavier than trunk-based development and is less common for high-velocity SRE workflows.

## Q4. What is a good pull request culture?
**Answer:**  
- PRs are small and focused.  
- Description explains the change and its risk.  
- CI runs on every PR.  
- At least one reviewer approves.  
- Merges trigger consistent pipelines.

## Q5. How do you handle hotfixes safely?
**Answer:**  
- Branch from the production tag or main.  
- Apply the minimum needed change.  
- Run the full pipeline.  
- Backport to main if needed.  
- Document the event.

## Q6. How do you secure your Git workflows?
**Answer:**  
- Require reviews on protected branches.  
- Require signed commits where possible.  
- Restrict who can approve and merge.  
- Use repository scanning for secrets.

## Q7. How do GitOps and SRE relate?
**Answer:**  
- GitOps treats Git as the source of truth for infrastructure and applications.  
- A controller reconciles the cluster to Git state.  
- This aligns with SRE goals of auditability and repeatability.

## Q8. What is a common collaboration anti-pattern?
**Answer:**  
- Long-lived branches that drift far from main.  
- Force pushes to shared branches.  
- Bypassing reviews for "urgent" changes.  
- Mixing many unrelated changes in one PR.

## Q9. How do PRs relate to incident response?
**Answer:**  
- PRs provide a clear history of changes that may have caused incidents.  
- Correlating deploys with incidents speeds up triage.  
- Postmortem actions often end up as PRs.

## Q10. What is the relationship between Git, IaC, and runbooks?
**Answer:**  
- Git stores all of them.  
- IaC changes go through the same review and CI process.  
- Runbooks evolve with the system they describe.  
- The pipeline ties code, infra, and operations together.
