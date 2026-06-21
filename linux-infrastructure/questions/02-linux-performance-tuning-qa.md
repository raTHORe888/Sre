# Q&A: Linux Performance Tuning

Pairs with: [02-linux-performance-tuning.md](../02-linux-performance-tuning.md)

> 10 interview-grade questions on Linux kernel, filesystem, and storage tuning.

---

## Q1. How do you baseline a Linux host's performance before tuning anything?
**Answer:**  
- Capture metrics for CPU, memory, disk, and network under representative load.  
- Tools:
  - `sar` from sysstat for historical data.
  - `vmstat 1`, `mpstat -P ALL 1`, `pidstat 1` for live CPU and memory.
  - `iostat -xz 1` for storage.
  - `ss -ti`, `nstat`, `ethtool -S` for network.
  - `perf stat`, `perf top` for CPU-level profiling.
- Record the workload conditions: traffic, request mix, time of day.  
- Without a baseline, you cannot tell if tuning helped or hurt.

## Q2. What is the difference between mq-deadline, BFQ, and none I/O schedulers?
**Answer:**  
- **mq-deadline**: simple deadline-based scheduler with multi-queue; good general default.  
- **BFQ**: fairness-oriented, can be better for desktop/interactive workloads but adds overhead.  
- **none**: no scheduling, lets the device do it; typical for **NVMe** drives that have their own queues.  
- For object storage on NVMe, `none` is often the right choice. For SATA/SAS HDDs, `mq-deadline` is usually fine.  
- Always **benchmark with your real workload** before changing schedulers fleet-wide.

## Q3. How do `vm.swappiness`, `vm.dirty_ratio`, and `vm.dirty_background_ratio` affect performance?
**Answer:**  
- `vm.swappiness` controls how aggressively the kernel swaps anonymous memory. Lower values (e.g., 10) reduce swap for memory-rich servers.  
- `vm.dirty_background_ratio` is the percent of memory of dirty pages at which background flush starts.  
- `vm.dirty_ratio` is the percent at which writers are throttled and forced to flush synchronously.  
- For write-heavy storage hosts, lowering both ratios spreads I/O more evenly and avoids large stalls.  
- Always validate with `iostat` and tail-latency metrics after tuning.

## Q4. When would you choose XFS, ext4, or ZFS for an object storage workload?
**Answer:**  
- **XFS**: excellent for large files, parallel I/O, and large block devices. Common choice for **Ceph OSDs** and large data volumes.  
- **ext4**: solid general-purpose default; mature and predictable.  
- **ZFS**: end-to-end checksums, snapshots, compression. Costs more memory, but adds data integrity and storage efficiency.  
- For object storage at scale, **XFS** is typical for the data path; ZFS may be used in specific deployments where its features outweigh the resource cost.

## Q5. What is NUMA, and how can it hurt performance?
**Answer:**  
- **NUMA** (Non-Uniform Memory Access) means each CPU has faster access to its local memory than to remote memory on another socket.  
- A process running on socket 0 accessing memory on socket 1 incurs extra latency.  
- Symptoms: high `%sys` time, low scaling with more cores, unexplained latency.  
- Tools: `numastat -p <pid>`, `numactl --hardware`, `lscpu`.  
- Mitigation: pin processes and memory together with `numactl`, set workload-aware NUMA policies (e.g., `interleave` for some DB workloads), or use cgroup cpusets.

## Q6. How does Transparent Huge Pages (THP) affect performance?
**Answer:**  
- THP groups 4 KB pages into 2 MB pages to reduce TLB pressure.  
- It can help for memory-heavy analytical workloads.  
- It can hurt latency-sensitive workloads (databases, low-latency storage) because of allocation stalls.  
- Many databases (MongoDB, Redis, Cassandra) explicitly recommend disabling or setting to `madvise`.  
- Always test the specific workload before changing.

## Q7. How do you tune the Linux TCP stack for high-bandwidth, long-latency links?
**Answer:**  
- Increase socket buffer limits: `net.core.rmem_max`, `net.core.wmem_max`.  
- Tune TCP autotuning ranges: `net.ipv4.tcp_rmem`, `net.ipv4.tcp_wmem`.  
- Choose modern congestion control: `net.ipv4.tcp_congestion_control = bbr`.  
- Enable selective ACK and timestamps.  
- For 10G+ NICs, ensure adequate ring buffers (`ethtool -G`) and consider jumbo frames if the network supports them end-to-end.  
- Validate with `iperf3` between hosts before and after.

## Q8. How would you find which process is causing high I/O?
**Answer:**  
- `iostat -xz 1` to see which **devices** are busy.  
- `iotop` to see which **processes** are doing I/O.  
- `pidstat -d 1` for per-process I/O statistics.  
- For deeper analysis: `biolatency.bt` (bpftrace) or `biosnoop` from BCC tools.  
- For NFS or distributed FS clients: `nfsiostat`, application-level traces.

## Q9. What does high `await` and low `%util` in iostat indicate?
**Answer:**  
- `%util` is the percent of time the device had at least one outstanding request.  
- `await` is the average time a request waited (including queue and service).  
- High `await` with low `%util` usually means **queueing in software** rather than the device being saturated: small queue depth, contention, or scheduler issues.  
- Check `aqu-sz`, queue depth settings, scheduler choice, and whether the device is being starved by other processes.

## Q10. How do you make tuning changes safe and reproducible across a fleet?
**Answer:**  
- Apply changes via **configuration management**, never on individual hosts.  
- Document the **reason** and the **workload** next to every non-default value.  
- Roll out in waves with health checks.  
- Keep a **benchmark suite** that can verify the gain on a canary host.  
- Re-validate after every major kernel upgrade; defaults change.  
- Maintain a version-controlled **`sysctl.d`** and `tuned` profile so changes are reviewable.
