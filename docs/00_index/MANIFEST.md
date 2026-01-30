# KOME Documentation Manifest

**Purpose**: Single source of truth for every doc in the repository. Every doc is accounted for exactly once.

**Verification**: Run `find . -name "*.md" -not -path "./.git/*"` and ensure each path appears in this manifest.

**Last updated**: 2026-01-30

---

## Format

| Purpose | Canonical path | Status | Owner |
|---------|----------------|--------|-------|
| One-line purpose | Path from repo root | Current / Draft / Archived | Unassigned or name |

---

## Root

| Purpose | Canonical path | Status | Owner |
|---------|----------------|--------|-------|
| Project readme | README.md | Current | Unassigned |
| High-level architecture | ARCHITECTURE.md | Current | Unassigned |
| Contribution guidelines | CONTRIBUTING.md | Current | Unassigned |
| Project structure | PROJECT_STRUCTURE.md | Current | Unassigned |
| Quick start | QUICK_START.md | Current | Unassigned |
| CN00 readiness | CN00_READY.md | Current | Unassigned |
| Scaffolding completion | SCAFFOLDING_COMPLETE.md | Current | Unassigned |

---

## docs/ (root docs tree)

| Purpose | Canonical path | Status | Owner |
|---------|----------------|--------|-------|
| Index landing | docs/00_index/README.md | Current | Unassigned |
| Doc manifest | docs/00_index/MANIFEST.md | Current | Unassigned |
| Phase TODO (refactor + repo cleaning) | docs/07_project_management/PHASE_TODO.md | Current | Unassigned |
| AAR Repo Governance Phase 1 | docs/07_project_management/20260130_AAR_Repo_Governance_Phase1.md | Current | Unassigned |
| Archive README 20260130 | docs/99_archive/2026/20260130_repo_governance_restructure/README.md | Current | Unassigned |
| Backend caching guide | docs/guides/backend-caching.md | Current | Unassigned |
| Client config guide | docs/guides/client-config.md | Current | Unassigned |
| Troubleshooting guide | docs/guides/troubleshooting.md | Current | Unassigned |
| Operations runbook | docs/operations/runbook.md | Current | Unassigned |
| Quick reference | docs/operations/quick-reference.md | Current | Unassigned |
| Installation setup | docs/setup/installation.md | Current | Unassigned |

---

## cache_nodes_012426_2236/ (two-node cache implementation)

| Purpose | Canonical path | Status | Owner |
|---------|----------------|--------|-------|
| Cache nodes readme | cache_nodes_012426_2236/README.md | Current | Unassigned |
| Phase 0 foundation | cache_nodes_012426_2236/00_FOUNDATION.md | Current | Unassigned |
| Phase 1 basic setup | cache_nodes_012426_2236/01_BASIC_SETUP.md | Current | Unassigned |
| Phase 2 failover & observability | cache_nodes_012426_2236/02_FAILOVER_OBSERVABILITY.md | Current | Unassigned |
| Phase 3 cache planner | cache_nodes_012426_2236/03_CACHE_PLANNER.md | Current | Unassigned |
| Phase 4 advanced features | cache_nodes_012426_2236/04_ADVANCED_FEATURES.md | Current | Unassigned |
| Phase 5 enterprise hardening | cache_nodes_012426_2236/05_ENTERPRISE_HARDENING.md | Current | Unassigned |
| Phase 6 SRE runbook | cache_nodes_012426_2236/06_SRE_RUNBOOK.md | Current | Unassigned |
| Streaming architecture | cache_nodes_012426_2236/STREAMING_ARCHITECTURE.md | Current | Unassigned |
| Gaps and incomplete | cache_nodes_012426_2236/GAPS_AND_INCOMPLETE.md | Current | Unassigned |
| Ready checklist | cache_nodes_012426_2236/READY.md | Current | Unassigned |

---

## cache_nodes_012426_2236/docs/

| Purpose | Canonical path | Status | Owner |
|---------|----------------|--------|-------|
| Distributed 10-node architecture | cache_nodes_012426_2236/docs/DISTRIBUTED_10_NODE_ARCHITECTURE.md | Current | Unassigned |
| GPU host TensorFlow integration | cache_nodes_012426_2236/docs/GPU_HOST_TENSORFLOW_INTEGRATION.md | Current | Unassigned |
| GPU resource arbitration | cache_nodes_012426_2236/docs/GPU_RESOURCE_ARBITRATION.md | Current | Unassigned |
| Infrastructure reference | cache_nodes_012426_2236/docs/INFRASTRUCTURE_REFERENCE.md | Current | Unassigned |
| Next-phase action plan | cache_nodes_012426_2236/docs/NEXT_PHASE_ACTION_PLAN.md | Current | Unassigned |
| Storage spec | cache_nodes_012426_2236/docs/STORAGE_SPEC.md | Current | Unassigned |
| Streaming data-plane | cache_nodes_012426_2236/docs/STREAMING_DATA_PLANE.md | Current | Unassigned |
| VIP clarification | cache_nodes_012426_2236/docs/VIP_CLARIFICATION.md | Current | Unassigned |

---

## reports/

| Purpose | Canonical path | Status | Owner |
|---------|----------------|--------|-------|
| Reports index | reports/README.md | Current | Unassigned |
| After-action report OKOME two-node | reports/2026-01-25_After_Action_Report_OKOME_Two-Node.md | Current | Unassigned |
| Hotwash lessons learned | reports/2026-01-25_Hotwash_Lessons_Learned.md | Current | Unassigned |

---

## .cursor/plans/

| Purpose | Canonical path | Status | Owner |
|---------|----------------|--------|-------|
| Two-node cache implementation plan | .cursor/plans/okome_two-node_cache_architecture_implementation_04d8a1cb.plan.md | Current | Unassigned |

---

## Governance

- **Archive**: docs/99_archive/2026/YYYYMMDD_reason/ — historical snapshots; never deleted.
- **PENDING**: Physical relocation of root and cache_nodes docs into 01_architecture, 02_directives_policies, 03_runbooks_ops, etc., with originals copied to 99_archive before removal from original path. No file deleted; originals preserved in archive.
