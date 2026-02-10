# Logic Factory インフラストラクチャ設計書（v2.0）

> **Architecture Decision**: 本設計は [ADR-001: Dify と n8n の統合戦略](../../docs/02_architecture/adr/001-dify-n8n-integration-strategy.md) に基づいています。

## Project Vision

Logic Factory のローカル開発環境として、n8n（ワークフローオーケストレーション）と Dify（AI推論エンジン）を中心とした共通基盤をDocker Composeで構築する。以下の価値を提供する：

- **開発者体験の最大化**: ローカル環境と本番環境（GCP）の完全なパリティを実現し、環境依存のバグを排除
- **Everything as Code**: 全てのインフラ設定をコード化し、`infrastructure/`配下のファイルのみで環境を完全再現可能
- **公式構成の尊重**: Difyは公式リポジトリの設定を無改変で利用し、メンテナンス性とアップデート追従性を確保
- **即座の価値提供**: `docker compose up`一発で、n8n/Difyを含む全てのサービスが連携動作する状態を実現

---

## Input/Output

### Input（環境構築に必要なもの）

- Docker & Docker Compose V2以降（`include`機能対応必須）
- Git（Dify公式リポジトリのsparse checkout用）
- `infrastructure/docker-compose.yml`（メインファイル、`include`使用）
- `infrastructure/n8n/compose.yml`（n8n専用設定）
- `infrastructure/dify/docker/`（公式リポジトリからsparse checkout）
- 環境変数ファイル:
  - `infrastructure/.env`（n8n用）
  - `infrastructure/dify/.env`（Dify用）

### Output（構築される環境）

- **n8n UI**: `http://localhost:5678` でアクセス可能
- **Dify UI**: `http://localhost:80` でアクセス可能
- **PostgreSQL**: n8nおよびDifyの永続化層（外部公開なし）
- **Redis**: Difyのキャッシュ/キュー管理（外部公開なし）
- **共有ストレージ**: `./shared/data`でホストとコンテナ間でファイル共有
- **単一ネットワーク**: 全サービスが`logic-factory-net`で連携

---

## Logic Definition

### A. アーキテクチャ概要

#### Docker Compose `include`による統合戦略

```yaml
# infrastructure/docker-compose.yml (メインファイル)
include:
  - path: ./n8n/compose.yml
  - path: ./dify/docker/docker-compose.yaml
    env_file: ./dify/.env

networks:
  logic-factory-net:
    driver: bridge
```

**設計原則**:

- n8nとDifyの設定を別ファイルで管理し、責務を分離
- Difyは公式docker-compose.yamlを無改変で利用
- 単一の`docker compose`コマンドで全サービスを管理
- 全サービスが共有ネットワーク`logic-factory-net`に参加

#### ネットワークトポロジー

```
[外部アクセス]
    |
    ├─ n8n UI (Port: 5678)
    └─ Dify UI (Port: 80) ← Nginx経由
         |
         v
[Docker Network: logic-factory-net]
    ├─ n8n (Internal DNS: n8n)
    ├─ Dify (11サービス):
    │   ├─ api (dify-api)
    │   ├─ worker (dify-worker)
    │   ├─ worker_beat (dify-worker-beat)
    │   ├─ web (dify-web)
    │   ├─ plugin_daemon
    │   ├─ db_postgres
    │   ├─ redis
    │   ├─ nginx
    │   ├─ sandbox
    │   ├─ ssrf_proxy
    │   └─ weaviate（ベクトルDB）
    ├─ db (n8n/共有PostgreSQL)
    └─ redis (n8n用、Difyは独自Redis使用)
```

### B. コンポーネント詳細

#### 1. n8n（オーケストレーション層）

**役割**: ワークフローの定義・実行・スケジューリング

**技術仕様** (`n8n/compose.yml`で定義):

- イメージ: `n8nio/n8n:latest`
- データベース: 共有PostgreSQL（`db`コンテナ）
  - 環境変数: `DB_TYPE=postgresdb`, `DB_POSTGRESDB_HOST=db`
  - データベース名: `n8n_db`
- ボリューム:
  - `n8n-data:/home/node/.n8n` - ワークフロー定義の永続化
  - `./shared/data:/shared/data` - Python Workerとのファイル共有用
- ネットワーク: `logic-factory-net`
- ヘルスチェック: `/healthz`エンドポイントを定期監視

**依存関係**:

- 共有PostgreSQL(`db`)の起動完了を待機

#### 2. Dify（AI推論エンジン）

**役割**: LLMプロンプトの実行・推論結果の生成

**公式構成の利用**:

- **ソース**: [langgenius/dify](https://github.com/langgenius/dify) の`docker/`ディレクトリ
- **取得方法**: Git sparse checkout
- **設定ファイル**: `dify/docker/docker-compose.yaml`（無改変で使用）
- **環境変数**: `dify/.env`

**マイクロサービス構成** (公式定義に準拠):

##### コアサービス（5つ）

1. **api** (`langgenius/dify-api:latest`)
   - REST APIサーバー（Gunicorn）
   - データベース: Dify専用PostgreSQL（`db_postgres`）
   - キャッシュ: Dify専用Redis
   - ストレージ: `./dify/docker/volumes/app/storage`

2. **worker** (`langgenius/dify-api:latest`, MODE=worker)
   - Celeryタスク処理（キューイング）
   - Redis経由でジョブを受信

3. **worker_beat** (`langgenius/dify-api:latest`, MODE=worker_beat)
   - Celeryスケジューラー（定期タスク）

4. **web** (`langgenius/dify-web:latest`)
   - フロントエンド（Next.js）
   - Nginx経由で公開

5. **plugin_daemon** (`langgenius/dify-plugin-daemon`)
   - プラグイン実行環境

##### 依存コンポーネント（6つ）

1. **db_postgres** (`postgres:15-alpine`)
   - Dify固有の設定・プロンプト管理用PostgreSQL

2. **redis** (`redis:7-alpine`)
   - キャッシュおよびキュー管理
   - 認証: パスワード保護

3. **nginx** (`nginx:alpine`)
   - リバースプロキシ&ロードバランサー
   - ポート80で外部公開
   - 設定: `dify/docker/nginx/`

4. **sandbox** (`langgenius/dify-sandbox`)
   - 安全なコード実行サンドボックス

5. **ssrf_proxy** (`ubuntu/squid`)
   - SSRF攻撃対策用プロキシ
   - 設定: `dify/docker/ssrf_proxy/`

6. **weaviate** (`semitechnologies/weaviate`)
   - ベクトルストレージ（他のベクトルDBも選択可能）

**システム要件**:

- 最小: CPU 2コア、RAM 8GB
- Docker VM設定も同様に調整必要

#### 3. 共有PostgreSQL（n8n専用）

**役割**: n8nの設定・履歴データの永続化

**技術仕様** (メインdocker-compose.ymlで定義):

- イメージ: `postgres:15-alpine`
- ボリューム: `postgres-data`（Named Volume）
- ポート: 外部公開なし（コンテナ内部の5432のみ）
- 初期化:
  - n8n用データベース: `n8n_db`
  - 初期化スクリプト: `./init-scripts/01-init-databases.sh`（冪等）
  - 実行タイミング: 初回起動時のみ（ボリュームが空の場合）
  - 2回目以降: 既存データをそのまま使用（スクリプト未実行）
- ネットワーク: `logic-factory-net`

**注意**: Difyは独自のPostgreSQL(`db_postgres`)を使用するため、このコンテナはn8n専用となります。

#### 4. 共有Redis（n8n用、オプション）

**役割**: n8nのキャッシュ/セッション管理（必要に応じて）

**注意**: Difyは独自のRedisを使用します。n8nでRedisが不要な場合、このコンテナは削除可能です。

### C. ストレージ戦略

#### Dify側（公式構成）

| 種類           | 用途                         | 実装方式     | マウント先                                       |
| :------------- | :--------------------------- | :----------- | :----------------------------------------------- |
| **Structured** | 設定・プロンプト管理         | Named Volume | `db_postgres:/var/lib/postgresql/data`           |
| **Cache**      | セッション・ジョブキュー     | Named Volume | `redis:/data`                                    |
| **Blob**       | 生成コンテンツ・アップロード | Bind Mount   | `./dify/docker/volumes/app/storage:/app/storage` |
| **Plugin**     | プラグインデータ             | Named Volume | `plugin_daemon:/app/storage`                     |
| **Vector**     | ベクトルインデックス         | Named Volume | `weaviate:/var/lib/weaviate`                     |

#### n8n側（独自構成）

| 種類           | 用途             | 実装方式     | マウント先                               |
| :------------- | :--------------- | :----------- | :--------------------------------------- |
| **Structured** | ワークフロー履歴 | Named Volume | `postgres-data:/var/lib/postgresql/data` |
| **n8n Data**   | ワークフロー定義 | Named Volume | `n8n-data:/home/node/.n8n`               |
| **Blob**       | 共有ファイル     | Bind Mount   | `./shared/data:/shared/data`             |

---

## Infrastructure

### ディレクトリ構成（実装後）

```
infrastructure/
├── docker-compose.yml              # メインファイル（include使用）
├── .env                            # n8n用環境変数
├── .env.example                    # n8n環境変数テンプレート
├── .gitignore                      # Git除外設定
├── README.md                       # 詳細ドキュメント
├── QUICKSTART.md                   # クイックスタートガイド
│
├── docs/
│   └── spec.md                     # 本ファイル
│
├── n8n/
│   └── compose.yml                 # n8n専用Docker Compose設定
│
├── dify/
│   ├── .env                        # Dify用環境変数
│   ├── .env.example                # Dify環境変数テンプレート
│   └── docker/                     # 公式リポジトリ（sparse checkout）
│       ├── docker-compose.yaml     # 公式ファイル（無改変）
│       ├── .env.example            # 公式環境変数テンプレート
│       ├── nginx/                  # Nginx設定（4ファイル）
│       ├── ssrf_proxy/             # SSRFプロキシ設定（2ファイル）
│       ├── volumes/                # データ永続化用
│       └── ...                     # その他公式設定
│
├── init-scripts/
│   └── 01-init-databases.sh        # n8n用PostgreSQL初期化スクリプト（冪等）
│
├── shared/
│   └── data/                       # n8nとPython Workerの共有ストレージ
│
└── logs/                           # ログ集約先（オプション）
```

### 環境変数設計

#### n8n用環境変数 (`.env`)

```bash
# PostgreSQL (n8n専用)
POSTGRES_USER=logicfactory
POSTGRES_PASSWORD=<strong-password>
POSTGRES_DB=postgres

# n8n Database
N8N_DB_NAME=n8n_db

# n8n Configuration
GENERIC_TIMEZONE=Asia/Tokyo
N8N_SECURE_COOKIE=false
N8N_HOST=localhost
N8N_PORT=5678
N8N_PROTOCOL=http
WEBHOOK_URL=http://localhost:5678/
```

#### Dify用環境変数 (`dify/.env`)

公式の`dify/docker/.env.example`をコピーして作成。主要な設定項目：

```bash
# Core Settings
SECRET_KEY=<generate-random-key-min-32-chars>
CONSOLE_WEB_URL=http://localhost
CONSOLE_API_URL=http://localhost/console/api
SERVICE_API_URL=http://localhost/api
APP_WEB_URL=http://localhost

# Database (Dify専用PostgreSQL)
DB_USERNAME=postgres
DB_PASSWORD=<dify-db-password>
DB_HOST=db_postgres
DB_PORT=5432
DB_DATABASE=dify

# Redis (Dify専用)
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=<dify-redis-password>
REDIS_DB=0
CELERY_BROKER_URL=redis://:${REDIS_PASSWORD}@redis:6379/1

# Storage
STORAGE_TYPE=local
STORAGE_LOCAL_PATH=/app/storage

# Vector Store
VECTOR_STORE=weaviate
WEAVIATE_ENDPOINT=http://weaviate:8080

# Code Execution
CODE_EXECUTION_ENDPOINT=http://sandbox:8194
CODE_EXECUTION_API_KEY=${SECRET_KEY}

# Plugin
PLUGIN_ENABLED=true
PLUGIN_DAEMON_URL=http://plugin_daemon:5002
```

### Docker Compose 設計原則

#### 1. メインファイルの役割 (`docker-compose.yml`)

```yaml
# n8n専用のサービス定義と、includeによる統合
services:
  # 共有PostgreSQL（n8n用）
  db:
    image: postgres:15-alpine
    # ... n8n用のPostgreSQL設定

  # 共有Redis（n8n用、オプション）
  redis:
    image: redis:7-alpine
    # ... 設定

# 外部composeファイルのインクルード
include:
  - path: ./n8n/compose.yml
  - path: ./dify/docker/docker-compose.yaml
    env_file: ./dify/.env

# 共有ネットワーク
networks:
  logic-factory-net:
    driver: bridge
```

#### 2. n8n専用設定 (`n8n/compose.yml`)

```yaml
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: logic-factory-n8n
    restart: unless-stopped
    networks:
      - logic-factory-net
    ports:
      - "5678:5678"
    environment:
      # PostgreSQL接続（共有dbコンテナ）
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=db
      - DB_POSTGRESDB_DATABASE=${N8N_DB_NAME}
      # ... その他設定
    volumes:
      - n8n-data:/home/node/.n8n
      - ../shared/data:/shared/data
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  n8n-data:

networks:
  logic-factory-net:
    external: true
```

#### 3. Dify公式設定 (`dify/docker/docker-compose.yaml`)

公式リポジトリのファイルを**無改変で使用**。ただし、以下の点を`dify/.env`で調整：

- `CONSOLE_WEB_URL`, `APP_WEB_URL`等のURL設定
- データベース・Redis認証情報
- ベクトルストア選択（デフォルト: Weaviate）

#### 4. ネットワーク統合

全サービスが`logic-factory-net`に参加する設定：

- メインdocker-compose.ymlでネットワークを定義
- `n8n/compose.yml`で`external: true`として参照
- Difyの公式docker-compose.yamlは内部ネットワークを使用するため、必要に応じてオーバーライド

---

## 実装フェーズ

### Phase 1: 公式Difyリポジトリの取得 ⬜

**目的**: Difyの公式docker設定を取得

**タスク**:

1. Sparse checkoutで`docker/`ディレクトリのみクローン
   ```bash
   cd infrastructure
   git clone --depth 1 --filter=blob:none --sparse \
     https://github.com/langgenius/dify.git dify-official
   cd dify-official
   git sparse-checkout set docker
   ```
2. シンボリックリンクまたはディレクトリ移動
   ```bash
   cd ..
   ln -s dify-official/docker dify/docker
   # または
   mv dify-official/docker dify/docker
   ```
3. `.gitignore`に`dify-official/`を追加（シンボリックリンク方式の場合）

**検証**:

- [ ] `dify/docker/docker-compose.yaml`が存在
- [ ] `dify/docker/nginx/`ディレクトリが存在
- [ ] `dify/docker/ssrf_proxy/`ディレクトリが存在

---

### Phase 2: 環境変数ファイルの整理 ⬜

**目的**: n8n用とDify用の環境変数を分離

**タスク**:

1. 既存の`.env`をn8n専用に整理
   - Dify関連の環境変数を削除
   - n8n必須項目のみ残す
2. `dify/.env`を作成
   ```bash
   cp dify/docker/.env.example dify/.env
   ```
3. `dify/.env`を編集
   - `SECRET_KEY`, `REDIS_PASSWORD`等を設定
   - URL系の設定を確認
4. `.env.example`ファイルを更新

**検証**:

- [ ] `infrastructure/.env`にn8n設定のみ含まれる
- [ ] `infrastructure/dify/.env`にDify設定が含まれる
- [ ] 両方の`.env.example`が更新されている

---

### Phase 3: n8n設定の分離 ⬜

**目的**: n8n専用のDocker Compose設定を作成

**タスク**:

1. `n8n/compose.yml`を作成
2. 既存`docker-compose.yml`からn8nサービス定義を移動
3. 共有PostgreSQL(`db`)への依存関係を設定
4. ネットワーク設定を`external: true`に変更
5. ボリューム定義を追加

**検証**:

- [ ] `n8n/compose.yml`が作成されている
- [ ] n8nサービスのみ定義されている
- [ ] ネットワーク設定が正しい（external）

---

### Phase 4: メインdocker-compose.ymlの作成 ⬜

**目的**: `include`機能を使った統合設定を作成

**タスク**:

1. 既存`docker-compose.yml`をバックアップ
   ```bash
   mv docker-compose.yml docker-compose.yml.old
   ```
2. 新しい`docker-compose.yml`を作成
   - 共有PostgreSQL(`db`)の定義
   - 共有Redis（オプション）
   - `include`セクション
   - ネットワーク定義
3. ログ設定の統一
4. ヘルスチェックの設定

**検証**:

- [ ] 新しい`docker-compose.yml`が作成されている
- [ ] `include`セクションが正しい
- [ ] ネットワーク定義がある

---

### Phase 5: PostgreSQL初期化スクリプトの調整 ✅

**目的**: n8n用データベースのみ初期化するよう修正し、冪等性を確保

**タスク**:

1. ~~`init-scripts/01-init-databases.sql`を確認~~ → シェルスクリプトに変更
2. ~~Dify用データベース作成部分を削除（Difyは独自PostgreSQLを使用）~~ → 完了
3. ~~n8n_dbのみ作成~~ → 完了
4. ~~冪等性を確保（何度実行しても安全）~~ → 完了

**実装内容**:

- `01-init-databases.sh`（冪等なシェルスクリプト）を作成
- データベースが既に存在する場合はスキップする仕組みを実装
- `make infra-up`で何度実行してもエラーにならないことを保証

**検証**:

- [x] n8n_dbのみ作成される
- [x] Dify関連のDB作成コードが削除されている
- [x] 冪等性が確保されている（再実行しても安全）

---

### Phase 6: Makefileコマンドの更新 ⬜

**目的**: 新しいディレクトリ構成に対応したコマンドを提供

**タスク**:

1. プロジェクトルートの`Makefile`を確認
2. 必要に応じて`infrastructure/`ディレクトリ変更に対応
3. 新しいコマンドの追加（例: `dify-logs`, `n8n-logs`）

**検証**:

- [ ] `make infra-up`が動作
- [ ] `make infra-logs`が全サービスのログを表示
- [ ] 個別サービスのログコマンドが動作

---

### Phase 7: 動作確認・テスト ⬜

**目的**: 全サービスが正常に起動し、連携することを確認

**テスト項目**:

1. **起動テスト**

   ```bash
   docker compose up -d
   docker compose ps
   ```

   - [ ] 全コンテナが起動（n8n + Dify11サービス）
   - [ ] ヘルスチェックが全て`healthy`

2. **アクセステスト**
   - [ ] http://localhost:5678 でn8n UIにアクセス可能
   - [ ] http://localhost:80 でDify UIにアクセス可能

3. **データ永続化テスト**

   ```bash
   docker compose down
   docker compose up -d
   ```

   - [ ] n8nの設定が保持されている
   - [ ] Difyの設定が保持されている

4. **サービス間連携テスト**
   - [ ] n8nからDify APIへのHTTPリクエストが成功
   - [ ] Docker DNS解決が動作（`dify-api`, `db`等）

5. **ログ確認**
   ```bash
   docker compose logs
   ```

   - [ ] エラーログがない
   - [ ] 全サービスが正常起動ログを出力

---

### Phase 8: ドキュメントの更新 ⬜

**目的**: README・QUICKSTARTを新しい構成に更新

**タスク**:

1. `README.md`を更新
   - ディレクトリ構成図を修正
   - 環境変数ファイルの説明を追加
   - Docker Compose includeの説明追加
2. `QUICKSTART.md`を更新
   - 起動手順の確認（変更がない場合は維持）
   - トラブルシューティングの追加
3. 本`spec.md`のステータスを更新

**検証**:

- [ ] README.mdが最新の構成を反映
- [ ] QUICKSTART.mdで実際に起動できる
- [ ] ADR-001へのリンクが適切

---

## Definition of Done (DoD)

以下の全条件を満たした時点で、新しいインフラストラクチャ構成が完成したと見なす。

### 1. ファイル構成の完成 ⬜

- [ ] `infrastructure/docker-compose.yml`（メインファイル、include使用）
- [ ] `infrastructure/n8n/compose.yml`（n8n専用設定）
- [ ] `infrastructure/dify/docker/`（公式リポジトリ、sparse checkout）
- [ ] `infrastructure/.env`（n8n用環境変数）
- [ ] `infrastructure/dify/.env`（Dify用環境変数）
- [ ] 両方の`.env.example`ファイル

### 2. 環境起動の成功 ⬜

- [ ] `docker compose up -d`で全サービスが正常起動（12+サービス）
- [ ] `docker compose ps`で全コンテナのStatusが`Up (healthy)`または`Up`
- [ ] 起動時間が3分以内（初回は5分許容）

### 3. サービスアクセスの確認 ⬜

- [ ] `http://localhost:5678`でn8n UIにアクセス可能
- [ ] `http://localhost:80`でDify UIにアクセス可能
- [ ] 初回アクセス時にセットアップウィザードが表示される

### 4. データ永続化の検証 ⬜

- [ ] `docker compose down`後、`docker compose up`で設定が保持される
- [ ] n8nでワークフロー作成→再起動→ワークフローが消えない
- [ ] Difyでプロンプト作成→再起動→プロンプトが消えない
- [ ] Named Volumeが正しく作成されている（`docker volume ls`）

### 5. サービス間連携の確認 ⬜

- [ ] n8nからDify APIへのHTTPリクエストが成功
  - URL: `http://nginx:80/api/...` または直接 `http://api:5001/...`
- [ ] Docker DNS解決が動作（サービス名でアクセス可能）
- [ ] Difyでプロンプトを実行し、結果が返る

### 6. ネットワーク設計の検証 ⬜

- [ ] `docker network ls`で`logic-factory-net`が存在
- [ ] 全サービスが同一ネットワークに参加
- [ ] PostgreSQL/Redisが外部公開されていない
- [ ] n8n(5678), Dify(80)のみ外部公開

### 7. 公式構成の保証 ⬜

- [ ] `dify/docker/docker-compose.yaml`が無改変
- [ ] 公式の`nginx/`, `ssrf_proxy/`設定がそのまま利用されている
- [ ] Difyの全11サービスが起動している

### 8. ドキュメント整備 ⬜

- [ ] `README.md`が新しい構成を反映
- [ ] `QUICKSTART.md`で実際に起動できる
- [ ] 両方の`.env.example`に全設定項目が記載
- [ ] 本`spec.md`が実際の実装と一致
- [ ] ADR-001へのリンクが機能

### 9. トラブルシューティング手順の確立 ⬜

- [ ] コンテナ起動失敗時のログ確認手順が文書化
- [ ] ポート競合時の解決方法が記載
- [ ] Dify公式リポジトリ更新手順が記載
- [ ] ネットワーク問題の対処法が記載

### 10. メンテナンス性の確認 ⬜

- [ ] Dify公式アップデート手順の文書化
  ```bash
  cd infrastructure/dify-official
  git pull
  docker compose up -d --pull always
  ```
- [ ] バックアップ手順の文書化
- [ ] ロールバック手順の文書化

---

## 運用コマンド一覧

### 起動・停止

```bash
# プロジェクトルートから（推奨）
make infra-up           # 全サービス起動
make infra-down         # 全サービス停止（データ保持）
make infra-restart      # 全サービス再起動
make infra-ps           # ステータス確認

# または infrastructure/ ディレクトリ内で
docker compose up -d
docker compose down
docker compose restart
docker compose ps
```

### ログ確認

```bash
# 全サービス
make infra-logs
docker compose logs -f

# n8nのみ
make infra-logs-n8n
docker compose logs -f n8n

# Dify関連のみ
make infra-logs-dify
docker compose logs -f api worker web nginx
```

### 監視・デバッグ

```bash
# ヘルスチェック
make infra-health

# データベース接続
make infra-db
docker compose exec db psql -U logicfactory -d n8n_db

# Dify PostgreSQL接続
docker compose exec db_postgres psql -U postgres -d dify

# Redis接続
docker compose exec redis redis-cli
```

### メンテナンス

```bash
# Dify公式リポジトリの更新
cd infrastructure/dify-official
git pull origin main
cd ../..
docker compose pull
docker compose up -d

# ボリューム確認
docker volume ls | grep infrastructure

# ネットワーク確認
docker network inspect logic-factory-net

# データのリセット（警告: 全データ削除）
make infra-clean-all
```

---

## トラブルシューティング

### コンテナ起動失敗

1. ログを確認

   ```bash
   docker compose logs <service-name>
   ```

2. ヘルスチェック確認

   ```bash
   docker compose ps
   ```

3. 依存サービスの確認
   - PostgreSQLが先に起動しているか
   - Redisが起動しているか

### ポート競合

既にポート5678または80が使用されている場合：

```bash
# ポート使用状況を確認
lsof -i :5678
lsof -i :80

# docker-compose.ymlのportsセクションを変更
# 例: "8080:80" に変更
```

### Dify関連エラー

1. 環境変数確認

   ```bash
   cat dify/.env
   # SECRET_KEYが32文字以上か確認
   ```

2. 公式設定の確認

   ```bash
   cd dify/docker
   cat docker-compose.yaml
   # サービス定義が正しいか確認
   ```

3. 公式リポジトリの再取得
   ```bash
   rm -rf dify/docker
   # Phase 1から再実行
   ```

### ネットワーク問題

n8nからDifyにアクセスできない場合：

```bash
# ネットワーク確認
docker network inspect logic-factory-net

# 全サービスがネットワークに参加しているか確認
docker compose ps --format json | jq '.[].Networks'

# DNS解決テスト
docker compose exec n8n ping -c 3 nginx
docker compose exec n8n ping -c 3 api
```

---

## 参照ドキュメント

- [ADR-001: Dify と n8n の統合戦略](../../docs/02_architecture/adr/001-dify-n8n-integration-strategy.md) - 技術選定の背景と理由
- [Infrastructure Architecture](../../docs/02_architecture/infrastructure.md) - アーキテクチャ詳細
- [共通基盤利用ルール](../../docs/01_guidelines/tool.md) - 運用ルール
- [Spec-Driven Development Protocol](../../docs/01_guidelines/spec-driven-development.md) - 開発プロセス
- [Docker Compose include documentation](https://docs.docker.com/compose/how-tos/multiple-compose-files/) - 公式ドキュメント
- [Dify Official Documentation](https://docs.dify.ai/getting-started/install-self-hosted/docker-compose) - Dify公式ドキュメント

---

## 実装ステータス

**現在のフェーズ**: Phase 7 - 動作確認・テスト完了 ✅

### 完了済みフェーズ

- ✅ Phase 0: 設計完了
- ✅ Phase 1: 公式Difyリポジトリの取得
- ✅ Phase 2: 環境変数ファイルの整理
- ✅ Phase 3: n8n設定の分離
- ✅ Phase 4: メインdocker-compose.ymlの作成
- ✅ Phase 5: PostgreSQL初期化スクリプトの調整
- ✅ Phase 6: Makefileコマンドの更新
- ✅ Phase 7: 動作確認・テスト
- ⏳ Phase 8: ドキュメントの更新（進行中）

### 動作確認結果

**起動成功**: 全13コンテナが正常に起動

| コンテナ                       | ステータス | 備考                  |
| :----------------------------- | :--------- | :-------------------- |
| logic-factory-n8n              | ✅ Healthy | http://localhost:5678 |
| logic-factory-db               | ✅ Healthy | n8n用PostgreSQL       |
| infrastructure-db_postgres-1   | ✅ Healthy | Dify用PostgreSQL      |
| infrastructure-api-1           | ✅ Up      | Dify API              |
| infrastructure-worker-1        | ✅ Up      | Dify Worker           |
| infrastructure-worker_beat-1   | ✅ Up      | Dify Scheduler        |
| infrastructure-web-1           | ✅ Up      | Dify Web UI           |
| infrastructure-nginx-1         | ✅ Up      | http://localhost:80   |
| infrastructure-redis-1         | ✅ Healthy | Dify Redis            |
| infrastructure-plugin_daemon-1 | ✅ Up      | Dify Plugins          |
| infrastructure-sandbox-1       | ✅ Healthy | Code Sandbox          |
| infrastructure-ssrf_proxy-1    | ✅ Up      | SSRF Protection       |
| infrastructure-weaviate-1      | ✅ Up      | Vector Store          |

**重要な注意点**:

- Docker Compose Profilesを使用しているため、起動時に `--profile weaviate --profile postgresql` の指定が必要
- Makefileでは自動的にプロファイルを指定するよう設定済み
- 手動起動する場合: `docker compose --profile weaviate --profile postgresql up -d`

次のステップ: Phase 8 - ドキュメントの最終更新
