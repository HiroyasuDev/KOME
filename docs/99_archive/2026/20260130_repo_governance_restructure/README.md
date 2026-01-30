# Archive: 2026-01-30 — Repo governance restructure

**Reason**: Establish mandatory documentation structure and governance (00_index, 01_architecture … 07_project_management, 99_archive) per phase-based refactor and repo-cleaning directive.

**Actions taken**:
- Created docs/00_index, 01_architecture, 02_directives_policies, 03_runbooks_ops, 04_data_pipelines, 05_qc_validation, 06_specs, 07_project_management.
- Created docs/00_index/README.md (index linking all sections).
- Created docs/00_index/MANIFEST.md (every doc listed with purpose, path, status, owner).
- Created docs/99_archive/2026/20260130_repo_governance_restructure/ (this folder).

**No files deleted.** No physical move of existing docs in this phase; MANIFEST lists current paths. Future phase: relocate docs into 01_architecture etc., copy originals here before path change, then update links.

**Verification**: docs/00_index/README.md and MANIFEST.md exist; directory structure exists; find for *.md matches MANIFEST entries.
