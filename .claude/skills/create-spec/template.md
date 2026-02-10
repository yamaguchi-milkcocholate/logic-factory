# {PROJECT_NAME} - 仕様書

> 作成日: {DATE}

## 1. Project Vision

### 解決する課題

{PROBLEM}

### 提供する価値

{VALUE}

### 成功定義 (Definition of Done)

以下の条件を満たした時点で「完成（非介在運用可能）」と見なす:

- [ ] ワークフローが n8n で正常に動作する
- [ ] エラーハンドリングが実装されている
- [ ] ログ出力が適切に行われている
- [ ] 本番環境へのデプロイが完了している
- [ ] {プロジェクト固有の成功条件}

---

## 2. Input/Output

### Input

| 項目         | 形式     | ソース   | 備考    |
| :----------- | :------- | :------- | :------ |
| {INPUT_NAME} | {FORMAT} | {SOURCE} | {NOTES} |

### Output

| 項目          | 形式     | 出力先        | 備考    |
| :------------ | :------- | :------------ | :------ |
| {OUTPUT_NAME} | {FORMAT} | {DESTINATION} | {NOTES} |

---

## 3. Logic Definition

### 3.1 解析フェーズ (Dify)

#### AI モデル選択

- **主要解析**: {MODEL_PRIMARY}（{REASON_PRIMARY}）
- **補助処理**: {MODEL_SECONDARY}（{REASON_SECONDARY}）

#### 判定基準・スコアリングロジック

{LOGIC_CRITERIA}

#### プロンプト設計

```
{PROMPT_DESIGN}
```

### 3.2 実行フェーズ (Python)

#### アルゴリズム

{ALGORITHM}

#### 使用ライブラリ

- **HTTP クライアント**: `httpx`
- **データバリデーション**: `Pydantic`
- **ロギング**: `loguru`
- **設定管理**: `pydantic-settings`
- {ADDITIONAL_LIBRARIES}

#### 冪等性の担保

{IDEMPOTENCY}

---

## 4. Infrastructure

### 4.1 共通基盤の利用

#### n8n ワークフロー

- **ワークフロー名**: `[{PROJECT_NAME}] {WORKFLOW_NAME}`
- **トリガー**: {TRIGGER_TYPE}
- **エラーハンドリング**: `shared/` のテンプレートを使用

#### Dify

- **使用ワークフロー/アプリ**: {DIFY_WORKFLOW}
- **API キー管理**: 本番用と開発用を分離
- **プロンプトバージョン管理**: Git で管理

### 4.2 GCP リソース

| リソース       | 用途            | 備考          |
| :------------- | :-------------- | :------------ |
| Cloud Run Jobs | {GCP_USAGE}     | {GCP_NOTES}   |
| Cloud Storage  | {STORAGE_USAGE} | {BUCKET_NAME} |

### 4.3 ストレージ戦略

- **構造化データ**: PostgreSQL に保存
- **キャッシュ**: Redis を使用
- **Blob データ**: `shared/data/` または Cloud Storage

---

## 5. Implementation Plan

### Phase 1: Spec (定義) - 完了

✓ この仕様書の作成

### Phase 2: Build & Prototype (推論構築)

#### タスク

- [ ] Dify でプロンプトエンジニアリングを実施
- [ ] n8n で外部 API との接続を確認
- [ ] データの疎通確認（エンドツーエンド）

#### 検証項目

- [ ] {VALIDATION_1}
- [ ] {VALIDATION_2}

### Phase 3: Automate & Solidify (自動化・堅牢化)

#### タスク

- [ ] `apps/{PROJECT_NAME}/src/` に Python スクリプトを実装
- [ ] Pydantic モデルでデータバリデーション実装
- [ ] ログ出力の実装（推論プロセスを記録）
- [ ] リトライ戦略の実装（tenacity 使用）
- [ ] n8n から Python スクリプトを呼び出すインターフェース確定

#### 品質保証

- [ ] `ruff check` でリントエラーなし
- [ ] `ruff format` で整形済み
- [ ] `mypy --strict` で型チェックパス
- [ ] エラーハンドリングのテスト完了

### Phase 4: Deploy & Forget (展開・非介在化)

#### タスク

- [ ] Coolify 経由で GCP VM へデプロイ
- [ ] Cloud Scheduler で定期実行設定
- [ ] n8n エラー通知フローを有効化
- [ ] 監視・ロギングの確認

#### 完成条件

- [ ] 人間の介在なしで正常に動作
- [ ] エラー発生時のみ通知が届く
- [ ] ログから推論プロセスが追跡可能

---

## 6. Notes & Considerations

### 技術的な注意事項

- {TECHNICAL_NOTES}

### ビジネス上の制約

- {BUSINESS_CONSTRAINTS}

### 将来的な拡張

- {FUTURE_EXTENSIONS}

---

## Appendix

### 参考資料

- [Python Coding Standards](../../docs/01_guidelines/code.md)
- [共通基盤利用ルール](../../docs/01_guidelines/tool.md)
- [Infrastructure Specification](../../docs/02_architecture/infrastructure.md)

### 用語集

| 用語     | 定義           |
| :------- | :------------- |
| {TERM_1} | {DEFINITION_1} |
