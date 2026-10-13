#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="$repo_root/.env.server"

if [[ -e "$env_file" ]]; then
  echo "Refusing to overwrite .env.server. Keep its existing secrets safe."
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "OpenSSL is required. Install it with: apt install -y openssl"
  exit 1
fi

mysql_root_password="$(openssl rand -hex 32)"
mysql_password="$(openssl rand -hex 32)"
customer_auth_secret="$(openssl rand -hex 32)"

umask 077
cat > "$env_file" <<EOF
NODE_ENV=production
PORT=4000
WEB_ORIGINS=https://panizstyle.ir,https://www.panizstyle.ir
PUBLIC_WEB_URL=https://panizstyle.ir
PUBLIC_API_URL=https://api.panizstyle.ir
DATABASE_CONNECTION_LIMIT=5
DATABASE_URL=mysql://panizstyle_app:${mysql_password}@mysql:3306/panizstyle
CUSTOMER_AUTH_SECRET=${customer_auth_secret}
UPLOADS_DIR=/data/uploads
BACKUP_DIR=/data/backups
BACKUP_RETENTION_COUNT=7
BACKUP_SCHEDULE_ENABLED=true
MYSQL_DATABASE=panizstyle
MYSQL_USER=panizstyle_app
MYSQL_ROOT_PASSWORD=${mysql_root_password}
MYSQL_PASSWORD=${mysql_password}
NEXT_PUBLIC_API_BASE_URL=https://api.panizstyle.ir/api/v1
NEXT_PUBLIC_SITE_URL=https://panizstyle.ir
SMS_PROVIDER=
SMS_CAMPAIGNS_ENABLED=false
RUBIKA_BOT_TOKEN=
RUBIKA_CHANNEL_ID=
RUBIKA_CHANNEL_URL=
RUBIKA_BOT_API_BASE_URL=https://botapi.rubika.ir/v3
RUBIKA_SEND_DELAY_MS=150
INSTAGRAM_USER_ID=
INSTAGRAM_ACCESS_TOKEN=
INSTAGRAM_GRAPH_API_VERSION=
EOF
chmod 600 "$env_file"

echo "Created .env.server with generated database and application secrets (permissions 600)."
echo "Do not print this file or add it to Git. Add SMS.ir and Rubika credentials to it later if needed."
