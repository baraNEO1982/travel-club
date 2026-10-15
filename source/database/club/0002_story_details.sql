ALTER TABLE trips ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE trips ADD COLUMN last_edit_id TEXT;
ALTER TABLE photos ADD COLUMN caption TEXT NOT NULL DEFAULT '';
CREATE TABLE photo_comments(id TEXT PRIMARY KEY, photo_id TEXT NOT NULL REFERENCES photos(id) ON DELETE CASCADE, author_id TEXT NOT NULL REFERENCES members(id), body TEXT NOT NULL, created_at INTEGER NOT NULL);
CREATE INDEX photo_comments_photo ON photo_comments(photo_id,created_at);
