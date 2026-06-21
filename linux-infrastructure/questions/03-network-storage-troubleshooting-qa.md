# Q&A: Network and Storage Troubleshooting

Pairs with: [03-network-storage-troubleshooting.md](../03-network-storage-troubleshooting.md)

> 10 interview-grade questions on troubleshooting with classic Unix tools.

---

## Q1. Walk me through how you would troubleshoot "the storage is slow."
**Answer:**  
1. **Confirm the symptom**: which clients, which buckets, which time window, what does "slow" mean (latency, throughput, errors)?  
2. **Check dashboards** for the storage cluster: tail latency, queue depth, error rates.  
3. **Check the network path**: load balancer, switches, NIC counters between client and storage.  
4. **Check storage nodes**: `iostat`, `dmesg` for disk errors, OSD/server health.  
5. **Check the client side**: client load, retries, DNS, TLS.  
6. **Form one hypothesis at a time** and test it.  
7. **Capture evidence** before mitigation, then mitigate.

## Q2. How do you use `tcpdump` effectively without overwhelming the host?
**Answer:**  
- Use specific filters: `tcpdump -i eth0 host 10.1.2.3 and port 443 -w out.pcap`.  
- Limit packet size if only headers are needed: `-s 96`.  
- Use ring buffer captures for long sessions: `-W 5 -C 100`.  
- Avoid running on a hot host without a filter; it can drop packets and add CPU.  
- Analyze offline with **Wireshark** or **tshark**; do not eyeball pcaps in production.

## Q3. What is `iperf3` for, and what are common pitfalls?
**Answer:**  
- `iperf3` measures TCP or UDP bandwidth between two hosts.  
- Pitfalls:
  - Single TCP stream can't reach line rate on 10G+; use `-P` for parallel streams.
  - CPU on either side can bottleneck before the network does.
  - Default window size may be too small for long-latency paths; tune `-w`.
  - Background traffic (monitoring, replication) can skew results.
- For real validation, run **both directions** and over **longer windows** (30-60 seconds).

## Q4. You see TCP retransmits climbing. How do you find the cause?
**Answer:**  
- Check `ss -ti` or `nstat` for `TCPRetrans`, `TCPLostRetransmit`, `TCPSlowStartRetrans`.  
- Compare with NIC counters (`ethtool -S`): drops, CRC errors, pause frames.  
- Check switch counters from the network team.  
- Look for MTU mismatches: a `ping -M do -s 1472` test reveals path MTU.  
- Use `tcpdump` on both ends to see whether packets are leaving and arriving.  
- Cloud-only: check **VPC flow logs** or **security group** denies as a cause.

## Q5. How do you investigate a "disk is full" alert?
**Answer:**  
- `df -h` to see block usage; `df -i` to see inode usage.  
- `du -xh --max-depth=1 /` (or specific mount) to find big directories.  
- Look for deleted-but-open files: `lsof | grep deleted`.  
- Check log rotation: misconfigured `logrotate` causes many "full disk" cases.  
- For filesystems with thin provisioning or snapshots (ZFS, LVM), check pool/volume usage, not just `df`.

## Q6. SMART says a disk is healthy, but I/O is slow. What do you check?
**Answer:**  
- SMART can miss firmware-level slow-down (e.g., URE retries below the threshold).  
- Check `dmesg` for `medium error` or `task abort` messages.  
- Check controller and HBA logs (vendor tools).  
- Run a **fio** test against the raw device to compare to peer disks.  
- Compare `await` and `svctm` to other identical drives.  
- If the drive is an outlier, replace it; latency outliers are common pre-failure signs.

## Q7. How do you debug a slow NFS mount?
**Answer:**  
- Check `nfsstat -c` on the client and `nfsstat -s` on the server for ops mix and errors.  
- `nfsiostat` shows per-mount latency and queueing.  
- Verify mount options: `vers`, `rsize`/`wsize`, `hard`/`soft`, `nconnect`.  
- Check network path with `ping`, `tracepath`, and `mtr`.  
- Check server load: CPU, memory, disk I/O, NFS thread count (`/proc/fs/nfsd/threads`).  
- Server-side, look at the underlying filesystem.

## Q8. What is `bpftrace`, and when would you use it?
**Answer:**  
- A high-level tracing language built on **eBPF** for live kernel and user-space observation.  
- Useful when standard tools don't show enough detail.  
- Examples:
  - `biolatency.bt`: histogram of block I/O latency.
  - `tcplife.bt`: lifecycle of TCP connections.
  - `runqlat.bt`: scheduler run queue latency.
- Lower overhead than older tools like `strace`.  
- Requires recent kernels (4.9+ for most, 5.x+ for newer features).

## Q9. How do you capture diagnostic data during an incident without making things worse?
**Answer:**  
- Use a **pre-built script** that runs in seconds: `iostat`, `vmstat`, `ss`, `dmesg`, `ps`, `top` snapshots, `ethtool` counters, and a short pcap.  
- Bound the work: short captures, low-overhead tools.  
- Save output to a non-customer-impacting location.  
- Avoid running large scans (`du -sh /`) on hot hosts.  
- Tag output with hostname and timestamp for postmortem use.

## Q10. After an incident, how do you turn troubleshooting steps into operational improvements?
**Answer:**  
- Add the steps to the **runbook** for the alert that fired.  
- Link the runbook from the alert.  
- If a step was manual, automate it (Ansible playbook, Lambda, SSM Document, custom script).  
- Add a **dashboard panel** for the signal you wished you had.  
- Add a **metric or alarm** so the next occurrence is detected earlier.  
- Review action items in the postmortem and track them to completion.
