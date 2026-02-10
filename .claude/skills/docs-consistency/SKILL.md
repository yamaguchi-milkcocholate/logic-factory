---
name: docs-consistency
description: Checks and fixes inconsistencies across documentation files. Use to ensure all docs are accurate and consistent.
---

ドキュメントの整合性を確認し、誤りを修正するスキルです。

## 説明

Logic Factory リポジトリ内の全ドキュメント（README.md, CLAUDE.md, docs/ 配下のファイル）間の整合性をチェックし、以下の問題を検出・修正します:

- 相互参照リンクの正確性（存在しないファイルへのリンク、タイポ）
- ディレクトリ名・ファイル名の一貫性
- 技術スタック・ツール名の記載の統一性
- バージョン情報の一貫性
- 用語の統一性（表記揺れ）
- ドキュメント構造の完全性

## 使用方法

```bash
/docs-consistency
```

パラメータは不要です。実行すると、すべてのドキュメントをスキャンし、問題があれば報告・修正提案を行います。

## チェック項目

### 1. ファイル構造の整合性

- `docs/01_guidelines/` 配下のファイルが全て存在するか
- `docs/02_architecture/` 配下のファイルが全て存在するか
- README.md, CLAUDE.md が存在するか

### 2. 相互参照リンクの整合性

以下のドキュメント間のリンクをチェック:

- README.md → docs/ への参照
- CLAUDE.md → docs/ への参照
- docs/ 内のドキュメント間の相互参照
- spec-driven-development.md の例: `[`docs/01_guidlines/`]` のようなタイポ

### 3. 技術スタック・ツール名の一貫性

以下の項目の記載が全ドキュメントで一致しているかを確認:

- **Orchestrator**: n8n
- **AI/LLM Logic**: Dify
- **Database**: PostgreSQL
- **Computing**: Local Docker → GCP VM (Coolify)
- **Execution**: Cloud Run Jobs
- **Python パッケージマネージャ**: uv
- **HTTP クライアント**: httpx
- **型チェック**: mypy / Pyright
- **データバリデーション**: Pydantic
- **ロギング**: loguru
- **設定管理**: pydantic-settings
- **静的解析**: ruff

### 4. ディレクトリ構造の一貫性

README.md と CLAUDE.md で記載されているディレクトリ構造が一致しているかを確認:

```
.
├── infrastructure/
├── apps/
│   └── {app_name}/
├── shared/
│   ├── python/
│   └── data/
├── docs/
│   ├── 01_guidelines/
│   └── 02_architecture/
└── Makefile
```

### 5. 用語の統一性

以下の用語が統一されているかを確認:

- 「仕様」vs「スペック」vs「spec」
- 「アプリ」vs「プロジェクト」vs「モジュール」
- 「ワークフロー」vs「パイプライン」

### 6. コマンドの一貫性

README.md と CLAUDE.md で記載されているコマンド例が一致しているかを確認:

- 環境構築コマンド
- Python 実行コマンド
- Lint/Format コマンド

## 実行手順

1. 全ドキュメントファイルをスキャン
2. 各チェック項目について検証
3. 検出された問題をリスト化
4. 修正が必要な箇所を特定
5. ユーザーに修正提案を提示
6. 承認後、修正を実行

## 出力形式

検出された問題は以下の形式で報告されます:

```
## 整合性チェック結果

### ❌ 問題が検出されました

#### 1. リンク切れ
- 📄 docs/01_guidelines/spec-driven-development.md:48
  - 誤: `docs/01_guidlines/`
  - 正: `docs/01_guidelines/`

#### 2. 用語の不統一
- 📄 README.md:47
  - 「spec.md」と記載されているが、他のドキュメントでは「{spec-name}.md」

### ✅ 修正提案

以下の修正を行いますか？
1. [ファイル名:行番号] 修正内容...
2. [ファイル名:行番号] 修正内容...
```

## 注意事項

- このスキルは読み取り専用でドキュメントをスキャンし、修正はユーザーの承認後に実行します
- 自動修正前に必ず変更内容をユーザーに確認します
- バックアップは Git で管理されているため、変更は git diff で確認可能です
