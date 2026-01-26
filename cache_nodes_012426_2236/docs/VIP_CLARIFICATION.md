# VIP Clarification (192.168.86.18)

- **VIP**: 192.168.86.18, managed by **keepalived** on frontend nodes.
- **No extra Pi**: The VIP floats between active/backup Nginx frontends (e.g. 192.168.86.20). No dedicated hardware for the VIP.
- **Phase 5**: keepalived configs live in `configs/keepalived/` (master/backup). Deploy when adding a second frontend for failover.
