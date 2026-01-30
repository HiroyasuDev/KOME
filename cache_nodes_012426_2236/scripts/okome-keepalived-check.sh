#!/bin/bash
# OKOME keepalived health check. Phase 5.
# Exit 0 if Nginx is healthy; 1 otherwise.
curl -sf --connect-timeout 1 --max-time 2 -o /dev/null http://127.0.0.1/ || exit 1
exit 0
