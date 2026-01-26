# OKOME Cache Nodes – Storage Spec

- **Media**: 32GB A1 microSD for both frontend (192.168.86.20) and backend (192.168.86.19).
- **Class**: A1 minimum; Class 10 recommended.
- **Usage**: OS, Nginx cache (frontend), Redis in-memory (backend; no persistence). No large persistent datasets on SD.

See [00_FOUNDATION.md](../00_FOUNDATION.md) for fstab and SD hardening.
