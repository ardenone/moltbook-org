# GITHUB_TOKEN Setup for Container Image Builds

This document describes how to configure the `GITHUB_TOKEN` environment variable required by `scripts/build-images.sh` for pushing container images to `ghcr.io`.

## Background

The `build-images.sh` script requires authentication with GitHub Container Registry (ghcr.io) to push built images. This is done via a GitHub Personal Access Token (PAT) with the appropriate scopes.

## Prerequisites

- GitHub account with access to the `ardenone` organization
- Ability to push to `ghcr.io/ardenone/*` repositories

## Creating a GitHub Personal Access Token

1. Navigate to https://github.com/settings/tokens
2. Click **Generate new token** (select **Generate new token (classic)** if prompted)
3. Configure the token:
   - **Name**: `Moltbook Container Builds` (or descriptive name)
   - **Expiration**: Choose appropriate expiration (or no expiration for CI/CD)
   - **Scopes**:
     - `write:packages` - Required for pushing images
     - `read:packages` - Required for pulling images
4. Click **Generate token**
5. **Important**: Copy the token immediately. You won't be able to see it again.

## Configuration Options

### Option 1: Local Environment File (Recommended for Devpods)

Use a `.env.local` file to store the token in your project directory (gitignored).

1. Create the environment file from the template:
   ```bash
   cp .env.local.template .env.local
   ```

2. Edit `.env.local` with your token:
   ```bash
   GITHUB_TOKEN=ghp_your_actual_token_here
   GITHUB_USERNAME=ardenone
   ```

3. Source the environment before building:
   ```bash
   source scripts/load-env.sh
   ./scripts/build-images.sh --push
   ```

The `.env.local` file is already in `.gitignore`, so it won't be committed to git.

### Option 2: Direnv (Recommended for Local Development)

Use `direnv` to automatically load the token when entering the project directory.

1. Install `direnv` if not already installed:
   ```bash
   # Ubuntu/Debian
   sudo apt install direnv

   # macOS
   brew install direnv
   ```

2. Hook direnv into your shell:
   ```bash
   # For bash
   echo 'eval "$(direnv hook bash)"' >> ~/.bashrc

   # For zsh
   echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
   ```

3. Restart your shell or run `source ~/.bashrc` / `source ~/.zshrc`

4. Create `.envrc` from the template:
   ```bash
   cp .envrc.template .envrc
   ```

5. Edit `.envrc` with your token:
   ```bash
   export GITHUB_TOKEN="your_actual_token_here"
   export GITHUB_USERNAME="your_github_username"  # Optional
   ```

6. Allow direnv:
   ```bash
   direnv allow
   ```

The token will now be automatically loaded when you enter the project directory.

### Option 3: Shell Environment Variable

Set the token in your shell profile:

```bash
# Add to ~/.bashrc or ~/.zshrc
export GITHUB_TOKEN="your_actual_token_here"
export GITHUB_USERNAME="your_github_username"  # Optional
```

Then reload: `source ~/.bashrc` or `source ~/.zshrc`

### Option 4: Inline Environment Variable

Pass the token inline when running the build script:

```bash
GITHUB_TOKEN=your_actual_token_here ./scripts/build-images.sh --push
```

This option doesn't persist the token and must be specified each time.

### Option 5: Kubernetes Secret (For Cluster Builds)

For automated builds in Kubernetes, use a Kubernetes Secret.

A template is provided at `k8s/secrets/github-token-secret-template.yml`:

```bash
# 1. Copy and fill in the template
cp k8s/secrets/github-token-secret-template.yml k8s/secrets/github-token-secret.yml
editor k8s/secrets/github-token-secret.yml  # Replace REPLACE_WITH_GITHUB_TOKEN

# 2. Create a SealedSecret (recommended for production)
kubeseal --format yaml < k8s/secrets/github-token-secret.yml > k8s/secrets/github-token-sealedsecret.yml

# 3. Apply to cluster
kubectl apply -f k8s/secrets/github-token-sealedsecret.yml

# 4. Clean up the plain secret (DO NOT COMMIT)
rm k8s/secrets/github-token-secret.yml
```

For Kaniko builds, create the docker-registry secret format:

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

Then reference in your Pod/Deployment:

```yaml
spec:
  containers:
  - name: builder
    env:
    - name: GITHUB_TOKEN
      valueFrom:
        secretKeyRef:
          name: github-token
          key: GITHUB_TOKEN
```

**Note**: For production use, SealedSecrets are recommended. The template file `k8s/secrets/github-token-secret-template.yml` contains both the Opaque secret format and the docker-registry format needed for Kaniko.

## Verification

Verify your token is configured correctly:

```bash
# Check if environment variable is set
echo $GITHUB_TOKEN

# Test authentication (requires docker or podman)
echo "$GITHUB_TOKEN" | docker login ghcr.io --username github --password-stdin
```

## Usage

Once configured, build and push images:

```bash
# Build and push to ghcr.io
./scripts/build-images.sh --push

# Build with specific tag
./scripts/build-images.sh --push --tag v1.0.0

# Dry run (build only, don't push)
./scripts/build-images.sh --dry-run
```

## Security Considerations

- **Never commit** `.envrc` or any file containing real tokens
- `.envrc` is already in `.gitignore`
- The `.envrc.template` file is safe to commit
- Rotate tokens periodically via https://github.com/settings/tokens
- Use the minimum required scopes (write:packages, read:packages)
- For CI/CD, use GitHub Actions secrets or encrypted secrets

## Troubleshooting

### Authentication Failed

```
Error: authentication failed
```

**Solutions**:
- Verify token has `write:packages` scope
- Check token hasn't expired
- Ensure `GITHUB_TOKEN` environment variable is set: `echo $GITHUB_TOKEN`
- Verify registry URL is `ghcr.io`

### Permission Denied

```
Error: denied: permission_denied
```

**Solutions**:
- Verify you're a member of the `ardenone` organization
- Check token has `write:packages` scope for the correct organization
- Ensure you're pushing to the correct registry path: `ghcr.io/ardenone/*`

### Token Not Found

```
Error: GITHUB_TOKEN environment variable not set
```

**Solutions**:
- For direnv: Run `direnv allow` in project directory
- For shell profile: Restart your shell or run `source ~/.bashrc`
- Verify token is set: `echo $GITHUB_TOKEN`

## Related Documentation

- [Container Build Guide](./CONTAINER_BUILD_GUIDE.md)
- [External Build Summary](./EXTERNAL_BUILD_SUMMARY.md)
- [GitHub Actions Workflow](../.github/workflows/build-images.yml)
- [Secrets README](../k8s/secrets/README.md) - Information on all Moltbook secrets
- [GitHub Token Secret Template](../k8s/secrets/github-token-secret-template.yml) - Kubernetes secret template
