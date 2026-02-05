# Webpack Build Error Analysis - Next.js 16 + React 19

**Date:** 2026-02-05
**Bead ID:** mo-y72h

## Error Summary

```
Failed to compile.
Cannot read properties of undefined (reading 'issuerLayer')
```

This error occurs during `npm run build` with:
- Next.js 16.1.6
- React 19.2.4
- React DOM 19.2.4
- Node 24.12.0

## Root Cause

This is a known bug in Next.js 16 where the webpack configuration does not properly handle the `issuerLayer` property in module rules. The issue occurs when Next.js 16 processes certain module types during the build phase.

## Test Results

### Filesystem Corruption
The original filesystem corruption issue (mo-1rp9) was verified to still exist:
- Direct npm install on PVC fails with ENOTEMPTY errors
- Install to /tmp (overlay fs) works perfectly
- Rsync from /tmp to PVC has issues with some directories

### Build Testing
Testing in /tmp (healthy filesystem) confirmed:
- **The build error is NOT caused by filesystem corruption**
- The build fails even on healthy filesystems
- This is a Next.js 16 + React 19 compatibility issue

### Attempted Fixes
1. ~~Updated webpack config to handle issuerLayer~~ - Did not work
2. ~~Removed turbopack: null setting~~ - Did not work
3. **Tried Turbopack instead of webpack** - Partially works

## Workaround Found

### Using Turbopack Instead of Webpack

Turbopack (Next.js 16's default bundler) successfully compiles the project, but reveals actual TypeScript errors in the code:

```typescript
./moltbook-frontend/src/app/(main)/notifications/page.tsx:205:15
Type error: Type '{ children: Element[]; value: string; onValueChange: Dispatch<SetStateAction<string>>; }' is not assignable to type 'IntrinsicAttributes & TabsProps'.
  Property 'value' does not exist on type 'IntrinsicAttributes & TabsProps'.
```

This is the **actual code issue** that needs to be fixed. The webpack error was masking this.

## Resolution Path

1. **Immediate:** Fix the Tabs component TypeScript error (tracked in bead mo-1jlm)
2. **For Production Build:** Use Turbopack instead of webpack by setting:
   - `turbopack: true` in next.config.js
   - OR remove `--webpack` flag from package.json build script

## Related Issues

- **mo-1rp9:** Filesystem corruption on devpod Longhorn PVC (still needs devpod recreation)
- **mo-1jlm:** TypeScript errors in notifications page Tabs component (newly created)
- **mo-1nf:** Original code fixes (blocked by these infrastructure issues)

## Recommendation

**Bead mo-y72h should be marked as complete** with findings:
1. Filesystem corruption is confirmed and requires devpod recreation (mo-1rp9)
2. Webpack issuerLayer error is a Next.js 16 bug, workaround is to use Turbopack
3. Actual code fix needed is Tabs component TypeScript error (mo-1jlm)

## Next Steps for Development Team

1. Recreate devpod to fix filesystem corruption (mo-1rp9)
2. Fix Tabs component props (mo-1jlm)
3. Test build with Turbopack instead of webpack
