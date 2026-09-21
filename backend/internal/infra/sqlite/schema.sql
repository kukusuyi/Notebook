CREATE TABLE `user` (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username VARCHAR(64) NOT NULL,
  email VARCHAR(255) NULL,
  password_hash VARCHAR(255) NULL,
  role TEXT NOT NULL DEFAULT 'user',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (username),
  UNIQUE (email)
);

CREATE TABLE file_record (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  question_id INTEGER NULL,
  storage_provider VARCHAR(32) NOT NULL DEFAULT 'oss',
  bucket_name VARCHAR(128) NOT NULL,
  object_key VARCHAR(512) NOT NULL,
  file_name VARCHAR(255) NOT NULL,
  file_url VARCHAR(1024) NOT NULL,
  file_size INTEGER NULL,
  mime_type VARCHAR(128) NULL,
  file_type TEXT NOT NULL DEFAULT 'image',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (object_key),
  CONSTRAINT fk_file_user
    FOREIGN KEY (user_id) REFERENCES `user` (id)
);

CREATE TABLE wrong_question (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  subject VARCHAR(64) NOT NULL,
  chapter VARCHAR(128) NULL,
  question_core TEXT NOT NULL,
  standard_solution TEXT NULL,
  wrong_solution TEXT NULL,
  semantic_summary TEXT NOT NULL,
  mistake_summary TEXT NULL,
  difficulty_level INTEGER NULL,
  mastery_status TEXT NOT NULL DEFAULT 'unmastered',
  source_type TEXT NOT NULL DEFAULT 'manual',
  source_image_id INTEGER NULL,
  source_image_url VARCHAR(1024) NULL,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  deleted_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_wq_difficulty
    CHECK (difficulty_level IS NULL OR difficulty_level BETWEEN 1 AND 5),
  CONSTRAINT fk_wq_user
    FOREIGN KEY (user_id) REFERENCES `user` (id),
  CONSTRAINT fk_wq_source_image
    FOREIGN KEY (source_image_id) REFERENCES file_record (id)
);



CREATE TABLE tag (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  tag_name VARCHAR(128) NOT NULL,
  tag_type TEXT NOT NULL,
  usage_count INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  deleted_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (user_id, tag_type, tag_name),
  CONSTRAINT fk_tag_user
    FOREIGN KEY (user_id) REFERENCES `user` (id)
);

CREATE TABLE wrong_question_tag (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  question_id INTEGER NOT NULL,
  tag_id INTEGER NOT NULL,
  tag_type TEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (question_id, tag_id),
  CONSTRAINT fk_wqt_question
    FOREIGN KEY (question_id) REFERENCES wrong_question (id),
  CONSTRAINT fk_wqt_tag
    FOREIGN KEY (tag_id) REFERENCES tag (id)
);

CREATE TABLE ocr_record (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  image_id INTEGER NULL,
  image_url VARCHAR(1024) NOT NULL,
  raw_text MEDIUMTEXT NULL,
  output_question_json JSON NULL,
  status TEXT NOT NULL,
  error_message TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_ocr_user
    FOREIGN KEY (user_id) REFERENCES `user` (id),
  CONSTRAINT fk_ocr_image
    FOREIGN KEY (image_id) REFERENCES file_record (id)
);

CREATE TABLE ai_analysis_record (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  question_id INTEGER NULL,
  provider_name VARCHAR(128) NOT NULL,
  model_name VARCHAR(128) NOT NULL,
  analysis_type TEXT NOT NULL,
  input_question_json JSON NOT NULL,
  output_tags_json JSON NULL,
  semantic_summary TEXT NULL,
  mistake_summary TEXT NULL,
  status TEXT NOT NULL,
  error_message TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_ai_user
    FOREIGN KEY (user_id) REFERENCES `user` (id),
  CONSTRAINT fk_ai_question
    FOREIGN KEY (question_id) REFERENCES wrong_question (id)
);

CREATE TABLE review_record (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,
  review_result TEXT NOT NULL,
  mastery_before TEXT NOT NULL,
  mastery_after TEXT NOT NULL,
  note TEXT NULL,
  reviewed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_review_user
    FOREIGN KEY (user_id) REFERENCES `user` (id),
  CONSTRAINT fk_review_question
    FOREIGN KEY (question_id) REFERENCES wrong_question (id)
);


CREATE INDEX idx_question_owner ON wrong_question(user_id,is_deleted,created_at DESC,id DESC);
CREATE INDEX idx_file_owner ON file_record(user_id);
CREATE INDEX idx_tag_owner ON tag(user_id,tag_type);
CREATE TABLE local_vector (question_id INTEGER NOT NULL REFERENCES wrong_question(id), vector_type TEXT NOT NULL, model TEXT NOT NULL, dimension INTEGER NOT NULL, content_hash TEXT NOT NULL, vector BLOB NOT NULL, PRIMARY KEY(question_id,vector_type));
CREATE TABLE vector_job (question_id INTEGER PRIMARY KEY REFERENCES wrong_question(id), revision INTEGER NOT NULL DEFAULT 1, status TEXT NOT NULL DEFAULT 'pending', attempts INTEGER NOT NULL DEFAULT 0, next_attempt INTEGER NOT NULL DEFAULT 0, error TEXT NOT NULL DEFAULT '');
CREATE TRIGGER queue_question_insert AFTER INSERT ON wrong_question BEGIN INSERT INTO vector_job(question_id) VALUES(NEW.id); END;
CREATE TRIGGER queue_question_update AFTER UPDATE ON wrong_question BEGIN INSERT INTO vector_job(question_id) VALUES(NEW.id) ON CONFLICT(question_id) DO UPDATE SET revision=revision+1,status='pending',attempts=0,next_attempt=0; DELETE FROM local_vector WHERE question_id=NEW.id; END;

CREATE TRIGGER tag_link_added AFTER INSERT ON wrong_question_tag BEGIN
 UPDATE tag SET usage_count=usage_count+1 WHERE id=NEW.tag_id AND EXISTS(SELECT 1 FROM wrong_question WHERE id=NEW.question_id AND is_deleted=0);
END;
CREATE TRIGGER tag_link_removed AFTER DELETE ON wrong_question_tag BEGIN
 UPDATE tag SET usage_count=MAX(usage_count-1,0) WHERE id=OLD.tag_id AND EXISTS(SELECT 1 FROM wrong_question WHERE id=OLD.question_id AND is_deleted=0);
END;
CREATE TRIGGER question_deleted AFTER UPDATE OF is_deleted ON wrong_question WHEN OLD.is_deleted=0 AND NEW.is_deleted=1 BEGIN
 UPDATE tag SET usage_count=MAX(usage_count-1,0) WHERE id IN (SELECT tag_id FROM wrong_question_tag WHERE question_id=NEW.id);
 DELETE FROM local_vector WHERE question_id=NEW.id;
END;
CREATE TRIGGER question_image_insert BEFORE INSERT ON wrong_question WHEN NEW.source_image_id IS NOT NULL BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM file_record WHERE id=NEW.source_image_id AND user_id=NEW.user_id) THEN RAISE(ABORT,'image owner mismatch') END;
END;
CREATE TRIGGER question_image_update BEFORE UPDATE OF source_image_id ON wrong_question WHEN NEW.source_image_id IS NOT NULL BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM file_record WHERE id=NEW.source_image_id AND user_id=NEW.user_id) THEN RAISE(ABORT,'image owner mismatch') END;
END;
CREATE TRIGGER bind_image_insert AFTER INSERT ON wrong_question BEGIN
 UPDATE file_record SET question_id=NEW.id WHERE id=NEW.source_image_id;
END;
CREATE TRIGGER bind_image_update AFTER UPDATE OF source_image_id ON wrong_question BEGIN
 UPDATE file_record SET question_id=NULL WHERE question_id=NEW.id;
 UPDATE file_record SET question_id=NEW.id WHERE id=NEW.source_image_id;
END;
