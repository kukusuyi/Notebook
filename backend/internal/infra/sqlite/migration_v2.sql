DROP TRIGGER queue_question_update;
CREATE TRIGGER queue_question_update AFTER UPDATE OF question_core,standard_solution,wrong_solution,semantic_summary,mistake_summary,subject,chapter,is_deleted ON wrong_question BEGIN
 INSERT INTO vector_job(question_id) VALUES(NEW.id) ON CONFLICT(question_id) DO UPDATE SET revision=revision+1,status='pending',attempts=0,next_attempt=0;
 DELETE FROM local_vector WHERE question_id=NEW.id;
END;
ALTER TABLE wrong_question ADD COLUMN search_text TEXT NOT NULL DEFAULT '';
ALTER TABLE tag ADD COLUMN search_text TEXT NOT NULL DEFAULT '';
UPDATE wrong_question SET search_text=search_normalize(question_core || char(10) || semantic_summary || char(10) || coalesce(wrong_solution,''));
UPDATE tag SET search_text=search_normalize(tag_name);
CREATE TRIGGER question_search_insert AFTER INSERT ON wrong_question BEGIN
 UPDATE wrong_question SET search_text=search_normalize(new.question_core || char(10) || new.semantic_summary || char(10) || coalesce(new.wrong_solution,'')) WHERE id=new.id;
END;
CREATE TRIGGER question_search_update AFTER UPDATE OF question_core,semantic_summary,wrong_solution ON wrong_question BEGIN
 UPDATE wrong_question SET search_text=search_normalize(new.question_core || char(10) || new.semantic_summary || char(10) || coalesce(new.wrong_solution,'')) WHERE id=new.id;
END;
CREATE TRIGGER tag_search_insert AFTER INSERT ON tag BEGIN
 UPDATE tag SET search_text=search_normalize(new.tag_name) WHERE id=new.id;
END;
CREATE TRIGGER tag_search_update AFTER UPDATE OF tag_name ON tag BEGIN
 UPDATE tag SET search_text=search_normalize(new.tag_name) WHERE id=new.id;
END;
CREATE TABLE review_plan (
 question_id INTEGER PRIMARY KEY REFERENCES wrong_question(id),
 streak INTEGER NOT NULL DEFAULT 0,
 due_at INTEGER NOT NULL,
 last_reviewed_at INTEGER NOT NULL DEFAULT 0
);
INSERT INTO review_plan(question_id,due_at) SELECT id, CASE WHEN mastery_status='mastered' THEN unixepoch()+604800 ELSE 0 END FROM wrong_question WHERE is_deleted=0;
CREATE TRIGGER question_plan_insert AFTER INSERT ON wrong_question BEGIN
 INSERT INTO review_plan(question_id,due_at) VALUES(new.id,CASE WHEN new.mastery_status='mastered' THEN unixepoch()+604800 ELSE 0 END);
END;
CREATE TABLE review_session (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 user_id INTEGER NOT NULL REFERENCES user(id),
 requested_count INTEGER NOT NULL,
 created_at INTEGER NOT NULL
);
CREATE TABLE review_session_item (
 session_id INTEGER NOT NULL REFERENCES review_session(id),
 question_id INTEGER NOT NULL REFERENCES wrong_question(id),
 position INTEGER NOT NULL,
 result TEXT NOT NULL DEFAULT '',
 PRIMARY KEY(session_id,question_id)
);
ALTER TABLE review_record ADD COLUMN session_id INTEGER REFERENCES review_session(id);
ALTER TABLE review_record ADD COLUMN submission_id TEXT;
ALTER TABLE review_record ADD COLUMN next_due_at INTEGER;
CREATE UNIQUE INDEX review_submission ON review_record(user_id,submission_id);
CREATE INDEX review_due ON review_plan(due_at);
CREATE INDEX review_sessions_owner ON review_session(user_id,created_at);
