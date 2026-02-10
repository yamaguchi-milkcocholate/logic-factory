---
name: create-spec
description: Create a spec document for a change or improvement in Logic Factory following the Spec-Driven Development protocol
argument-hint: [change-id]
disable-model-invocation: true
---

# Create Spec Document

Logic Factory の Spec-Driven Development プロトコルに従って、改修・変更の設計書を作成します。

**対象**: 機能追加、バグ修正、改善、リファクタリングなど、あらゆる規模の変更に対応します。

## 実行プロセス

### 1. 設計書情報の確認

まず、以下の情報をユーザーから収集します（引数で指定されていない場合）:

- **変更ID**: `$ARGUMENTS` が指定されている場合はそれを使用、なければ質問する（例: `add-error-retry`, `fix-n8n-timeout`）
- **対象プロジェクト**: どのプロジェクト/コンポーネントに対する変更か（既存プロジェクト名または新規の場合はプロジェクト名）
- **変更の目的**: どのような問題を解決し、どのような価値を提供するか

### 2. ディレクトリ構造の確認

対象プロジェクトに応じて、以下のいずれかの構造で設計書を配置します:

**既存プロジェクトへの変更の場合:**

```bash
apps/{project-name}/
└── docs/
    ├── spec.md  # 既存の仕様書（あれば）
    └── changes/
        └── {change-id}.md  # 新しい変更設計書
```

**新規プロジェクトの場合:**

```bash
apps/{project-name}/
├── docs/
│   └── spec.md  # プロジェクト全体の仕様書
├── src/
└── pyproject.toml
```

必要なディレクトリが存在しない場合は作成します。

### 3. 設計書の生成

変更の規模に応じて、以下のいずれかのテンプレートで作成します:

- **小規模な変更** (バグ修正、小さな機能追加など): [`change-template.md`](./change-template.md) を使用
- **新規プロジェクト**: [`template.md`](./template.md) を使用

既存プロジェクトへの変更の場合は `apps/{project-name}/docs/changes/{change-id}.md` に作成し、新規プロジェクトの場合は `apps/{project-name}/docs/spec.md` に作成します。

### 4. pyproject.toml の生成（新規プロジェクトの場合のみ）

新規プロジェクトの場合、`apps/{project-name}/pyproject.toml` を以下のテンプレートで作成します:

```toml
[project]
name = "{project-name}"
version = "0.1.0"
description = "{プロジェクトの簡単な説明}"
requires-python = ">=3.11"
dependencies = [
    "httpx>=0.27.0",
    "pydantic>=2.0.0",
    "pydantic-settings>=2.0.0",
    "loguru>=0.7.0",
    "tenacity>=8.0.0",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.ruff]
target-version = "py311"
line-length = 100

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "B", "C4", "SIM"]
ignore = []

[tool.mypy]
strict = true
python_version = "3.11"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
```

### 5. 実行手順

1. 変更IDを確認（引数または質問）
2. 対象プロジェクトを確認（既存プロジェクト名または新規プロジェクト名）
3. 変更の規模を判断（小規模な変更 or 新規プロジェクト）
4. 変更の目的と内容をヒアリング
5. 適切なディレクトリ構造を作成
6. 変更の規模に応じた設計書を生成（ユーザーの回答を反映）
7. 新規プロジェクトの場合のみ pyproject.toml を生成
8. 完了メッセージと次のステップを表示

### 6. 完了メッセージ

設計書の作成が完了したら、変更の規模に応じて以下を表示します:

**小規模な変更の場合:**

```
✅ 変更設計書を作成しました

📄 作成されたファイル:
- apps/{プロジェクト名}/docs/changes/{変更ID}.md

🚀 次のステップ:

1. 設計書を編集して詳細を追記
2. 実装を開始する前に、設計書をレビュー
3. Phase 2 (Build & Prototype) に進む

詳細は docs/01_guidelines/spec-driven-development.md を参照してください。
```

**新規プロジェクトの場合:**

```
✅ プロジェクト仕様書を作成しました

📄 作成されたファイル:
- apps/{プロジェクト名}/docs/spec.md
- apps/{プロジェクト名}/pyproject.toml

🚀 次のステップ:

1. spec.md を編集して詳細を追記
2. Phase 2 (Build & Prototype) に進む:
   - Dify でワークフローを作成
   - n8n で外部連携を確認

詳細は docs/01_guidelines/spec-driven-development.md を参照してください。
```

## 重要な注意事項

- **変更の規模を判断**: まず変更の規模を判断し、適切なテンプレートを選択する
  - バグ修正、小さな機能追加 → `change-template.md`
  - 新規プロジェクト → `template.md`
- **対話的なアプローチ**: ユーザーから十分な情報を引き出すため、必要に応じて質問する
- **テンプレートの柔軟性**: 変更の性質に応じて、不要なセクションは省略可能
- **既存ファイルの確認**: ディレクトリやファイルが既に存在する場合は上書き確認を行う
- **Git 管理**: 作成後、ユーザーに git add を推奨する
- **小さく始める**: 小規模な変更は簡潔に記述し、必要に応じて後から詳細化する

## ヒアリング項目

変更の規模に応じて、以下の情報を収集します:

### 共通項目（すべての変更）

1. **変更ID**: ケバブケース（例: `add-error-retry`, `fix-timeout-issue`）
2. **対象プロジェクト**: 既存プロジェクト名または新規プロジェクト名（ケバブケース）
3. **変更の目的**: 何を解決するのか、どのような価値を提供するのか
4. **影響範囲**: どのコンポーネントに影響するか（n8n / Dify / Python / インフラなど）

### 小規模な変更の場合（追加項目）

5. **変更内容**: 具体的に何を変更するのか
6. **テスト方法**: どのように動作確認するか

### 新規プロジェクトの場合（追加項目）

5. **入力データ**: どこから何を取得するのか
6. **出力データ**: どこに何を出力するのか
7. **使用する AI モデル**: Claude Sonnet / Gemini Flash の選択理由
8. **主要なロジック**: どのような処理を行うのか
