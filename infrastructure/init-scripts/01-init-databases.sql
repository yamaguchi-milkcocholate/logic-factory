-- n8n用データベースの作成
CREATE DATABASE n8n_db;

-- Dify用データベースの作成
CREATE DATABASE dify_db;

-- 権限の付与（必要に応じて）
GRANT ALL PRIVILEGES ON DATABASE n8n_db TO logicfactory;
GRANT ALL PRIVILEGES ON DATABASE dify_db TO logicfactory;
