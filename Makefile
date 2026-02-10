.PHONY: help infra-up infra-down infra-restart infra-ps infra-logs infra-logs-n8n infra-logs-dify infra-clean infra-clean-all infra-db infra-db-init infra-db-reset infra-redis infra-health infra-setup

# Docker Compose ファイルのパス
COMPOSE_FILE := infrastructure/docker-compose.yml
# Difyのプロファイルを指定（postgresql, weaviate）
COMPOSE := docker compose -f $(COMPOSE_FILE) --profile weaviate --profile postgresql

# デフォルトターゲット: ヘルプを表示
help:
	@echo "Logic Factory - Infrastructure Management"
	@echo ""
	@echo "=== セットアップ ==="
	@echo "  make infra-setup       : 環境変数ファイルを作成"
	@echo "  make infra-up          : 全サービスを起動（初回はDB自動初期化）"
	@echo ""
	@echo "=== 運用 ==="
	@echo "  make infra-down        : 全サービスを停止（データ保持）"
	@echo "  make infra-restart     : 全サービスを再起動"
	@echo "  make infra-ps          : 全コンテナの状態を表示"
	@echo "  make infra-logs        : 全サービスのログを表示（リアルタイム）"
	@echo "  make infra-logs-n8n    : n8nのログを表示"
	@echo "  make infra-logs-dify   : Dify関連のログを表示"
	@echo "  make infra-health      : ヘルスチェック実行"
	@echo ""
	@echo "=== データベース ==="
	@echo "  make infra-db          : PostgreSQLに接続"
	@echo "  make infra-db-init     : n8n用DBを手動初期化（通常不要）"
	@echo "  make infra-db-reset    : n8n用DBを完全リセット※警告"
	@echo "  make infra-redis       : Redisに接続"
	@echo ""
	@echo "=== クリーンアップ ==="
	@echo "  make infra-clean       : コンテナ停止＋削除（データ保持）"
	@echo "  make infra-clean-all   : 全削除（データも削除）※警告"
	@echo ""

# 全サービス起動
# 注意: 初回起動時、PostgreSQLコンテナが以下を自動実行します:
#   1. postgres-dataボリュームの初期化
#   2. init-scripts/01-init-databases.sh の実行（n8n_db作成）
# 2回目以降は既存のボリュームを使用するため、初期化スクリプトは実行されません
infra-up:
	@echo "🚀 Logic Factory インフラを起動中..."
	$(COMPOSE) up -d
	@echo "✅ 起動完了"
	@echo "   - n8n: http://localhost:5678"
	@echo "   - Dify: http://localhost:80"
	@echo ""
	@echo "💡 初回起動の場合、n8n用データベース(n8n_db)が自動作成されます"

# 全サービス停止
infra-down:
	@echo "⏸️  Logic Factory インフラを停止中..."
	$(COMPOSE) stop
	@echo "✅ 停止完了（データは保持されています）"

# 全サービス再起動
infra-restart:
	@echo "🔄 Logic Factory インフラを再起動中..."
	$(COMPOSE) restart
	@echo "✅ 再起動完了"

# コンテナ状態確認
infra-ps:
	@echo "📊 コンテナ状態:"
	@$(COMPOSE) ps

# 全ログ表示（リアルタイム）
infra-logs:
	@echo "📄 全サービスのログを表示中... (Ctrl+C で終了)"
	$(COMPOSE) logs -f

# n8nログ表示
infra-logs-n8n:
	@echo "📄 n8n ログを表示中... (Ctrl+C で終了)"
	$(COMPOSE) logs -f n8n

# Dify関連ログ表示
infra-logs-dify:
	@echo "📄 Dify 関連ログを表示中... (Ctrl+C で終了)"
	$(COMPOSE) logs -f api worker web nginx

# ヘルスチェック
infra-health:
	@echo "🏥 ヘルスチェック実行中..."
	@echo ""
	@echo "n8n:"
	@curl -s http://localhost:5678/healthz && echo " ✅ OK" || echo " ❌ NG"
	@echo ""
	@echo "Dify:"
	@curl -s http://localhost/health && echo " ✅ OK" || echo " ❌ NG"
	@echo ""
	@echo "PostgreSQL:"
	@$(COMPOSE) exec -T db pg_isready -U logicfactory && echo " ✅ OK" || echo " ❌ NG"
	@echo ""
	@echo "Redis (Dify):"
	@$(COMPOSE) exec -T redis redis-cli ping && echo " ✅ OK" || echo " ❌ NG"

# PostgreSQL接続
infra-db:
	@echo "🗄️  PostgreSQL に接続中..."
	@echo "データベース一覧: \l"
	@echo "終了: \q"
	$(COMPOSE) exec db psql -U logicfactory

# n8n用DB手動初期化（通常は不要 - 初回起動時に自動実行される）
infra-db-init:
	@echo "🔧 n8n用データベースを手動初期化中..."
	@echo "注意: 通常、この操作は不要です（初回起動時に自動実行されます）"
	$(COMPOSE) exec db bash -c "cd /docker-entrypoint-initdb.d && ./01-init-databases.sh"
	@echo "✅ 初期化完了"

# n8n用DBリセット（データ削除）
infra-db-reset:
	@echo "⚠️  警告: n8n_dbデータベースを完全削除します"
	@echo "続行するには Ctrl+C で中断、Enter で続行..."
	@read dummy
	@echo "🗑️  n8n_db を削除中..."
	$(COMPOSE) exec db psql -U logicfactory -c "DROP DATABASE IF EXISTS n8n_db;"
	@echo "🔧 n8n_db を再作成中..."
	$(COMPOSE) exec db bash -c "cd /docker-entrypoint-initdb.d && ./01-init-databases.sh"
	@echo "✅ リセット完成"

# Redis接続
infra-redis:
	@echo "💾 Redis に接続中..."
	@echo "終了: exit"
	$(COMPOSE) exec redis redis-cli

# クリーン（データ保持）
infra-clean:
	@echo "🧹 コンテナを停止・削除中（データは保持）..."
	$(COMPOSE) down
	@echo "✅ クリーンアップ完了"

# 全削除（データも削除）
infra-clean-all:
	@echo "⚠️  警告: 全データが削除されます"
	@echo "続行するには Ctrl+C で中断、Enter で続行..."
	@read dummy
	@echo "🗑️  全データを削除中..."
	$(COMPOSE) down -v
	@echo "✅ 全削除完了"

# 特定サービスの再起動
infra-restart-n8n:
	@echo "🔄 n8n を再起動中..."
	$(COMPOSE) restart n8n

infra-restart-dify-api:
	@echo "🔄 Dify API を再起動中..."
	$(COMPOSE) restart api

infra-restart-dify-worker:
	@echo "🔄 Dify Worker を再起動中..."
	$(COMPOSE) restart worker

# 環境変数ファイルのコピー
infra-setup:
	@echo "📝 環境変数ファイルを設定中..."
	@if [ ! -f infrastructure/.env ]; then \
		cp infrastructure/.env.example infrastructure/.env; \
		echo "✅ infrastructure/.env を作成しました"; \
	else \
		echo "ℹ️  infrastructure/.env は既に存在します"; \
	fi
	@if [ ! -f infrastructure/dify/.env ]; then \
		cp infrastructure/dify/.env.example infrastructure/dify/.env; \
		echo "✅ infrastructure/dify/.env を作成しました"; \
	else \
		echo "ℹ️  infrastructure/dify/.env は既に存在します"; \
	fi
	@echo "⚠️  .env ファイルを編集してパスワードとAPIキーを設定してください"
