CREATE DATABASE IF NOT EXISTS wrong_question_book
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE wrong_question_book;

CREATE TABLE `user` (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '用户ID',
  username VARCHAR(64) NOT NULL COMMENT '用户名',
  email VARCHAR(255) NULL COMMENT '邮箱',
  password_hash VARCHAR(255) NULL COMMENT '密码哈希',
  role ENUM('user', 'admin') NOT NULL DEFAULT 'user' COMMENT '角色',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_user_username (username),
  UNIQUE KEY uk_user_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

CREATE TABLE file_record (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '文件ID',
  user_id BIGINT UNSIGNED NOT NULL COMMENT '所属用户',
  question_id BIGINT UNSIGNED NULL COMMENT '绑定的错题ID',
  storage_provider VARCHAR(32) NOT NULL DEFAULT 'oss' COMMENT '存储服务',
  bucket_name VARCHAR(128) NOT NULL COMMENT 'OSS bucket 名称',
  object_key VARCHAR(512) NOT NULL COMMENT 'OSS 对象 key',
  file_name VARCHAR(255) NOT NULL COMMENT '原始文件名',
  file_url VARCHAR(1024) NOT NULL COMMENT '文件访问地址',
  file_size BIGINT UNSIGNED NULL COMMENT '文件大小',
  mime_type VARCHAR(128) NULL COMMENT 'MIME 类型',
  file_type ENUM('image', 'other') NOT NULL DEFAULT 'image' COMMENT '文件类型',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (id),
  KEY idx_file_user_id (user_id),
  KEY idx_file_question_id (question_id),
  UNIQUE KEY uk_file_object_key (object_key),
  CONSTRAINT fk_file_user
    FOREIGN KEY (user_id) REFERENCES `user` (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='图片文件记录表';

CREATE TABLE wrong_question (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '错题ID',
  user_id BIGINT UNSIGNED NOT NULL COMMENT '所属用户',
  subject VARCHAR(64) NOT NULL COMMENT '学科',
  chapter VARCHAR(128) NULL COMMENT '章节',
  question_core TEXT NOT NULL COMMENT '题目主干 LaTeX / 文本',
  standard_solution TEXT NULL COMMENT '标准题解',
  wrong_solution TEXT NULL COMMENT '学生错误过程 / 错误思路',
  semantic_summary TEXT NOT NULL COMMENT 'AI 生成的题目语义摘要',
  mistake_summary TEXT NULL COMMENT 'AI 生成的错因摘要',
  difficulty_level TINYINT UNSIGNED NULL COMMENT '难度等级 1-5',
  mastery_status ENUM('unmastered', 'learning', 'mastered') NOT NULL DEFAULT 'unmastered' COMMENT '掌握状态',
  source_type ENUM('manual', 'image', 'import') NOT NULL DEFAULT 'manual' COMMENT '来源',
  source_image_id BIGINT UNSIGNED NULL COMMENT '原图文件ID',
  source_image_url VARCHAR(1024) NULL COMMENT '原图 OSS 地址',
  is_deleted TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否删除错题',
  deleted_at DATETIME NULL COMMENT '错题删除时间',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (id),
  KEY idx_wq_user_id (user_id),
  KEY idx_wq_subject (subject),
  KEY idx_wq_chapter (chapter),
  KEY idx_wq_mastery_status (mastery_status),
  KEY idx_wq_source_image_id (source_image_id),
  KEY idx_wq_created_at (created_at),
  CONSTRAINT chk_wq_difficulty
    CHECK (difficulty_level IS NULL OR difficulty_level BETWEEN 1 AND 5),
  CONSTRAINT fk_wq_user
    FOREIGN KEY (user_id) REFERENCES `user` (id),
  CONSTRAINT fk_wq_source_image
    FOREIGN KEY (source_image_id) REFERENCES file_record (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='错题主表';

ALTER TABLE file_record
  ADD CONSTRAINT fk_file_question
  FOREIGN KEY (question_id) REFERENCES wrong_question (id);

CREATE TABLE tag (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '标签ID',
  user_id BIGINT UNSIGNED NOT NULL COMMENT '所属用户',
  tag_name VARCHAR(128) NOT NULL COMMENT '标签名称',
  tag_type ENUM('knowledge_point', 'problem_type', 'method', 'mistake_reason') NOT NULL COMMENT '标签类型',
  usage_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '使用次数',
  is_active TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否启用',
  deleted_at DATETIME NULL COMMENT '删除时间',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_tag_user_type_name (user_id, tag_type, tag_name),
  KEY idx_tag_user_type (user_id, tag_type),
  KEY idx_tag_is_active (is_active),
  CONSTRAINT fk_tag_user
    FOREIGN KEY (user_id) REFERENCES `user` (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='标签定义表';

CREATE TABLE wrong_question_tag (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '关联ID',
  question_id BIGINT UNSIGNED NOT NULL COMMENT '错题ID',
  tag_id BIGINT UNSIGNED NOT NULL COMMENT '标签ID',
  tag_type ENUM('knowledge_point', 'problem_type', 'method', 'mistake_reason') NOT NULL COMMENT '标签类型冗余',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_wq_tag (question_id, tag_id),
  KEY idx_wqt_tag_id (tag_id),
  KEY idx_wqt_tag_type (tag_type),
  CONSTRAINT fk_wqt_question
    FOREIGN KEY (question_id) REFERENCES wrong_question (id),
  CONSTRAINT fk_wqt_tag
    FOREIGN KEY (tag_id) REFERENCES tag (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='错题标签关联表';

CREATE TABLE question_vector (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '映射ID',
  question_id BIGINT UNSIGNED NOT NULL COMMENT '错题ID',
  vector_type ENUM('semantic', 'mistake') NOT NULL COMMENT '向量类型',
  collection_name VARCHAR(128) NOT NULL COMMENT 'Qdrant collection 名称',
  vector_id VARCHAR(64) NOT NULL COMMENT 'Qdrant point UUID',
  embedding_model VARCHAR(128) NOT NULL COMMENT 'Embedding 模型',
  content_hash CHAR(64) NOT NULL COMMENT '摘要文本 hash',
  status ENUM('active', 'deleted', 'failed') NOT NULL DEFAULT 'active' COMMENT '状态',
  active_vector_type VARCHAR(16)
    GENERATED ALWAYS AS (
      CASE WHEN status = 'active' THEN vector_type ELSE NULL END
    ) STORED,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_qv_active_type (question_id, active_vector_type),
  UNIQUE KEY uk_qv_collection_vector (collection_name, vector_id),
  KEY idx_qv_question_id (question_id),
  KEY idx_qv_content_hash (content_hash),
  KEY idx_qv_status (status),
  CONSTRAINT fk_qv_question
    FOREIGN KEY (question_id) REFERENCES wrong_question (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='向量映射表';

CREATE TABLE ocr_record (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'OCR记录ID',
  user_id BIGINT UNSIGNED NOT NULL COMMENT '所属用户',
  image_id BIGINT UNSIGNED NULL COMMENT '图片文件ID',
  image_url VARCHAR(1024) NOT NULL COMMENT 'OSS 图片地址',
  raw_text MEDIUMTEXT NULL COMMENT 'OCR 原始文本',
  output_question_json JSON NULL COMMENT '识别出的标准错题 JSON',
  status ENUM('success', 'failed') NOT NULL COMMENT '处理状态',
  error_message TEXT NULL COMMENT '失败原因',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (id),
  KEY idx_ocr_user_id (user_id),
  KEY idx_ocr_image_id (image_id),
  KEY idx_ocr_status (status),
  KEY idx_ocr_created_at (created_at),
  CONSTRAINT fk_ocr_user
    FOREIGN KEY (user_id) REFERENCES `user` (id),
  CONSTRAINT fk_ocr_image
    FOREIGN KEY (image_id) REFERENCES file_record (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='OCR处理记录表';

CREATE TABLE ai_analysis_record (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'AI分析记录ID',
  user_id BIGINT UNSIGNED NOT NULL COMMENT '所属用户',
  question_id BIGINT UNSIGNED NULL COMMENT '错题ID',
  provider_name VARCHAR(128) NOT NULL COMMENT '模型厂商标识',
  model_name VARCHAR(128) NOT NULL COMMENT '调用的模型名称',
  analysis_type ENUM('analyze_wrong_question') NOT NULL COMMENT '分析类型',
  input_question_json JSON NOT NULL COMMENT '输入的标准错题 JSON',
  output_tags_json JSON NULL COMMENT 'AI 输出标签 JSON',
  semantic_summary TEXT NULL COMMENT 'AI 输出题目语义摘要',
  mistake_summary TEXT NULL COMMENT 'AI 输出错因摘要',
  status ENUM('success', 'failed') NOT NULL COMMENT '处理状态',
  error_message TEXT NULL COMMENT '失败原因',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (id),
  KEY idx_ai_user_id (user_id),
  KEY idx_ai_question_id (question_id),
  KEY idx_ai_provider_name (provider_name),
  KEY idx_ai_model_name (model_name),
  KEY idx_ai_status (status),
  KEY idx_ai_created_at (created_at),
  CONSTRAINT fk_ai_user
    FOREIGN KEY (user_id) REFERENCES `user` (id),
  CONSTRAINT fk_ai_question
    FOREIGN KEY (question_id) REFERENCES wrong_question (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='AI分析记录表';

CREATE TABLE review_record (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '复习记录ID',
  user_id BIGINT UNSIGNED NOT NULL COMMENT '所属用户',
  question_id BIGINT UNSIGNED NOT NULL COMMENT '错题ID',
  review_result ENUM('remembered', 'partial', 'forgotten') NOT NULL COMMENT '复习结果',
  mastery_before ENUM('unmastered', 'learning', 'mastered') NOT NULL COMMENT '复习前掌握状态',
  mastery_after ENUM('unmastered', 'learning', 'mastered') NOT NULL COMMENT '复习后掌握状态',
  note TEXT NULL COMMENT '复习备注',
  reviewed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '复习时间',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (id),
  KEY idx_review_user_id (user_id),
  KEY idx_review_question_id (question_id),
  KEY idx_review_reviewed_at (reviewed_at),
  CONSTRAINT fk_review_user
    FOREIGN KEY (user_id) REFERENCES `user` (id),
  CONSTRAINT fk_review_question
    FOREIGN KEY (question_id) REFERENCES wrong_question (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='复习记录表';

-- INSERT INTO `user` (id, username, role)
-- VALUES (1, 'default_user', 'user')
-- ON DUPLICATE KEY UPDATE username = username;
