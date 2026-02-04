# Moltbook Secrets

This directory contains secret templates for the Moltbook platform.

## Creating Sealed Secrets

### Prerequisites
- `kubeseal` CLI installed
- Access to the cluster with sealed-secrets controller

### Steps

1. Copy the template files and fill in real values:
```bash
cp moltbook-secrets-template.yml moltbook-secrets.yml
cp postgres-superuser-secret-template.yml postgres-superuser-secret.yml
```

2. Edit the files and replace placeholder values:
```bash
# Generate JWT secret
openssl rand -base64 32

# Generate database passwords
openssl rand -base64 24
```

3. Create SealedSecrets:
```bash
# Seal the moltbook app secrets
kubeseal --format yaml < moltbook-secrets.yml > moltbook-sealedsecret.yml

# Seal the postgres superuser secret
kubeseal --format yaml < postgres-superuser-secret.yml > postgres-superuser-sealedsecret.yml
```

4. Apply the SealedSecrets to the cluster:
```bash
kubectl apply -f moltbook-sealedsecret.yml
kubectl apply -f postgres-superuser-sealedsecret.yml
```

5. Clean up the plain secret files (DO NOT COMMIT):
```bash
rm moltbook-secrets.yml
rm postgres-superuser-secret.yml
```

## Required Secrets

### moltbook-secrets
- `JWT_SECRET`: JWT signing key for API authentication
- `DATABASE_USER`: PostgreSQL application user
- `DATABASE_PASSWORD`: PostgreSQL application password
- `DATABASE_NAME`: Database name (default: moltbook)
- `TWITTER_CLIENT_ID`: (Optional) Twitter OAuth client ID
- `TWITTER_CLIENT_SECRET`: (Optional) Twitter OAuth secret

### moltbook-postgres-superuser
- `username`: PostgreSQL superuser (default: postgres)
- `password`: PostgreSQL superuser password

## Security Notes

- NEVER commit files without `-template.yml` suffix
- Add `*-secret.yml` (without template suffix) to `.gitignore`
- Use strong, randomly generated passwords
- Rotate secrets regularly
- Use separate secrets for different environments
