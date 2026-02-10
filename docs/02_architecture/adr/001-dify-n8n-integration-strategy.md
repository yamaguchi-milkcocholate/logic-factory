# ADR-001: Dify と n8n の統合戦略

## Status

**Accepted** - 2026-02-11

## Context

### 背景

Logic Factoryは、n8n（ワークフローオーケストレーション）とDify（AI推論エンジン）を統合した共通基盤を構築しています。当初、Difyの公式docker-compose設定を独自に再実装する方針で進めていましたが、以下の問題が発生しました：

1. **設定の複雑性**: 公式の設定を手動で再現しようとしたため、設定漏れや不整合が発生
2. **メンテナンス困難**: 公式のアップデートに追従するのが難しい
3. **動作保証の欠如**: 公式の動作確認済み構成から外れている

### プロジェクトの設計思想

Logic Factoryは以下の原則に基づいています：

- **Everything as Code**: `infrastructure/` 配下の設定ファイルのみで環境を完全再現可能とする
- **Environment Parity**: ローカル (Docker Compose) と本番 (GCP VM/Cloud Run) の差異を最小化
- **単一ネットワーク**: 全てのサービスは Docker 内のカスタムブリッジネットワーク `logic-factory-net` に参加
- **依存関係の明示**: n8n が Dify の生存を確認してからワークフローを開始する

### 調査内容

#### 公式Difyリポジトリの構成

公式の`docker/`ディレクトリには以下が含まれる：

- `docker-compose.yaml` - メイン構成ファイル
- `.env.example` - 環境変数テンプレート
- `nginx/` - リバースプロキシ設定（4ファイル）
- `ssrf_proxy/` - セキュリティプロキシ設定（2ファイル）
- `volumes/` - データ永続化用ディレクトリ
- その他ベクトルDB用設定ディレクトリ

**重要**: docker-compose.yamlのみでは構築できず、関連する設定ファイルとディレクトリが必須。

#### ベストプラクティス調査（2026年版）

1. **外部プロジェクト統合方法**
   - **Git Submodule**: 公式更新への追従が容易だが、git操作がやや複雑
   - **ファイルコピー**: シンプルだが手動更新必要、差分管理が困難
   - **Sparse Checkout**: 必要部分のみクローン、Git管理可能

2. **Monorepo + Docker Compose管理**
   - **Docker Compose `include`機能** (2024年導入): 複数のdocker-composeファイルをモジュール化
   - Build contextはリポジトリルートに設定
   - `.dockerignore`を積極的に活用

3. **Dify本番環境推奨**
   - 開発・小規模: Docker Compose
   - 本番・高可用性: Kubernetes推奨
   - システム要件: 最小 CPU 2コア、RAM 8GB

**出典**:

- [Docker Compose Modularity with include](https://www.docker.com/blog/improve-docker-compose-modularity-with-include/)
- [How to Structure a Monorepo with Docker (2026)](https://oneuptime.com/blog/post/2026-02-08-how-to-structure-a-monorepo-with-docker/view)
- [Dify Docker Compose Deployment](https://docs.dify.ai/getting-started/install-self-hosted/docker-compose)

## Decision

**プランA: Docker Compose `include`機能を採用**

### ディレクトリ構成

```
infrastructure/
├── docker-compose.yml          # メインファイル（include使用）
├── n8n/
│   └── compose.yml             # n8n専用設定
├── dify/
│   ├── docker/                 # 公式をsparse checkout
│   │   ├── docker-compose.yaml # 公式ファイル（無改変）
│   │   ├── .env.example
│   │   ├── nginx/
│   │   ├── ssrf_proxy/
│   │   └── volumes/
│   └── .env                    # Dify用環境変数
├── shared/
│   └── data/                   # コンテナ間共有ストレージ
└── .env                        # 共通環境変数（n8n用）
```

### 実装方針

1. **公式リポジトリの取得**: Git sparse checkoutで`docker/`ディレクトリのみクローン
2. **設定の分離**: n8nとDifyの設定を別ファイルで管理
3. **統合起動**: メインのdocker-compose.ymlで`include`を使い、単一コマンドで全サービス起動
4. **ネットワーク共有**: `logic-factory-net`を共有ネットワークとして定義

### 検討した代替案

#### プランB: 統合docker-compose.yml

現在の`infrastructure/docker-compose.yml`に公式設定をマージ

- **メリット**: すべてが1ファイル、シンプル
- **デメリット**: 公式更新の手動マージ必要、ファイルが複雑化
- **却下理由**: メンテナンス性が低く、公式更新への追従が困難

#### プランC: 完全分離

n8nとDifyを別々のdocker-composeで管理

- **メリット**: 独立性が高い
- **デメリット**:
  - プロジェクト設計思想（単一ネットワーク）に反する
  - 運用コマンドが分散
  - 依存関係の管理が複雑
- **却下理由**: Everything as Code原則および依存関係の明示的管理に反する

## Consequences

### ポジティブな影響

1. **メンテナンス性の向上**: 公式docker-compose.yamlを無改変で利用するため、設定ミスが減少
2. **更新追従の容易さ**: `git pull`のみで公式の最新版に更新可能
3. **Everything as Code原則の遵守**: 全設定がGit管理され、環境の完全再現が可能
4. **単一コマンド管理**: `docker compose up -d`で全サービスが起動
5. **ネットワーク統合**: n8nとDifyが同一ネットワークで自然に連携
6. **設計思想との整合性**: 依存関係の明示的管理が可能

### ネガティブな影響・考慮事項

1. **ディレクトリ構造の変更**: 既存の独自docker-compose.ymlからの移行が必要
2. **学習コスト**: Docker Compose `include`機能の理解が必要（ただし、公式ドキュメント充実）
3. **Git submodule/sparse checkout管理**: 公式リポジトリの部分的クローンの管理が必要
4. **環境変数の分散**: n8n用とDify用で`.env`ファイルが分かれる（ただし、責務分離としては適切）

### 移行タスク

1. ✅ ADRの作成（本ファイル）
2. ⬜ `docs/02_architecture/infrastructure.md`の更新
3. ⬜ 公式Difyリポジトリのsparse checkout
4. ⬜ n8n設定の分離（`n8n/compose.yml`作成）
5. ⬜ メイン`docker-compose.yml`の作成（`include`使用）
6. ⬜ 環境変数ファイルの整理
7. ⬜ Makefileコマンドの更新
8. ⬜ READMEおよびQUICKSTART.mdの更新
9. ⬜ 動作確認・テスト

### 運用への影響

- **起動コマンド**: 変更なし（`make infra-up` または `docker compose up -d`）
- **ログ確認**: 変更なし（全サービスが単一docker-composeで管理されるため）
- **個別サービス再起動**: サービス名が変わる可能性あり（Makefileで吸収）

## References

- [Docker Compose Modularity with include](https://www.docker.com/blog/improve-docker-compose-modularity-with-include/)
- [How to Structure a Monorepo with Docker (2026)](https://oneuptime.com/blog/post/2026-02-08-how-to-structure-a-monorepo-with-docker/view)
- [Dify Official Docker Compose Guide](https://docs.dify.ai/getting-started/install-self-hosted/docker-compose)
- [Running Docker Compose Like a Pro](https://henwib.medium.com/building-blocks-of-docker-compose-organizing-services-with-git-submodules-part-1-6535b2dbf8d1)
- [Dify GitHub Repository - docker directory](https://github.com/langgenius/dify/tree/main/docker)

## Notes

このADRは、Logic Factoryの共通基盤構築における重要な技術的意思決定を記録するものです。今後、Dify以外の外部サービス統合においても、同様の原則（公式設定の尊重、Docker Compose includeの活用）を適用することを推奨します。
