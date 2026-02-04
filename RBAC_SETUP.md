# RBAC Setup Required for Moltbook Deployment

## Status: 🔴 BLOCKED - Waiting for Cluster Admin Action

## Issue
The Moltbook deployment cannot proceed because the devpod ServiceAccount lacks permissions to create namespaces in the ardenone-cluster.

## Required Action
A cluster administrator must apply the RBAC manifest located at:
```
/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

## Command to Run (Cluster Admin Only)
```bash
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

## What This Manifest Does
The RBAC manifest grants the `devpod:default` ServiceAccount the following permissions:

1. **Namespace Management**
   - Create namespaces
   - Get, list, watch namespaces

2. **RBAC Management within Namespaces**
   - Create and manage Roles
   - Create and manage RoleBindings

3. **Traefik Middleware Management**
   - Create, update, delete Traefik middlewares
   - Get, list middlewares

## Why This Is Needed
Moltbook deployment requires creating a dedicated namespace with its own RBAC policies and Traefik routing configuration. The devpod ServiceAccount needs these elevated permissions to set up the infrastructure.

## Related Beads
- **mo-2aid**: RBAC: Grant devpod namespace creation permissions for Moltbook deployment (current bead)
- **mo-1kib**: Blocker: Apply RBAC manifest - devpod namespace creation permissions (tracking bead)

## Verification
After the RBAC manifest is applied, verify permissions with:
```bash
kubectl auth can-i create namespace --as=system:serviceaccount:devpod:default
```

Expected output: `yes`

## Security Considerations
- This grant is scoped specifically to namespace creation and management
- Does not grant full cluster admin privileges
- Follows principle of least privilege
- Only applies to devpod:default ServiceAccount
