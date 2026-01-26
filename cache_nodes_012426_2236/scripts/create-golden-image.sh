#!/bin/bash
# OKOME – golden image procedure (documentation + helpers)
# Plan: okome_two-node_cache_architecture_implementation
# Usage: ./create-golden-image.sh [frontend|backend]

set -euo pipefail

NODE="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== OKOME Golden Image ==="
echo ""
echo "1. Harden one node (frontend or backend) per 00_FOUNDATION.md and 01_BASIC_SETUP.md."
echo "2. Run install + production reconfig (deploy_frontend_production / deploy_backend_production)."
echo "3. Verify: ./verify.sh and ./okome-validate.sh."
echo "4. Image the SD:"
echo "   - Use Raspberry Pi Imager 'Custom' or dd/server-side clone."
echo "   - Or: shutdown, clone SD (e.g. dd if=/dev/sdX of=okome-golden.img bs=4M status=progress)."
echo "5. Write image to new SD, boot, set static IP + hostname for second node."
echo "6. Re-run deploy_frontend_production or deploy_backend_production as appropriate."
echo ""
echo "Node: ${NODE:-any}. Use 'frontend' or 'backend' to print node-specific steps."
echo ""
