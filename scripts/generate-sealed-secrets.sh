#!/bin/bash
set -e

# Moltbook SealedSecrets Generation Script
# This script generates secure secrets and creates SealedSecrets for the Moltbook platform

NAMESPACE="moltbook"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$PROJECT_DIR/k8s/secrets"

echo "🔐 Moltbook SealedSecrets Generator"
echo "===================================="
echo ""

# Check if kubeseal is installed
if ! command -v kubeseal &> /dev/null; then
    echo "❌ Error: kubeseal is not installed"
    echo "Please install kubeseal: https://github.com/bitnami-labs/sealed-secrets"
    exit 1
fi

# Check if kubectl can connect to cluster
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "❌ Error: Cannot connect to cluster or namespace $NAMESPACE does not exist"
    echo "Please create the namespace first: kubectl apply -f k8s/namespace/moltbook-namespace.yml"
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Generate secure random values
echo "🎲 Generating secure random values..."
JWT_SECRET=$(openssl rand -base64 32)
POSTGRES_PASSWORD=$(openssl rand -base64 24)
DATABASE_PASSWORD=$(openssl rand -base64 24)

echo "✅ Random values generated"
echo ""

# Create PostgreSQL Superuser Secret
echo "📝 Creating PostgreSQL Superuser Secret..."
cat > "$SECRETS_DIR/postgres-superuser.yml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: moltbook-postgres-superuser
  namespace: $NAMESPACE
type: kubernetes.io/basic-auth
stringData:
  username: postgres
  password: "$POSTGRES_PASSWORD"
EOF

kubeseal --format yaml < "$SECRETS_DIR/postgres-superuser.yml" > "$SECRETS_DIR/postgres-superuser-sealedsecret.yml"
rm "$SECRETS_DIR/postgres-superuser.yml"
echo "✅ PostgreSQL Superuser SealedSecret created: postgres-superuser-sealedsecret.yml"

# Create Moltbook App Secrets
echo "📝 Creating Moltbook App Secrets..."
cat > "$SECRETS_DIR/moltbook-secrets.yml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: moltbook-secrets
  namespace: $NAMESPACE
type: Opaque
stringData:
  JWT_SECRET: "$JWT_SECRET"
  DATABASE_USER: "moltbook"
  DATABASE_PASSWORD: "$DATABASE_PASSWORD"
  DATABASE_NAME: "moltbook"
  REDIS_URL: "redis://moltbook-redis:6379"
  TWITTER_CLIENT_ID: ""
  TWITTER_CLIENT_SECRET: ""
EOF

kubeseal --format yaml < "$SECRETS_DIR/moltbook-secrets.yml" > "$SECRETS_DIR/moltbook-secrets-sealedsecret.yml"
rm "$SECRETS_DIR/moltbook-secrets.yml"
echo "✅ Moltbook App SealedSecret created: moltbook-secrets-sealedsecret.yml"

# Create Database Connection Secret
echo "📝 Creating Database Connection Secret..."
cat > "$SECRETS_DIR/db-connection.yml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: moltbook-db-connection
  namespace: $NAMESPACE
type: Opaque
stringData:
  DATABASE_URL: "postgresql://moltbook:$DATABASE_PASSWORD@moltbook-postgres-rw.moltbook.svc.cluster.local:5432/moltbook?sslmode=require"
EOF

kubeseal --format yaml < "$SECRETS_DIR/db-connection.yml" > "$SECRETS_DIR/db-connection-sealedsecret.yml"
rm "$SECRETS_DIR/db-connection.yml"
echo "✅ Database Connection SealedSecret created: db-connection-sealedsecret.yml"

echo ""
echo "✨ All SealedSecrets generated successfully!"
echo ""
echo "📁 Generated files:"
echo "   - $SECRETS_DIR/postgres-superuser-sealedsecret.yml"
echo "   - $SECRETS_DIR/moltbook-secrets-sealedsecret.yml"
echo "   - $SECRETS_DIR/db-connection-sealedsecret.yml"
echo ""
echo "🚀 Next steps:"
echo "   1. Review the generated SealedSecret files"
echo "   2. Commit them to Git (they are safe to commit)"
echo "   3. Apply to cluster: kubectl apply -f $SECRETS_DIR/*-sealedsecret.yml"
echo ""
echo "⚠️  IMPORTANT: Save these secret values in a secure password manager!"
echo "   JWT_SECRET: $JWT_SECRET"
echo "   POSTGRES_PASSWORD: $POSTGRES_PASSWORD"
echo "   DATABASE_PASSWORD: $DATABASE_PASSWORD"
