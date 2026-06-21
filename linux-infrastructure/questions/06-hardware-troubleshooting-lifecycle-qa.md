# Q&A: Hardware Troubleshooting and Lifecycle

Pairs with: [06-hardware-troubleshooting-lifecycle.md](../06-hardware-troubleshooting-lifecycle.md)

> 10 interview-grade questions on bare metal hardware operations.

---

## Q1. What is a BMC, and why does it matter for fleet management?
**Answer:**  
- The **Baseboard Management Controller** is an independent processor on the server motherboard with its own network port and OS.  
- Vendor names: **iDRAC** (Dell), **iLO** (HPE), **IMM/XCC** (Lenovo).  
- Functions:
  - Remote power on/off and reset.
  - Console redirection (KVM over IP).
  - Hardware sensor data (temperature, fans, PSU).
  - Firmware updates.
  - Standardized API access via **Redfish**.
- Critical for managing hosts that are unreachable from the OS network.

## Q2. What SMART attributes are most important for predicting disk failure?
**Answer:**  
- **Reallocated Sectors Count**: any non-zero growth is a warning sign.  
- **Current Pending Sector Count**: sectors that may be remapped soon.  
- **Offline Uncorrectable**: serious sign of impending failure.  
- **Read Error Rate** and **Seek Error Rate** trends.  
- For **SSDs**: **Wear Leveling Count**, **Media Wearout Indicator**, **Available Spare**.  
- For **NVMe**: `nvme smart-log` shows similar fields plus media errors.  
- Track trends, not just current values; a sudden jump matters more than absolute count.

## Q3. How would you triage a server that won't POST?
**Answer:**  
- Connect via **BMC** and check power, system event log (SEL), and POST screens.  
- Look at LEDs and beep codes for vendor-specific guidance.  
- Reseat memory and check DIMM slots; remove one DIMM at a time to isolate.  
- Reseat CPUs and cables.  
- Check PSU status and try a known-good PSU.  
- Update or reset firmware (BIOS/UEFI) if recent change correlates.  
- Open RMA with the vendor if hardware fault is confirmed.

## Q4. What is ECC memory, and how do you know if a DIMM is failing?
**Answer:**  
- **ECC** memory detects and corrects single-bit errors and detects multi-bit errors.  
- Failing DIMMs show **correctable errors** in `mcelog`, `rasdaemon`, or BMC SEL.  
- A rising rate of correctable errors usually precedes uncorrectable errors that crash the server.  
- Action: schedule a DIMM replacement before it fails uncorrectably.  
- BMC logs typically identify the slot; vendor tooling can confirm.

## Q5. What is Redfish, and why is it preferred over legacy IPMI?
**Answer:**  
- **Redfish** is a modern, RESTful, JSON-based API standard from DMTF for server management.  
- Advantages over IPMI:
  - Secure by default (HTTPS, modern auth).
  - Structured data and schema.
  - Easier to script and automate across vendors.
  - Better suited to large-fleet automation.
- IPMI is older, less secure, and harder to standardize.

## Q6. How do you manage firmware updates at scale?
**Answer:**  
- Maintain an **approved firmware baseline** per server SKU.  
- Stage firmware bundles on a local repository for offline-friendly rollout.  
- Update one fault domain at a time; never update all hosts simultaneously.  
- Validate post-update: boot success, hardware health, workload performance.  
- Track per-host firmware versions in CMDB for audit and recall purposes.  
- Coordinate with vendor security advisories; some firmware updates fix critical CVEs.

## Q7. How do you safely replace a disk in a storage server?
**Answer:**  
1. Confirm the disk is the correct one (vendor disk locator LED, serial number match).  
2. In the storage system, mark the disk out of service (e.g., `ceph osd out`, MinIO heal pause).  
3. Wait for data redistribution or replication to satisfy redundancy requirements.  
4. Physically replace the disk.  
5. Re-add the disk to the storage system; rebuild/backfill data.  
6. Monitor SMART data on the new disk during burn-in.  
7. Update inventory and warranty records.

## Q8. What burn-in tests would you run on a new server before putting it in production?
**Answer:**  
- **memtest86+** or vendor memory diagnostics for several passes to catch DIMM failures.  
- **CPU stress** with `stress-ng` or `mprime` for several hours to validate cooling and stability.  
- **Disk full-write test** with `badblocks -wsv` or vendor tools for each new disk.  
- **fio** I/O benchmark to compare each disk against expected baseline.  
- **iperf3** network test against peer hosts to validate NIC and cabling.  
- Check the system event log for anomalies during burn-in.

## Q9. How do you securely decommission a disk that may have customer data?
**Answer:**  
- For SATA/SAS: ATA Secure Erase or `nvme format` (for NVMe) following vendor guidance.  
- For self-encrypting drives: cryptographic erase via vendor tool.  
- For high-sensitivity environments: physical destruction (degausser, shredding) per policy.  
- Record:
  - Disk serial number.
  - Method used.
  - Operator and timestamp.
  - Destruction certificate, if applicable.
- Update CMDB to `decommissioned` with proof of erasure.

## Q10. What signals tell you that hardware operations are mature?
**Answer:**  
- Predictive failure detection catches most disk failures before customer impact.  
- Firmware and BIOS versions are consistent across each SKU.  
- BMC access is controlled, audited, and on an isolated management network.  
- Inventory is accurate and includes serial, warranty, and lifecycle state.  
- Replacement procedures are documented and rehearsed.  
- Vendor RMAs are tracked end-to-end with SLA adherence.
