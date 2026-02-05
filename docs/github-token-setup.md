# GitHub Token Setup for Container Image Builds

This document explains how to configure `GITHUB_TOKEN` for pushing container images to `ghcr.io` (GitHub Container Registry).

## Overview

The `build-images.sh` script requires `GITHUB_TOKEN` to authenticate with `ghcr.io` when pushing container images. There are multiple ways to configure this token depending on your use case.

## Creating a GitHub Personal Access Token

1. **Create the token:**
   - Go to: https://github.com/settings/tokens
   - Click "Generate new token" (classic)
   - Or "Generate new token" -> "Fine-grained token" (recommended for better security)

2. **Configure token scopes:**
   - For classic tokens: Select `write:packages`, `read:packages`, `delete:packages`
   - For fine-grained tokens:
     - Repository access: Select "moltbook-org" repository
     - Permissions: Contents (read), Packages (write/read)

3. **Save the token securely:**
   - Copy the token immediately (you won't see it again)
   - Store it in a password manager or secure location

## Configuration Options

### Option 1: Environment Variable (Recommended for Local Builds)

Set the `GITHUB_TOKEN` environment variable before running the build script:

```bash
export GITHUB_TOKEN=your_token_here
./scripts/build-images.sh --push
```

Or pass it inline:

```bash
GITHUB_TOKEN=your_token_here ./scripts/build-images.sh --push
```

**Pros:** Simple, secure (not stored in files)
**Cons:** Must be set each time, not suitable for automated builds

### Option 2: Kubernetes Secret (Recommended for Devpod/CI)

Create a Kubernetes secret to store the token securely:

#### Step 1: Create the secret template

1. Copy the template:
   ```bash
   cp k8s/secrets/github-token-secret-template.yml k8s/secrets/github-token-secret.yml
   ```

2. Fill in the token:
   ```bash
   # Edit the file and replace REPLACE_WITH_GITHUB_TOKEN with your actual token
   editor k8s/secrets/github-token-secret.yml
   ```

#### Step 2: Create a SealedSecret (Recommended)

For production clusters, use SealedSecrets:

```bash
kubeseal --format yaml < k8s/secrets/github-token-secret.yml > k8s/secrets/github-token-sealedsecret.yml
```

Then apply:

```bash
kubectl apply -f k8s/secrets/github-token-sealedsecret.yml
```

#### Step 3: Alternative: Create docker-registry secret for Kaniko

For Kaniko builds, create the proper docker-registry secret:

```bash
kubectl create secret docker-registry docker-config \
  --docker-server=ghcr.io \
  --docker-username=ardenone \
  --docker-password=YOUR_GITHUB_TOKEN \
  --docker-email=noreply@github.com \
  --namespace=moltbook
```

Or create a SealedSecret:

```bash
kubectl create secret docker-registry docker-config \
  --docker-server=ghcr.io \
  --docker-username=ardenone \
  --docker-password=YOUR_GITHUB_TOKEN \
  --docker-email=noreply@github.com \
  --namespace=moltbook \
  --dry-run=client -o yaml | \
kubeseal --format yaml > k8s/secrets/docker-config-sealedsecret.yml
```

#### Step 4: Use the secret in devpod

Mount the secret as an environment variable in your devpod configuration:

```yaml
apiVersion: loft.sh/v1
kind: DevPod
metadata:
  name: moltbook-devpod
spec:
  template:
    spec:
      containers:
        - name: main
          env:
            - name: GITHUB_TOKEN
              valueFrom:
                secretKeyRef:
                  name: github-token
                  key: GITHUB_TOKEN
```

**Pros:** Secure, reusable, works with automated builds
**Cons:** Requires Kubernetes setup, initial configuration needed

### Option 3: Pass at Build Time

Pass the token directly when running the script:

```bash
GITHUB_TOKEN=your_token ./scripts/build-images.sh --push
```

**Pros:** Simple, explicit
**Cons:** Must be specified each time, token visible in process list

### Option 4: GitHub Actions (Recommended for CI/CD)

The repository includes a GitHub Actions workflow that automatically builds and pushes images on commits. The workflow uses `GITHUB_TOKEN` automatically (provided by GitHub Actions).

**Configuration:** `.github/workflows/build-images.yml`

**Pros:** Fully automated, secure (GitHub manages the token), triggers on push
**Cons:** Requires GitHub Actions to be enabled

## Security Best Practices

1. **Never commit tokens to Git:**
   - Use `.gitignore` to exclude secret files
   - Use SealedSecrets for Kubernetes
   - Use GitHub Secrets for Actions

2. **Use fine-grained tokens:**
   - Classic tokens have broad access
   - Fine-grained tokens limit access to specific repositories

3. **Rotate tokens regularly:**
   - Set expiration dates on tokens
   - Revoke old tokens after creating new ones

4. **Use environment-specific tokens:**
   - Different tokens for dev, staging, production
   - Makes it easier to revoke access if compromised

5. **Audit token usage:**
   - Check GitHub Settings > Developer settings > Personal access tokens
   - Monitor for unauthorized usage

## Troubleshooting

### Authentication Failed

```
Error: unauthorized: authentication required
```

**Solution:** Verify the token has `write:packages` scope and is not expired.

### Token Not Found

```
GITHUB_TOKEN environment variable not set
```

**Solution:** Set the environment variable or mount the Kubernetes secret.

### SealedSecret Creation Failed

```
Error: cannot find controller
```

**Solution:** Ensure the SealedSecrets controller is running in your cluster:

```bash
kubectl get pods -n kube-system | grep sealed-secrets
```

## Related Files

- `scripts/build-images.sh` - Main build script
- `scripts/build-with-kaniko.yml` - Kaniko-based build configuration
- `k8s/secrets/github-token-secret-template.yml` - Secret template
- `k8s/secrets/docker-config-sealedsecret.yml` - Docker registry config (to be created)
- `.github/workflows/build-images.yml` - GitHub Actions workflow

## References

- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Creating Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
- [SealedSecrets Documentation](https://github.com/bitnami-labs/sealed-secrets)
