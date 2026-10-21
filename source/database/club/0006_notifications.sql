CREATE TABLE trip_notifications(id TEXT PRIMARY KEY,trip_id TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,user_id TEXT NOT NULL REFERENCES members(id),created_at INTEGER NOT NULL,read_at INTEGER,UNIQUE(trip_id,user_id));
CREATE INDEX trip_notifications_user ON trip_notifications(user_id,created_at);
CREATE TRIGGER notify_trip_member AFTER INSERT ON trip_members BEGIN
 INSERT INTO trip_notifications(id,trip_id,user_id,created_at) VALUES(lower(hex(randomblob(16))),NEW.trip_id,NEW.user_id,unixepoch()) ON CONFLICT(trip_id,user_id) DO UPDATE SET id=excluded.id,created_at=excluded.created_at,read_at=NULL;
END;
CREATE TRIGGER clear_trip_notification AFTER DELETE ON trip_members BEGIN
 DELETE FROM trip_notifications WHERE trip_id=OLD.trip_id AND user_id=OLD.user_id;
END;
INSERT INTO trip_notifications(id,trip_id,user_id,created_at) SELECT lower(hex(randomblob(16))),trip_id,user_id,unixepoch() FROM trip_members WHERE user_id!=(SELECT author_id FROM trips WHERE id=trip_id);
