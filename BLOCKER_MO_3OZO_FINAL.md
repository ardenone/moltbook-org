# CRITICAL BLOCKER: mo-3ozo - Devpod Filesystem Corruption

## Task Requirements
- Generate `package-lock.json` for Next.js 16.1.6 (matching `package.json`)
- Run tests if applicable
- Commit changes

## Status: **BLOCKED - Infrastructure Failure**

## Root Cause
The devpod environment has **severe overlay filesystem corruption** that causes files to disappear after creation. This is a critical infrastructure issue that prevents any npm/pnpm operations from completing successfully.

## Evidence of Filesystem Corruption

### Files That Disappeared
1. **package-lock.json** (created via `pnpm import` at 11:36) - now gone
2. **pnpm-lock.yaml** (existed earlier) - now gone
3. **node_modules** - repeatedly corrupted during npm install

### Error Patterns Observed
```
ENOTEMPTY: directory not empty, rmdir during cleanup
exit code 137 (Killed) despite 62GB RAM + 24GB swap
exit code 217 (filesystem errors)
TAR_ENTRY_ERROR ENOENT errors throughout extraction
```

## Timeline of Attempts

| Time | Attempt | Result |
|------|---------|--------|
| 11:24 | npm install | Killed (137) |
| 11:25 | npm install --clean | Killed (137) |
| 11:26 | npm install --legacy-peer-deps | Killed (137) |
| 11:27 | Docker build | Overlay mount errors |
| 11:30 | Single-threaded npm install | ENOTEMPTY errors (217) |
| 11:36 | pnpm import | **Created package-lock.json** |
| 11:40 | Verify files | **package-lock.json GONE** |

## Infrastructure Details

### Memory (Appears Sufficient)
- Total RAM: 62GB
- Available: 50GB
- Swap: 24GB
- No cgroup limits detected

### Filesystem (Corrupted)
- Overlay filesystem issues
- Files disappear after creation
- Directory removal failures (ENOTEMPTY)
- Docker overlay mount errors

## Related Beads
- **mo-1ch1** (Closed): Fix: npm install OOM in devpod environment
  - Status: Resolved via pnpm import, but files disappeared
  - Action: Re-open as infrastructure issue

## Resolution Options

### Option 1: Fresh Devpod (RECOMMENDED)
- Spawn a new devpod with clean filesystem
- Run `npx pnpm@latest import` to generate package-lock.json
- Commit and push

### Option 2: External Build
- Generate package-lock.json outside this devpod
- Copy into repository
- Commit

### Option 3: Accept pnpm-lock.yaml
- Commit pnpm-lock.yaml instead of package-lock.json
- Update Dockerfile to use pnpm instead of npm
- Requires: `npm install -g pnpm` in Dockerfile

## package.json State (Correct)
```json
{
  "name": "moltbook-web",
  "next": "^16.1.6",
  "react": "^19.0.0",
  "react-dom": "^19.0.0"
}
```

The `package.json` is correctly configured for Next.js 16.1.6. The issue is purely the inability to generate a lockfile in this corrupted environment.

## Recommendation
**This devpod is unusable for npm operations. Request a fresh devpod.**

## Files to Commit (when environment is fixed)
- `moltbook-frontend/package-lock.json` (generated, Next.js 16.1.6)
- `BLOCKER_MO_3OZO_FINAL.md` (this documentation)

## Commit Message (when ready)
```
feat(mo-3ozo): Fix: Update package-lock.json for Next.js 16.1.6

Generated package-lock.json using pnpm import to match package.json
Next.js version 16.1.6.

Co-Authored-By: Claude Code <noreply@anthropic.com>
```
