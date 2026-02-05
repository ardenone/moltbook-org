# Moltbook Secrets

This directory contains SealedSecrets for the Moltbook platform deployment.

## SealedSecrets (GitOps Compatible)

The following SealedSecrets have been generated and can be safely committed to Git:

### Existing SealedSecrets
- `moltbook-api-sealedsecret.yml` - API secrets (DATABASE_URL, JWT_SECRET, OAuth credentials)
- `postgres-superuser-sealedsecret.yml` - PostgreSQL superuser credentials
- `db-credentials-sealedsecret.yml` - Database application user credentials

These secrets were generated using the sealed-secrets controller and can be safely committed to version control.

## Regenerating SealedSecrets

If you need to regenerate secrets (e.g., rotation):

### Prerequisites
- `kubeseal` CLI installed
- Access to the cluster with sealed-secrets controller

### Steps

1. Copy the template files and fill in real values:
```bash
cp moltbook-api-secrets-template.yml moltbook-api-secrets.yml
cp moltbook-db-credentials-template.yml moltbook-db-credentials.yml
cp postgres-superuser-secret-template.yml postgres-superuser-secret.yml
```

Note: You can also use `db-connection-secret-template.yml` if you prefer a separate connection string secret.

2. Generate strong passwords and secrets:
```bash
# Generate JWT secret (32 bytes, base64 encoded)
JWT_SECRET=$(openssl rand -base64 32)
echo "JWT_SECRET: $JWT_SECRET"

# Generate database password (24 bytes, base64 encoded)
DB_PASSWORD=$(openssl rand -base64 24)
echo "DB_PASSWORD: $DB_PASSWORD"

# Generate PostgreSQL superuser password
POSTGRES_PASSWORD=$(openssl rand -base64 24)
echo "POSTGRES_PASSWORD: $POSTGRES_PASSWORD"
```

3. Edit the files and replace REPLACE_ME placeholders with the generated values

4. Create SealedSecrets:
```bash
# Seal the API secrets
kubeseal --format yaml < moltbook-api-secrets.yml > moltbook-api-sealedsecret.yml

# Seal the database credentials
kubeseal --format yaml < moltbook-db-credentials.yml > moltbook-db-credentials-sealedsecret.yml

# Seal the postgres superuser secret
kubeseal --format yaml < postgres-superuser-secret.yml > postgres-superuser-sealedsecret.yml
```

5. Apply the SealedSecrets to the cluster:
```bash
kubectl apply -f moltbook-api-sealedsecret.yml
kubectl apply -f moltbook-db-credentials-sealedsecret.yml
kubectl apply -f postgres-superuser-sealedsecret.yml
```

6. Clean up the plain secret files (DO NOT COMMIT):
```bash
rm moltbook-api-secrets.yml
rm moltbook-db-credentials.yml
rm postgres-superuser-secret.yml
```

## Required Secrets

### moltbook-api-secrets
- `DATABASE_URL`: PostgreSQL connection string (format: postgresql://user:pass@host:port/db)
- `JWT_SECRET`: JWT signing key for API authentication (generate with `openssl rand -base64 32`)
- `TWITTER_CLIENT_ID`: (Optional) Twitter OAuth client ID
- `TWITTER_CLIENT_SECRET`: (Optional) Twitter OAuth secret

### moltbook-db-credentials
- `username`: PostgreSQL application user (default: moltbook)
- `password`: PostgreSQL application password

### moltbook-postgres-superuser
- `username`: PostgreSQL superuser (default: postgres)
- `password`: PostgreSQL superuser password

### github-token (Container Registry Authentication)
- `GITHUB_TOKEN`: GitHub Personal Access Token for ghcr.io authentication
  - Create at: https://github.com/settings/tokens
  - Required scopes: `write:packages`, `read:packages`, `delete:packages`
  - Used by: `build-images.sh` script for pushing images
- `GITHUB_USERNAME`: GitHub username (default: `ardenone`)

**Note**: The `github-token-secret-template.yml` template is provided for creating this secret as a SealedSecret.

## Security Notes

- NEVER commit files without `-template.yml` suffix
- Add `*-secret.yml` (without template suffix) to `.gitignore`
- Use strong, randomly generated passwords
- Rotate secrets regularly
- Use separate secrets for different environments
