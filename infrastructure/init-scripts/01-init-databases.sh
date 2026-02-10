#!/bin/bash
# Logic Factory - Database Initialization Script
# このスクリプトは冪等です（何度実行しても安全）

set -e

echo "🔧 n8n用データベースの初期化を開始..."

# データベースが存在しない場合のみ作成
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	SELECT 'CREATE DATABASE n8n_db'
	WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'n8n_db')\gexec
EOSQL

# 権限付与（データベースが既に存在する場合でも安全）
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	GRANT ALL PRIVILEGES ON DATABASE n8n_db TO logicfactory;
EOSQL

echo "✅ n8n_db データベースの初期化完了"
echo ""
echo "注意: Difyは独自のPostgreSQLコンテナ(db_postgres)を使用するため、"
echo "      このスクリプトではDify用データベースは作成しません"
