# Logic Factory Infrastructure Specification

## 1. インフラ基本思想

- **Everything as Code**: 全てのインフラ定義をコード化し、`infrastructure/` 配下の設定ファイルのみで環境を完全再現可能とする。
- **Environment Parity**: ローカル (Docker Compose) と本番 (GCP VM/Cloud Run) の差異を最小化し、環境依存のバグを排除する。

## 2. ネットワークトポロジー

全てのサービスは Docker 内のカスタムブリッジネットワーク `logic-factory-net` に参加し、サービス名による名前解決（DNS）を行う。

- **Internal (Private)**: DB、Redis、Dify API は外部公開せず、n8n や Worker からのみアクセスを許可。
- **External (Public)**: n8n の UI (ポート 5678) および Dify UI (ポート 80) のみ、リバースプロキシ経由で外部公開。

## 3. コンポーネント詳細

### A. オーケストレーション (n8n)

- **Persistance**: SQLite ではなく PostgreSQL を外部 DB として接続。
- **Isolation**: 実行ログを DB に保存し、コンテナが再起動してもワークフローの状態を維持。

### B. 推論エンジン (Dify)

- **公式Docker Compose使用**: [Dify公式リポジトリ](https://github.com/langgenius/dify)の`docker/`ディレクトリをsparse checkoutで取得し、無改変で利用。
- **システム要件**: 最小 CPU 2コア、RAM 8GB
- **Modular Stack**: 以下のマイクロサービス群で構成。
  - **コアサービス** (5):
    - `api`: REST APIサーバー（Gunicorn）
    - `worker`: Celeryタスク処理（キューイング）
    - `worker_beat`: Celeryスケジューラー（定期タスク）
    - `web`: フロントエンド（Next.js）
    - `plugin_daemon`: プラグイン実行環境
  - **依存コンポーネント** (6):
    - `db_postgres`: Dify固有の設定・プロンプト管理用PostgreSQL
    - `redis`: キャッシュおよびキュー管理
    - `nginx`: リバースプロキシ&ロードバランサー
    - `sandbox`: 安全なコード実行サンドボックス
    - `ssrf_proxy`: SSRF攻撃対策用プロキシ
    - `weaviate`: ベクトルストレージ（他のベクトルDBも選択可能）

### C. 実行エージェント (Python Worker)

- **Compute**: ローカルでは同一 Docker 内のコンテナとして稼働。高負荷時は `Cloud Run Jobs` へオフロード。
- **Volume Mounting**: `/shared/data` をホストおよび全コンテナ間でマウントし、動画素材や解析ログの高速な受け渡しを実現。

## 4. ストレージ戦略

| 種類           | 用途           | 物理実体 (Local)         | 物理実体 (GCP)             |
| :------------- | :------------- | :----------------------- | :------------------------- |
| **Structured** | 設定・履歴     | PostgreSQL Container     | Cloud SQL (or VM内DB)      |
| **Cache**      | 一時データ     | Redis Container          | Memorystore (or VM内Redis) |
| **Blob**       | 動画・画像素材 | `./shared/data` (Volume) | Google Cloud Storage       |

## 5. 監視とロギング (Observability)

- **Health Check**: 各コンテナにヘルスチェックを設定し、n8n が Dify の生存を確認してからワークフローを開始する依存関係を定義。
- **Log Aggregation**: 全コンテナの標準出力を `logic-factory/logs/` に集約し、トラブルシューティングを容易にする。

## 6. ディレクトリ構成

```
infrastructure/
├── docker-compose.yml          # メインファイル（include使用）
├── n8n/
│   └── compose.yml             # n8n専用設定
├── dify/
│   ├── docker/                 # Dify公式設定（sparse checkout）
│   │   ├── docker-compose.yaml # 公式ファイル（無改変）
│   │   ├── .env.example
│   │   ├── nginx/              # リバースプロキシ設定
│   │   ├── ssrf_proxy/         # セキュリティプロキシ設定
│   │   └── volumes/            # データ永続化
│   └── .env                    # Dify用環境変数
├── shared/
│   └── data/                   # コンテナ間共有ストレージ
├── logs/                       # ログ集約先
└── .env                        # 共通環境変数（n8n用）
```

### 公式リポジトリの統合

Difyは公式リポジトリの`docker/`ディレクトリを**Git sparse checkout**で取得し、設定ファイルを無改変で利用します。これにより：

- ✅ 公式の動作確認済み構成を保証
- ✅ `git pull`のみで最新版に更新可能
- ✅ 設定ミスや不整合を回避
- ✅ メンテナンス負荷を最小化

```bash
# 公式dockerディレクトリの取得
cd infrastructure
git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/langgenius/dify.git dify-official
cd dify-official
git sparse-checkout set docker
```

## 7. Docker Compose 統合戦略

### Docker Compose `include` 機能

Logic Factoryでは、Docker Compose 2.20以降で導入された`include`機能を活用し、n8nとDifyの設定を分離しつつ、単一コマンドで全サービスを管理します。

**メインファイル例** (`infrastructure/docker-compose.yml`):

```yaml
include:
  - path: ./n8n/compose.yml
  - path: ./dify/docker/docker-compose.yaml
    env_file: ./dify/.env

networks:
  logic-factory-net:
    driver: bridge
```

### メリット

1. **モジュール性**: n8nとDifyの設定を独立して管理
2. **公式設定の尊重**: Difyの公式docker-compose.yamlを無改変で利用
3. **単一コマンド管理**: `docker compose up -d`で全サービス起動
4. **ネットワーク統合**: 全サービスが`logic-factory-net`で自然に連携
5. **Everything as Code**: 全設定がGit管理され、環境の完全再現が可能

### 参考資料

- [ADR-001: Dify と n8n の統合戦略](./adr/001-dify-n8n-integration-strategy.md) - 技術選定の詳細な背景と理由
- [Docker Compose Modularity with include](https://www.docker.com/blog/improve-docker-compose-modularity-with-include/)
- [Dify Official Documentation](https://docs.dify.ai/getting-started/install-self-hosted/docker-compose)
