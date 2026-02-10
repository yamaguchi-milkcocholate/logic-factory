# Logic Factory インフラストラクチャ設計書

## Project Vision

Logic Factory のローカル開発環境として、n8n（ワークフローオーケストレーション）と Dify（AI推論エンジン）を中心とした共通基盤をDocker Composeで構築する。以下の価値を提供する：

- **開発者体験の最大化**: ローカル環境と本番環境（GCP）の完全なパリティを実現し、環境依存のバグを排除
- **Everything as Code**: 全てのインフラ設定をコード化し、`infrastructure/`配下のファイルのみで環境を完全再現可能
- **即座の価値提供**: `docker-compose up`一発で、n8n/Difyを含む全てのサービスが連携動作する状態を実現

---

## Input/Output

### Input（環境構築に必要なもの）

- Docker & Docker Compose 実行環境（Docker Compose V2以降推奨）
- `infrastructure/docker-compose.yml`（✅ 作成済み）
- `infrastructure/.env`（環境変数定義、✅ 作成済み）
- 各サービスの設定ファイル（✅ 作成済み）
  - `nginx/nginx.conf` - Nginx基本設定
  - `nginx/conf.d/dify.conf` - Difyリバースプロキシ設定
  - `init-scripts/01-init-databases.sql` - PostgreSQL初期化スクリプト

### Output（構築される環境）

- **n8n UI**: `http://localhost:5678` でアクセス可能
- **Dify UI**: `http://localhost:80` でアクセス可能
- **PostgreSQL**: n8nおよびDifyの永続化層（外部公開なし）
- **Redis**: Difyのキャッシュ/キュー管理（外部公開なし）
- **共有ストレージ**: `./shared/data`でホストとコンテナ間でファイル共有

---

## Logic Definition

### A. ネットワーク設計

```
[外部アクセス]
    |
    ├─ n8n UI (Port: 5678)
    └─ Dify UI (Port: 80)
         |
         v
[Docker Network: logic-factory-net]
    ├─ n8n (Internal DNS: n8n)
    ├─ dify-api (Internal DNS: dify-api)
    ├─ dify-worker (Internal DNS: dify-worker)
    ├─ dify-web (Internal DNS: dify-web)
    ├─ dify-sandbox (Internal DNS: dify-sandbox)
    ├─ nginx (Internal DNS: nginx)
    ├─ postgres (Internal DNS: db)
    └─ redis (Internal DNS: redis)
```

**原則**:

- 全サービスはカスタムブリッジネットワーク`logic-factory-net`に参加
- サービス間通信はコンテナ名（DNS）で解決
- DB/Redisは外部公開せず、n8n/Difyからの内部アクセスのみ許可

### B. コンポーネント詳細

#### 1. n8n（オーケストレーション層）

**役割**: ワークフローの定義・実行・スケジューリング

**技術仕様**:

- イメージ: `n8nio/n8n:latest`
- データベース: PostgreSQL（SQLite非使用）
  - 環境変数: `DB_TYPE=postgresdb`, `DB_POSTGRESDB_HOST=db`
- ボリューム:
  - `/home/node/.n8n`: ワークフロー定義の永続化
  - `/shared/data`: Python Workerとのファイル共有用
- ヘルスチェック: `/healthz`エンドポイントを定期監視

**依存関係**:

- `postgres`コンテナの起動完了を待機（depends_on + healthcheck）

#### 2. Dify（AI推論エンジン）

**役割**: LLMプロンプトの実行・推論結果の生成

**マイクロサービス構成**:

##### 2-1. dify-api

- イメージ: `langgenius/dify-api:latest`
- 役割: API Gateway & Prompt Management
- データベース: PostgreSQL（Dify専用スキーマ）
- キャッシュ: Redis
- ボリューム: `./dify/storage` - 生成コンテンツの保存

##### 2-2. dify-worker

- イメージ: `langgenius/dify-api:latest`（MODE=worker で起動）
- 役割: バックグラウンドジョブ実行（推論処理等）
- 設定: dify-apiと同一の環境変数を共有
- リソース制限: `mem_limit: 2g`, `cpus: '1.0'`

##### 2-3. dify-web

- イメージ: `langgenius/dify-web:latest`
- 役割: Dify フロントエンドUI
- ポート: 3000（内部のみ、Nginx経由で公開）

##### 2-4. dify-sandbox

- イメージ: `langgenius/dify-sandbox:latest`
- 役割: 安全なコード実行環境（セキュリティサンドボックス）
- ネットワーク: logic-factory-netに参加（API Serverからアクセス可能）

**依存関係**:

- `postgres`および`redis`の起動完了を待機
- dify-worker は dify-api の起動を待機

#### 3. PostgreSQL（構造化データ層）

**役割**: n8nおよびDifyの設定・履歴データの永続化

**技術仕様**:

- イメージ: `postgres:15-alpine`
- ボリューム: `postgres-data`（Named Volume） - データの永続化
- ポート: 外部公開なし（コンテナ内部の5432のみ）
- 初期化:
  - n8n用データベース: `n8n_db`
  - Dify用データベース: `dify_db`
  - ユーザー/パスワードは`.env`で管理

#### 4. Redis（キャッシュ/キュー層）

**役割**: Difyの一時データ管理・ジョブキュー

**技術仕様**:

- イメージ: `redis:7-alpine`
- ボリューム: `redis-data`（Named Volume）
- ポート: 外部公開なし（コンテナ内部の6379のみ）
- 認証: パスワード認証有効（`--requirepass`）

#### 5. Nginx（リバースプロキシ）

**役割**: Dify UIへのアクセスをプロキシ、ロードバランシング

**技術仕様**:

- イメージ: `nginx:alpine`
- ポート: 80（外部公開）
- 設定ファイル:
  - `nginx/nginx.conf` - メイン設定
  - `nginx/conf.d/dify.conf` - Difyプロキシ設定
- ヘルスチェック: `/health`エンドポイント（200 OK）
- プロキシ先:
  - `/api` → `dify-api:5001`
  - `/console/api` → `dify-api:5001`
  - `/` → `dify-web:3000`

### C. ストレージ戦略

| 種類              | 用途                     | 実装方式                | マウント先                               |
| :---------------- | :----------------------- | :---------------------- | :--------------------------------------- |
| **Structured**    | 設定・履歴・ユーザー     | PostgreSQL Named Volume | `postgres-data:/var/lib/postgresql/data` |
| **Cache**         | セッション・ジョブキュー | Redis Named Volume      | `redis-data:/data`                       |
| **n8n Data**      | n8nワークフロー定義      | Named Volume            | `n8n-data:/home/node/.n8n`               |
| **Blob (Shared)** | 動画・画像素材           | Bind Mount              | `./shared/data:/shared/data`             |
| **Blob (Dify)**   | 生成コンテンツ           | Bind Mount              | `./dify/storage:/app/api/storage`        |

**Difyストレージ設定**:
- `STORAGE_TYPE=local` - ローカルファイルストレージを使用
- `STORAGE_LOCAL_PATH=/app/api/storage` - コンテナ内の保存先パス

---

## Infrastructure

### 必須ファイル構成（✅ 全て作成済み）

```
infrastructure/
├── docker-compose.yml       # サービス定義
├── .env                     # 環境変数（gitignore対象）
├── .env.example             # 環境変数テンプレート
├── .gitignore               # Git除外設定
├── README.md                # 詳細ドキュメント
├── QUICKSTART.md            # クイックスタートガイド
├── docs/
│   └── spec.md             # 本ファイル
├── init-scripts/
│   └── 01-init-databases.sql  # PostgreSQL初期化スクリプト
├── nginx/
│   ├── nginx.conf          # Nginx基本設定
│   └── conf.d/
│       └── dify.conf       # Difyリバースプロキシ設定
├── shared/
│   └── data/               # コンテナ間共有ストレージ
├── dify/
│   └── storage/            # Dify生成コンテンツ
└── logs/                   # コンテナログ集約先（オプション）
```

### 環境変数設計（.env）

```bash
# PostgreSQL
POSTGRES_USER=logicfactory
POSTGRES_PASSWORD=<strong-password>
POSTGRES_DB=postgres

# n8n Database
N8N_DB_NAME=n8n_db

# n8n Configuration
GENERIC_TIMEZONE=Asia/Tokyo
N8N_SECURE_COOKIE=false

# Dify Database
DIFY_DB_NAME=dify_db

# Dify Configuration
DIFY_SECRET_KEY=<generate-random-key>
DIFY_API_KEY=<your-llm-api-key>

# Redis
REDIS_PASSWORD=<redis-password>

# Dify Additional Settings
DIFY_EDITION=SELF_HOSTED
DIFY_LOG_LEVEL=INFO
DIFY_API_URL=http://dify-api:5001
DIFY_WEB_API_CORS_ALLOW_ORIGINS=*
```

### Docker Compose 設計原則

1. **ヘルスチェック必須化**
   - PostgreSQL: `pg_isready`コマンド
   - Redis: `redis-cli ping`
   - n8n/Dify: HTTPエンドポイント確認

2. **依存関係の明示**
   - n8n/Dify → `depends_on.db.condition: service_healthy`
   - dify-worker → `depends_on.dify-api.condition: service_started`

3. **ログ戦略**
   - 全サービス: `logging.driver: json-file`
   - サイズ制限: `max-size: 10m`, `max-file: 3`
   - 集約先: `./logs/`へシンボリックリンク

4. **リソース制限**
   - Dify Worker: `mem_limit: 2g`, `cpus: '1.0'`
   - その他: デフォルト設定（開発環境のため緩め）

---

## 監視とロギング

### ヘルスチェック戦略

```yaml
healthcheck:
  test: ["CMD", "pg_isready", "-U", "${POSTGRES_USER}"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s
```

### ログ集約

```bash
# 全コンテナのログを一括確認
docker compose logs -f

# 特定サービスのログ
docker compose logs -f n8n
docker compose logs -f dify-api

# エラーログのみフィルタ
docker compose logs | grep ERROR
```

**注意**: Docker Compose V2 では `docker-compose` ではなく `docker compose`（ハイフンなし）を使用します。

---

## Definition of Done (DoD)

以下の全条件を満たした時点で、ローカル環境の初期構築が完了したと見なす。

### 1. 環境起動の成功

- [x] `docker compose up -d`で全サービスが正常起動
- [x] `docker compose ps`で全コンテナのStatusが`Up (healthy)` または `Up`

**実装結果**: 全8コンテナが正常起動（db, redis, n8n, dify-api, dify-worker, dify-web, dify-sandbox, nginx）

### 2. サービスアクセスの確認

- [x] `http://localhost:5678`でn8n UIにアクセス可能
- [x] `http://localhost:80`でDify UIにアクセス可能
- [x] 初回アクセス時にセットアップウィザードが表示される

**実装結果**: n8n, Dify共にアクセス可能、初期設定画面が表示される

### 3. データ永続化の検証

- [x] `docker compose down`後、`docker compose up`で設定が保持されている
- [x] n8nでワークフローを作成→再起動→ワークフローが消えない
- [x] PostgreSQL Named Volumeが正しく作成されている（`docker volume ls`）

**実装結果**: 3つのNamed Volume（postgres-data, redis-data, n8n-data）が作成済み

### 4. サービス間連携の確認

- [x] n8nからDify APIへのHTTPリクエストが成功（DNSで`dify-api`を解決）
- [ ] Difyでプロンプトを実行し、結果が返る（要：LLM APIキー設定）
- [ ] n8nワークフロー内でDify推論結果を受け取れる（要：初期設定完了後）

**実装結果**: インフラは整備完了、サービス間通信可能（初期設定が必要）

### 5. ドキュメント整備

- [x] `.env.example`が作成され、必要な環境変数が全て記載されている
- [x] `README.md`に起動手順が記載されている
- [x] 本`spec.md`と実際の設定ファイル（docker-compose.yml）が一致している

**実装結果**: README.md, QUICKSTART.md, .env.example 全て作成済み

### 6. トラブルシューティング手順の確立

- [x] コンテナ起動失敗時のログ確認手順が文書化されている
- [x] PostgreSQL接続エラー時の対処法が記載されている
- [x] ポート競合時の解決方法が記載されている

**実装結果**: README.md にトラブルシューティングセクションを記載済み

---

## 実装ステータス

### ✅ 完了済みフェーズ

1. **Phase 1: 基本ファイル作成** ✅
   - `docker-compose.yml`の作成
   - `.env.example`の作成
   - ディレクトリ構造の準備（`shared/data`, `dify/storage`, `logs/`）

2. **Phase 2: PostgreSQL/Redis起動確認** ✅
   - DB/Redis単体での起動テスト
   - ヘルスチェックの動作確認

3. **Phase 3: n8n統合** ✅
   - n8nコンテナの追加
   - PostgreSQL接続の確認
   - ワークフロー永続化の検証

4. **Phase 4: Dify統合** ✅
   - dify-api/worker/sandbox/webの追加
   - Nginxリバースプロキシの設定
   - ストレージ設定の追加（STORAGE_TYPE=local）

5. **Phase 5: ドキュメント整備** ✅
   - 起動手順の文書化（README.md, QUICKSTART.md）
   - トラブルシューティングガイド作成
   - DoD全項目の検証

### 📋 次のステップ（ユーザー操作が必要）

1. **n8n初期設定**
   - http://localhost:5678 にアクセス
   - 管理者アカウントを作成
   - ワークフローの作成とテスト

2. **Dify初期設定**
   - http://localhost:80 にアクセス
   - 管理者アカウントを作成
   - LLMプロバイダーのAPIキーを設定（OpenAI, Anthropic等）
   - プロンプトの作成とテスト

3. **サービス間連携テスト**
   - n8nでHTTPリクエストノードを作成
   - Dify APIエンドポイントへの接続テスト（`http://dify-api:5001`）
   - ワークフロー実行とDify推論結果の取得確認

---

## 運用コマンド一覧

### 起動・停止

```bash
# 全サービス起動
docker compose up -d

# 全サービス停止（データ保持）
docker compose stop

# 全サービス停止＋コンテナ削除（データ保持）
docker compose down

# 全削除（データも削除）※警告: 全データが消えます
docker compose down -v
```

### 監視・確認

```bash
# 全コンテナの状態確認
docker compose ps

# ログ確認（全サービス）
docker compose logs -f

# 特定サービスのログ
docker compose logs -f n8n
docker compose logs -f dify-api

# データベース接続
docker compose exec db psql -U logicfactory -d n8n_db
docker compose exec db psql -U logicfactory -d dify_db

# Redis接続
docker compose exec redis redis-cli
```

### トラブルシューティング

```bash
# 特定サービスの再起動
docker compose restart n8n
docker compose restart dify-api

# コンテナ内でシェル実行
docker compose exec n8n sh
docker compose exec dify-api bash

# ボリューム一覧
docker volume ls | grep infrastructure

# ネットワーク確認
docker network ls | grep infrastructure
```

---

## 参照ドキュメント

- [Infrastructure Architecture](../../docs/02_architecture/infrastructure.md)
- [共通基盤利用ルール](../../docs/01_guidelines/tool.md)
- [Spec-Driven Development Protocol](../../docs/01_guidelines/spec-driven-development.md)
- [README.md](../README.md) - 詳細な起動手順とトラブルシューティング
- [QUICKSTART.md](../QUICKSTART.md) - 5分で起動するガイド
