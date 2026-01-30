# Phase TODO — Refactor and Repo Cleaning

**Purpose**: Canonical TODO list for phase-based refactor and repo cleaning. Every item has scope, required action, verification criteria, and acceptance gate. No task skipped, summarized, or abandoned.

**Last updated**: 2026-01-30

---

## Repo cleaning (governance structure) — Phase 1

| ID | Scope / location | Required action | Verification criteria | Acceptance gate | Status |
|----|------------------|-----------------|------------------------|-----------------|--------|
| RC-1 | docs/ | Create 00_index, 01_architecture … 07_project_management, 99_archive/2026/YYYYMMDD | `ls docs` shows all dirs | Repo production standard | COMPLETE |
| RC-2 | docs/00_index/ | Create README.md linking all sections | README exists; links to 01..07 and 99_archive | Governance artifact 1 | COMPLETE |
| RC-3 | docs/00_index/ | Create MANIFEST.md listing every doc | Every .md in repo accounted for in MANIFEST | Governance artifact 2 | COMPLETE |
| RC-4 | docs/99_archive/ | Create 2026/20260130_repo_governance_restructure/README.md | Archive dir exists; README explains reason | Governance artifact 4 | COMPLETE |
| RC-5 | Repo root; MANIFEST | Verify root listing; manifest coverage; document PENDING moves | Root listing; find *.md vs MANIFEST; PENDING moves in MANIFEST | No stray docs; traceability | COMPLETE |

---

## PENDING (carry-forward)

### Repo cleaning — physical relocation (Phase 2)

| ID | Scope / location | Required action | Verification criteria | Acceptance gate | Status |
|----|------------------|-----------------|------------------------|----------------|--------|
| RC-6 | Root ARCHITECTURE.md, PROJECT_STRUCTURE.md, QUICK_START.md, CN00_READY.md, SCAFFOLDING_COMPLETE.md | Move to docs/01_architecture or 02/07; copy original to 99_archive first | No file deleted; originals in archive; links updated | No root clutter | PENDING |
| RC-7 | docs/guides, docs/operations, docs/setup | Assign to 02_directives_policies, 03_runbooks_ops, or 06_specs; move; archive originals | Every doc has canonical home in 01..07 | Repo production standard | PENDING |
| RC-8 | cache_nodes_012426_2236/*.md and cache_nodes_012426_2236/docs/*.md | Relocate into docs/01_architecture, 03_runbooks_ops, etc.; archive originals; update cross-links | MANIFEST updated; no broken links | Traceability | PENDING |

**Justification for PENDING**: Physical move of existing docs was deliberately deferred to avoid breaking references in a single large change. MANIFEST and index use current paths. Next phase will perform moves with copy-to-archive-then-relocate and link updates.

### Refactor — streaming and GPU (from prior work)

| ID | Scope / location | Required action | Verification criteria | Acceptance gate | Status |
|----|------------------|-----------------|------------------------|----------------|--------|
| RF-1 | NODE-03–06 stream broker | Implement stream broker on 03–06 (hold SSE/WS, pull from .30, buffer/backpressure) | Service runs; holds connection; streams from .30 | STREAMING_DATA_PLANE | PENDING |
| RF-2 | CORE GPU .30 | Enforce GPU resource arbitration (Mode A or B); TF/vLLM/Ollama limits in config or systemd | Config or script applies limits; health checks used | GPU_RESOURCE_ARBITRATION | PENDING |
| RF-3 | SLO dashboards | Add TTFT, jitter, disconnect rate, queue depth, cache hit rate (NODE-09/10) | Dashboards exist and scrape | NEXT_PHASE_ACTION_PLAN Phase 3 | PENDING |

**Justification for PENDING**: Stream broker is not implemented (docs only). GPU limits are documented but not enforced in checked-in configs. SLO dashboards not yet added.

---

## Verification commands (evidence)

- **Structure**: `ls -la docs/` → 00_index, 01_architecture, 02_directives_policies, 03_runbooks_ops, 04_data_pipelines, 05_qc_validation, 06_specs, 07_project_management, 99_archive.
- **Manifest coverage**: `find . -name "*.md" -not -path "./.git/*" | wc -l` and cross-check with MANIFEST entries.
- **Archive**: `ls docs/99_archive/2026/20260130_repo_governance_restructure/` → README.md exists.
