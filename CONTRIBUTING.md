# Contributing to KOME

Thank you for your interest in contributing to KOME!

## Design Philosophy

KOME follows a **"boring and disposable"** design philosophy:

- **Simplicity**: NGINX only, no additional services
- **Disposability**: Fast rebuild (< 15 minutes)
- **Minimalism**: No Redis, Kubernetes, TLS, or complex features
- **SD-Friendly**: Minimal writes, log rotation

## Contribution Guidelines

### What We Accept

- Bug fixes
- Documentation improvements
- Performance optimizations (that maintain simplicity)
- Script improvements
- Test additions

### What We Don't Accept

- Features that add complexity (Redis, Kubernetes, etc.)
- TLS/SSL certificates (LAN-only design)
- Active health checks (passive failover by design)
- Lua/JavaScript in NGINX (pure config only)

## Development Workflow

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature`
3. **Make your changes**
4. **Test your changes**: `./scripts/test.sh`
5. **Commit your changes**: `git commit -m "Add feature"`
6. **Push to your fork**: `git push origin feature/your-feature`
7. **Open a Pull Request**

## Code Style

### Shell Scripts

- Use `set -euo pipefail`
- Add comments for complex logic
- Follow existing script patterns
- Run ShellCheck before committing

### Documentation

- Use Markdown
- Keep it concise
- Include examples
- Update related docs

## Testing

Before submitting:

```bash
# Run tests
./scripts/test.sh

# Check scripts
shellcheck scripts/*.sh
```

## Questions?

Open an issue for discussion before making large changes.

---

**Remember**: Keep it simple, boring, and disposable! 🚀
