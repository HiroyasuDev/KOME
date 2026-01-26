# Cache Node Client Configuration Guide

## Overview

The OKOME frontend cache node (CN00 at `192.168.86.20`) accelerates static frontend assets. This guide explains how to configure clients and browsers to use the cache node.

## When to Use the Cache Node

**Use the cache node for:**
- Browser access to Open WebUI
- Any client accessing frontend assets (`/assets/`, `/ui-schema/`, `/version/`)

**Do NOT use the cache node for:**
- API calls (`/v1/*`, `/infer`, `/stream`)
- Direct service-to-service communication
- IDE integrations (Continue, Cursor) - these use Gateway directly

## Browser Configuration

### Option 1: Direct Access (Recommended)

Simply point your browser to the cache node instead of the OptiPlex:

**Before (direct to OptiPlex):**
```
http://192.168.86.25:3000
```

**After (via cache node):**
```
http://192.168.86.20
```

The cache node automatically proxies to the OptiPlex for non-cached content.

### Option 2: Browser Bookmarks

Update your bookmarks:
- **Old**: `http://192.168.86.25:3000`
- **New**: `http://192.168.86.20`

### Option 3: Local DNS (Optional)

If you want a friendly name, add to `/etc/hosts` (Linux/macOS) or `C:\Windows\System32\drivers\etc\hosts` (Windows):

```
192.168.86.20  okome.local
```

Then access via: `http://okome.local`

## Client Application Configuration

### Open WebUI Environment Variables

If you're running Open WebUI in a way that allows configuration, you can set:

```bash
WEBUI_URL=http://192.168.86.20
```

However, since Open WebUI runs in Docker with `network_mode: host`, it binds directly to the OptiPlex. The cache node sits in front as a transparent proxy, so no Open WebUI configuration changes are needed.

### API Clients (Gateway)

**Do NOT** point API clients to the cache node. Use the Gateway directly:

```bash
# Correct - Gateway on OptiPlex
GATEWAY_URL=http://192.168.86.25:8088

# Wrong - Don't use cache node for API
GATEWAY_URL=http://192.168.86.20  # ❌
```

The cache node only caches frontend assets, not API responses.

## IDE Integration

IDE integrations (Continue, Cursor) should continue using the Gateway directly:

```json
{
  "apiBase": "http://192.168.86.25:8088",
  "apiKey": "your-api-key"
}
```

**Do not** point IDE integrations to the cache node.

## CLI Tools

OKOME CLI tools should use Gateway directly:

```bash
# Correct
export GATEWAY_URL=http://192.168.86.25:8088

# Wrong
export GATEWAY_URL=http://192.168.86.20  # ❌
```

## Verification

### Test Cache Node Access

```bash
# Should return 200 OK
curl -I http://192.168.86.20

# Check cache headers (for cached paths)
curl -I http://192.168.86.20/assets/app.js
# Look for: X-Cache: HIT or X-Cache: MISS
```

### Test from Browser

1. Open browser developer tools (F12)
2. Navigate to `http://192.168.86.20`
3. Check Network tab
4. Look for requests to `/assets/`, `/ui-schema/`, `/version/`
5. Check response headers for `X-Cache: HIT` on second load

## Failure Behavior

If the cache node is unavailable:

- **Browser**: Will show connection error (no automatic failover)
- **Manual failover**: Point browser directly to `http://192.168.86.25:3000`

The cache node is designed for performance, not high availability. If it fails, simply use the OptiPlex directly until the cache node is restored.

## Performance Benefits

Using the cache node provides:

- **Faster asset loading**: Cached assets served in < 10ms vs ~50-100ms from OptiPlex
- **Reduced OptiPlex load**: Static assets don't hit the main server
- **Better user experience**: Faster page loads, especially on repeat visits

## Troubleshooting

### Browser Can't Connect to Cache Node

1. Verify cache node is running:
   ```bash
   curl -I http://192.168.86.20
   ```

2. Check network connectivity:
   ```bash
   ping 192.168.86.20
   ```

3. Verify NGINX is running on cache node:
   ```bash
   sshpass -p "usshopper" ssh -p 22 ncadmin@192.168.86.20 \
     "sudo systemctl status nginx"
   ```

### Cache Not Working

1. Check cache headers in browser dev tools
2. Verify requests are to cached paths (`/assets/`, `/ui-schema/`, `/version/`)
3. Check cache node logs:
   ```bash
   sshpass -p "usshopper" ssh -p 22 ncadmin@192.168.86.20 \
     "sudo tail -f /var/log/nginx/access.log | grep X-Cache"
   ```

### Slow Performance

1. Verify cache hit rate:
   ```bash
   ./scripts/cache-node-stats.sh
   ```

2. Check if cache is actually being used (look for `X-Cache: HIT`)
3. Verify upstream (OptiPlex) is responsive:
   ```bash
   curl -I http://192.168.86.25:3000
   ```

## Summary

| Client Type | Configuration |
|-------------|---------------|
| **Browser** | Use `http://192.168.86.20` instead of `http://192.168.86.25:3000` |
| **API Clients** | Continue using `http://192.168.86.25:8088` (Gateway) |
| **IDE Integrations** | Continue using `http://192.168.86.25:8088` (Gateway) |
| **CLI Tools** | Continue using `http://192.168.86.25:8088` (Gateway) |

The cache node is transparent for frontend assets - just point your browser to it instead of the OptiPlex.
