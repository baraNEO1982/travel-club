ALTER TABLE members ADD COLUMN verified_email TEXT;
CREATE UNIQUE INDEX members_verified_email ON members(verified_email) WHERE verified_email IS NOT NULL;
CREATE TABLE email_tokens(hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE, email TEXT NOT NULL, purpose TEXT NOT NULL CHECK(purpose IN ('verify','reset')), expires INTEGER NOT NULL, used_at INTEGER);
CREATE INDEX email_tokens_user ON email_tokens(user_id,purpose);
CREATE TRIGGER password_changed AFTER UPDATE OF password ON members BEGIN
 DELETE FROM sessions WHERE user_id=NEW.id;
 UPDATE email_tokens SET used_at=unixepoch() WHERE user_id=NEW.id AND used_at IS NULL;
END;
CREATE TRIGGER recovery_email_changed AFTER UPDATE OF verified_email ON members BEGIN
 UPDATE email_tokens SET used_at=unixepoch() WHERE user_id=NEW.id AND used_at IS NULL;
END;
