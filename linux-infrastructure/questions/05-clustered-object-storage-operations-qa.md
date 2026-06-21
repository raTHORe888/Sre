# Q&A: Clustered Object Storage Operations

Pairs with: [05-clustered-object-storage-operations.md](../05-clustered-object-storage-operations.md)

> 10 interview-grade questions on operating clustered object storage at scale.

---

## Q1. What is object storage, and how is it different from block and file storage?
**Answer:**  
- **Block storage**: raw blocks (e.g., EBS, iSCSI LUNs). Filesystems sit on top. Low latency, no metadata.  
- **File storage**: directory tree with files (e.g., NFS, SMB). Good for shared workspaces.  
- **Object storage**: flat namespace of objects with rich metadata, accessed via HTTP APIs (typically S3-compatible).  
  - Massively scalable.
  - Designed for high durability via replication or erasure coding.
  - Ideal for backups, archives, media, ML datasets, logs.

## Q2. What is the difference between replication and erasure coding in object storage?
**Answer:**  
- **Replication** stores N full copies (e.g., 3 copies). Simple, fast reads/writes, higher storage overhead.  
- **Erasure coding** (e.g., 4+2 or 8+3) splits data into K data shards + M parity shards. Storage efficiency is higher, but reads/writes do more CPU work and small-object performance is worse.  
- **Replication** is typical for hot data and small clusters; **erasure coding** is typical for cold/large data and dense clusters.  
- Many systems support per-bucket policies, so you can mix both.

## Q3. How does Ceph map objects to OSDs?
**Answer:**  
- A client uses **CRUSH** (Controlled Replication Under Scalable Hashing) to deterministically compute placement.  
- Steps:
  1. Object is hashed to a **placement group (PG)**.
  2. CRUSH maps the PG to a set of **OSDs**, respecting the CRUSH map (failure domains, weights).
- No central lookup is needed; the client computes placement.  
- CRUSH lets you express rules like "spread three replicas across three racks."

## Q4. What is a placement group (PG) in Ceph, and why does it matter?
**Answer:**  
- A **PG** is a logical grouping of objects mapped together to a set of OSDs.  
- The number of PGs affects:
  - Distribution of data across OSDs.
  - Recovery and scrub workload.
  - Memory and CPU per OSD.
- Too few PGs → uneven distribution. Too many PGs → high overhead.  
- Ceph provides guidance via `pg_autoscaler` and the documentation. Always plan PG counts based on cluster size and OSD count.

## Q5. How do you protect against silent data corruption in object storage?
**Answer:**  
- Use **end-to-end checksums** (most object stores compute and verify these on read and write).  
- Run **periodic scrubs**:
  - Ceph: light scrub (metadata) and deep scrub (data).
  - MinIO: bit rot healing scans.
  - ZFS-backed: scheduled `zpool scrub`.
- Replicate or erasure-code across failure domains so a corrupted shard can be repaired.  
- Monitor scrub progress and errors; alert on any inconsistency.

## Q6. How do lifecycle policies help control object storage cost?
**Answer:**  
- Lifecycle rules automatically transition objects between **storage tiers** based on age or tags:
  - Hot → Warm → Cold → Glacier-like.
- Automatically **expire** objects after a defined period.  
- Apply to specific prefixes or buckets.  
- Reduces cost without operator effort and prevents unbounded growth.  
- Combine with **bucket quotas** and **request rate monitoring** to keep tenants in line.

## Q7. What is read-after-write consistency, and why does it matter for object storage?
**Answer:**  
- Means a successful `PUT` is immediately visible on a subsequent `GET`.  
- Modern object stores (S3, Ceph, MinIO) generally provide **strong read-after-write** for new objects.  
- Applications still need to handle eventual consistency for **overwrites** and **listings** in some systems.  
- Always check the **consistency model** of your specific store; design clients to be retry-safe.

## Q8. How do you handle a failed disk in a Ceph cluster?
**Answer:**  
1. The OSD on the failed disk goes `down` and eventually `out`.  
2. Ceph rebalances data automatically to maintain replica/EC requirements.  
3. Operator replaces the physical disk (after `ceph orch osd rm` or equivalent for that distribution).  
4. Re-add the disk as a new OSD; data rebalances back.  
5. Monitor:
   - `ceph -s` for cluster status.
   - PG states (active+clean is the goal).
   - Backfill/recovery progress.
6. Avoid bulk-replacing many disks at once; throttle recovery to protect client I/O.

## Q9. What metrics matter most when running object storage?
**Answer:**  
- **Durability indicators**: scrub errors, replica/EC health, OSD up/in counts.  
- **Latency**: p50, p95, p99 for `GET` and `PUT`.  
- **Throughput**: bytes/sec and operations/sec.  
- **Capacity**: per-pool/bucket usage and growth rate.  
- **Cluster health**: degraded, misplaced, recovering objects.  
- **Client experience**: HTTP error rates (4xx/5xx) and request latency from a synthetic monitor.  
- **Per-bucket / per-tenant** stats to spot noisy neighbors.

## Q10. How do you plan and execute a rolling upgrade of an object storage cluster?
**Answer:**  
1. Read the release notes; check version compatibility (mons, OSDs, RGWs, clients).  
2. Test the upgrade in a **staging cluster** with similar topology and data shape.  
3. Take snapshots/backups of critical components (mon database, configs).  
4. Upgrade **monitors / metadata services** first, then **OSDs/storage daemons**, then **gateways/RGWs**.  
5. Upgrade one host or fault domain at a time, validating health between steps.  
6. Pause if the cluster is recovering or scrubbing heavily.  
7. Once complete, run smoke tests and validate dashboards.  
8. Document the upgrade and any deviations from the plan.
