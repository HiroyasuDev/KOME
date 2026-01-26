# KOME Project Structure

```
KOME/
├── .github/
│   └── workflows/
│       └── test.yml              # CI/CD workflows
├── .cursor/                       # Cursor IDE configuration
├── docs/
│   ├── guides/
│   │   ├── client-config.md      # Client configuration guide
│   │   └── troubleshooting.md   # Troubleshooting guide
│   ├── operations/
│   │   ├── runbook.md            # Operations runbook
│   │   └── quick-reference.md   # Quick reference
│   └── setup/
│       └── installation.md      # Installation guide
├── infra/
│   ├── cache/
│   │   └── nginx-kome-cache.conf # NGINX cache configuration
│   └── monitoring/               # Monitoring configs (future)
├── scripts/
│   ├── bootstrap.sh              # Initial setup script
│   ├── deploy.sh                 # Deployment script
│   ├── verify-connectivity.sh    # Connectivity verification
│   ├── test.sh                   # Cache testing
│   ├── stats.sh                  # Statistics
│   └── purge.sh                  # Cache purge
├── tests/
│   └── test_cache.sh             # Test suite
├── .gitignore                    # Git ignore patterns
├── .pre-commit-config.yaml       # Pre-commit hooks
├── ARCHITECTURE.md               # Architecture documentation
├── CONTRIBUTING.md               # Contribution guidelines
├── LICENSE                       # MIT License
├── Makefile                      # Make commands
├── PROJECT_STRUCTURE.md          # This file
└── README.md                     # Main README

```

## Directory Descriptions

### `.github/workflows/`
CI/CD workflows for automated testing and validation.

### `docs/`
Documentation organized by purpose:
- **guides/**: How-to guides for specific tasks
- **operations/**: Operational documentation and runbooks
- **setup/**: Installation and setup guides

### `infra/`
Infrastructure configuration files:
- **cache/**: NGINX cache configuration
- **monitoring/**: Monitoring configurations (future)

### `scripts/`
Operational scripts for deployment, testing, and maintenance.

### `tests/`
Test suites for validating functionality.

## File Naming Conventions

- **Scripts**: Lowercase with hyphens (`bootstrap.sh`)
- **Documentation**: Lowercase with hyphens (`installation.md`)
- **Configuration**: Lowercase with hyphens (`nginx-kome-cache.conf`)

## Key Files

- **README.md**: Project overview and quick start
- **ARCHITECTURE.md**: System architecture and design
- **CONTRIBUTING.md**: Contribution guidelines
- **Makefile**: Common commands (`make deploy`, `make test`)

---

**Last Updated**: 2026-01-22
