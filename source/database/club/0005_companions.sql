ALTER TABLE photos ADD COLUMN author_id TEXT REFERENCES members(id);
UPDATE photos SET author_id=(SELECT author_id FROM trips WHERE trips.id=photos.trip_id);
CREATE TABLE trip_members(trip_id TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,user_id TEXT NOT NULL REFERENCES members(id),PRIMARY KEY(trip_id,user_id));
CREATE TABLE trip_notes(id TEXT PRIMARY KEY,trip_id TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,author_id TEXT NOT NULL REFERENCES members(id),body TEXT NOT NULL,version INTEGER NOT NULL DEFAULT 1,created_at INTEGER NOT NULL);
CREATE TABLE trip_invites(hash TEXT PRIMARY KEY REFERENCES invitations(hash),trip_id TEXT NOT NULL REFERENCES trips(id),claimed_by TEXT REFERENCES members(id));
CREATE TRIGGER trip_invite_claim AFTER UPDATE OF claimed_by ON trip_invites WHEN NEW.claimed_by IS NOT NULL AND OLD.claimed_by IS NULL BEGIN
 INSERT OR IGNORE INTO trip_members(trip_id,user_id) VALUES(NEW.trip_id,NEW.claimed_by);
END;
CREATE TRIGGER trip_registration AFTER UPDATE OF used_by ON invitations WHEN NEW.used_by IS NOT NULL BEGIN
 UPDATE trip_invites SET claimed_by=NEW.used_by WHERE hash=NEW.hash AND claimed_by IS NULL;
END;
CREATE TRIGGER reject_claimed_trip_invite BEFORE INSERT ON members WHEN EXISTS(SELECT 1 FROM trip_invites WHERE hash=NEW.invite_hash AND claimed_by IS NOT NULL) BEGIN
 SELECT RAISE(ABORT,'invalid_invitation');
END;
