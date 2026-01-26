# Hotwash: OKOME Two-Node Cache Implementation

**Date**: 2026-01-25  
**Reference**: [2026-01-25_After_Action_Report_OKOME_Two-Node.md](2026-01-25_After_Action_Report_OKOME_Two-Node.md)  
**Purpose**: Lessons learned for incorporation into future comprehensive playbooks.

---

## 1. Environment & Reachability

### What Happened
- SSH and deploy runs from the automated environment could not resolve `cn01.local` / `nc01.local` or reach the Pi over the LAN.
- Connections timed out; `.local` mDNS was unavailable from that environment.

### Lessons Learned
- **Playbook**: Assume "control plane" (where scripts run) may not be on the same network as targets. Document **where** each playbook step runs (local Mac, CI, jump host, etc.).
- **Playbook**: Prefer **IP-based** targets for automation (e.g. 192.168.86.19) when hostname resolution is unreliable; keep hostnames for human use.
- **Playbook**: Include a **reachability** pre-check (ping, SSH, or HTTP) and clear failure guidance (e.g. "Run from host with LAN access to 192.168.86.x").

### For Future Playbooks
```
- Pre-flight: Verify control plane can reach all targets (ping/SSH/HTTP).
- Default automation targets: IPs; hostnames optional.
- Document: "Execute from [host] with access to [networks]."
```

---

## 2. Static IP: NetworkManager vs dhcpcd

### What Happened
- Static IP was configured via `/etc/dhcpcd.conf` on CN01, but the node used **NetworkManager**. After reboot, the Pi stayed on DHCP (192.168.86.132); dhcpcd config had no effect.
- Static IP 192.168.86.19 was applied only after using `nmcli connection modify` and `nmcli connection up`.

### Lessons Learned
- **Playbook**: **Detect** which stack manages the primary interface (NetworkManager vs dhcpcd vs netplan) before applying static IP.
- **Playbook**: Prefer **NetworkManager** when `systemctl is-active NetworkManager` and `nmcli` exists; else use dhcpcd (or netplan) with explicit branches.
- **Playbook**: After changing static IP via `nmcli connection up`, SSH sessions to the **old** IP will drop; run long-lived installs via **nohup** (or equivalent) so they survive disconnect.

### For Future Playbooks
```
- Static IP procedure:
  1. If NetworkManager active: use nmcli (modify + up).
  2. Else if /etc/dhcpcd.conf: append eth0 block; reboot to apply.
- For NM "up": run install/deploy in background (nohup) so it survives SSH drop.
- Verify post-change: connect to NEW IP, not old.
```

---

## 3. Deploy vs. Install: Background Execution

### What Happened
- When deploy over SSH ran `nmcli connection up`, the Pi’s IP changed mid-session and SSH dropped. The install script would have been killed if run in the foreground.

### Lessons Learned
- **Playbook**: When a step **changes the target’s IP** (or otherwise drops SSH), run that step and **all dependent steps** in a **detached** way (nohup, systemd-run, or at).
- **Playbook**: Deployment scripts should **always** use nohup (or similar) for the remote install when static-IP application is part of the same run, then **poll** the new IP for success (e.g. Redis PONG, HTTP 200/504).

### For Future Playbooks
```
- If deploy applies static IP on target: run remote install via nohup.
- After nohup: sleep N, then verify via NEW IP (curl, redis-cli, etc.).
- Log output to /tmp/install_*.log for debugging.
```

---

## 4. Verification Semantics: Upstream Down vs. Frontend Down

### What Happened
- Frontend Nginx was correct and running, but upstream (192.168.86.25:8000) was down. Nginx returned **504 Gateway Time-out**. Initial verify treated non-2xx as failure.

### Lessons Learned
- **Playbook**: **Separate** "frontend reachable" from "upstream reachable." HTTP 502/503/504 from Nginx = frontend **up**, upstream **down or slow**.
- **Playbook**: Treat 502/503/504 as **success** for "cache node ready" checks; treat connection refused / timeout as **failure**.
- **Playbook**: Optional stricter check: "upstream reachable" (e.g. 200 from frontend) as a **separate** validation step or play.

### For Future Playbooks
```
- Frontend "ready": HTTP 200–204, 301–302, or 502–504 from Nginx.
- Frontend "down": connection refused or timeout.
- Upstream "reachable": optional; e.g. 200 from / or /health.
```

---

## 5. Nginx Config Conflicts

### What Happened
- An existing `kome-cache.conf` defined `limit_req_zone ... api_limit`. The new `okome-frontend.conf` also defined `api_limit`. Nginx failed to load due to duplicate zone names.

### Lessons Learned
- **Playbook**: Before deploying a new Nginx config, **remove or disable** conflicting configs (e.g. same server_name, same limit_req_zone names, or legacy cache configs).
- **Playbook**: Use **unique** zone names (e.g. `okome_ui_limit`, `okome_api_limit`) to avoid collisions with unknown existing configs.
- **Playbook**: Include `nginx -t` after config changes and **before** reload/restart.

### For Future Playbooks
```
- Pre-deploy: remove/disable old OKOME/KOME Nginx configs in conf.d.
- Use unique zone names per deployment (e.g. prefix with project).
- Always run nginx -t before systemctl restart nginx.
```

---

## 6. Per-Node Credentials

### What Happened
- CN00 and CN01 use **different** passwords (usshopper vs ussfitzgerald). Verify and deploy scripts had to support both.

### Lessons Learned
- **Playbook**: **Document** credentials per node (or per role) in a dedicated access section (e.g. READY.md). Use env vars (e.g. `OKOME_FRONTEND_PASS`, `OKOME_BACKEND_PASS`) rather than hardcoding.
- **Playbook**: Verification scripts that SSH to **multiple** nodes must use the **correct** credential per node.

### For Future Playbooks
```
- Access table: Node | IP | User | Password (or key).
- Env vars: OKOME_FRONTEND_PASS, OKOME_BACKEND_PASS (or OKOME_PASS if unified).
- Verify/deploy: use per-node credentials for SSH/scp.
```

---

## 7. Apt Conffile Prompts During Unattended Upgrade

### What Happened
- `apt-get upgrade` prompted for `dhcpcd.conf` (keep vs. replace). Unattended run hung on the prompt; `dpkg --configure -a` later fixed it.

### Lessons Learned
- **Playbook**: Use `DEBIAN_FRONTEND=noninteractive` for apt/dpkg in **all** non-interactive runs.
- **Playbook**: For conffile prompts, **prefer** `dpkg --configure -a` with a **noninteractive** default (e.g. `echo N | dpkg --configure -a`) or use `-o Dpkg::Options::="--force-confdef"` etc. as appropriate.
- **Playbook**: After upgrades that touch network/managed configs, **re-verify** static IP and services (e.g. `verify_backend`).

### For Future Playbooks
```
- All apt/dpkg: DEBIAN_FRONTEND=noninteractive.
- Document expected conffile choices (keep vs. replace) and how to automate.
- Post-upgrade: re-run verify scripts for affected nodes.
```

---

## 8. Curl Timeouts in Verification

### What Happened
- `curl` to frontend `/assets/` (which proxies to upstream) could **hang** when upstream was down, causing verify scripts to time out.

### Lessons Learned
- **Playbook**: **Always** set `--connect-timeout` and `--max-time` (or equivalent) on curl calls used in automation.
- **Playbook**: Use **short** timeouts (e.g. 3–5s connect, 5–10s total) for "is it up?" checks; avoid indefinite wait.

### For Future Playbooks
```
- All curl in verify: --connect-timeout 3 --max-time 8 (or similar).
- Prefer fast failure over long wait for "ready" checks.
```

---

## 9. Golden Image & Consistency

### What Happened
- Two nodes (CN00, CN01) were configured with different roles, credentials, and configs. A shared structure (`cache_nodes_012426_2236`) and scripts (deploy, verify) ensured consistency.

### Lessons Learned
- **Playbook**: Use a **single** layout (configs, scripts, docs) for all nodes. Parameterize by **role** (frontend vs. backend) and **node** (IP, credentials).
- **Playbook**: **One-command validation** (`okome-validate.sh`) that runs **per-node** checks (e.g. `verify_frontend`, `verify_backend`) plus **connectivity** checks reduces missed steps and speeds validation.
- **Playbook**: **READY.md**-style checklist (access, verify, deploy, next steps) improves handoff and ops.

### For Future Playbooks
```
- Single repo layout; role-based and node-based parameterization.
- One-command validate: per-node verify + connectivity.
- READY-style doc: access, verify, deploy, next steps.
```

---

## 10. Playbook Structure Recommendations

### High-Level Structure
1. **Pre-flight**: Reachability, credentials, and tool checks (sshpass, curl, etc.).
2. **Per-node procedures**: Static IP (NM vs. dhcpcd), install, config deploy, service enable/start.
3. **Verification**: Per-node (e.g. nginx/Redis, config, IP) and connectivity (HTTP, Redis PONG).
4. **Post-execution**: READY-style summary, next steps (e.g. start orchestrator, point to Redis).

### Checklist Items to Include
- [ ] Control plane can reach all target IPs.
- [ ] Credentials per node documented and used in scripts.
- [ ] Static IP method (NM vs. dhcpcd) detected and applied.
- [ ] Install run via nohup if static IP changes during deploy.
- [ ] Nginx config conflicts removed; `nginx -t` before restart.
- [ ] Verification treats 502/503/504 as "frontend up."
- [ ] All curl use --connect-timeout and --max-time.
- [ ] DEBIAN_FRONTEND=noninteractive for apt/dpkg.
- [ ] One-command validate run and passed.
- [ ] READY/checklist updated with access and next steps.

---

**Document version**: 1.0  
**Last updated**: 2026-01-25  
**For**: Incorporation into OKOME/KOME and broader infrastructure playbooks.
