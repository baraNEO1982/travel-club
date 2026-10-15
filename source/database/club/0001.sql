CREATE TABLE members(id TEXT PRIMARY KEY, username TEXT NOT NULL UNIQUE, name TEXT NOT NULL, password TEXT NOT NULL, invite_hash TEXT NOT NULL UNIQUE REFERENCES invitations(hash), active INTEGER NOT NULL DEFAULT 1, created_at INTEGER NOT NULL);
CREATE TABLE invitations(hash TEXT PRIMARY KEY, creator TEXT REFERENCES members(id), expires INTEGER NOT NULL, used_by TEXT UNIQUE REFERENCES members(id));
CREATE TABLE sessions(hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE, expires INTEGER NOT NULL);
CREATE INDEX sessions_expiry ON sessions(expires);
CREATE TABLE trips(id TEXT PRIMARY KEY, author_id TEXT NOT NULL REFERENCES members(id), title TEXT NOT NULL, place TEXT NOT NULL, body TEXT NOT NULL, created_at INTEGER NOT NULL);
CREATE TABLE photos(id TEXT PRIMARY KEY, trip_id TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE, size INTEGER NOT NULL, position INTEGER NOT NULL, ready INTEGER NOT NULL DEFAULT 0);
CREATE INDEX photos_trip ON photos(trip_id);
CREATE TABLE comments(id TEXT PRIMARY KEY, trip_id TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE, author_id TEXT NOT NULL REFERENCES members(id), body TEXT NOT NULL, created_at INTEGER NOT NULL);
CREATE INDEX comments_trip ON comments(trip_id,created_at);
CREATE TABLE rate_limits(key TEXT PRIMARY KEY, count INTEGER NOT NULL, expires INTEGER NOT NULL);
CREATE TABLE storage_budget(id INTEGER PRIMARY KEY CHECK(id=1), bytes INTEGER NOT NULL DEFAULT 0 CHECK(bytes <= 900000000));
INSERT INTO storage_budget(id) VALUES(1);
CREATE TRIGGER reserve_photo BEFORE INSERT ON photos BEGIN UPDATE storage_budget SET bytes=bytes+NEW.size WHERE id=1; END;
CREATE TRIGGER release_photo AFTER DELETE ON photos BEGIN UPDATE storage_budget SET bytes=bytes-OLD.size WHERE id=1; END;
CREATE TRIGGER require_invitation BEFORE INSERT ON members WHEN NOT EXISTS(SELECT 1 FROM invitations i WHERE i.hash=NEW.invite_hash AND i.used_by IS NULL AND i.expires>unixepoch() AND (i.creator IS NULL OR EXISTS(SELECT 1 FROM members m WHERE m.id=i.creator AND m.active=1))) BEGIN
 SELECT RAISE(ABORT,'invalid_invitation');
END;
CREATE TRIGGER consume_invitation AFTER INSERT ON members BEGIN
 UPDATE invitations SET used_by=NEW.id WHERE hash=NEW.invite_hash;
END;
