package com.zerocount.server.friend;

import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.zerocount.server.ws.WsAuthInterceptor;

/**
 * R1.1 — friends: request/accept/decline plus online presence.
 *
 * Friendships are directional rows (user_id → friend_id). A request creates
 * a 'pending' row; if the reverse pending row already exists, both sides
 * flip to 'accepted' (mutual-add). Presence = "has at least one live
 * WebSocket session" via {@link WsAuthInterceptor#sessionsOf}.
 */
@Service
public class FriendService {

    private final JdbcTemplate db;
    private final WsAuthInterceptor sessions;

    public FriendService(JdbcTemplate db, WsAuthInterceptor sessions) {
        this.db = db;
        this.sessions = sessions;
    }

    public record FriendEntry(UUID userId, String name, String avatar,
                              boolean online) {}
    public record FriendLists(List<FriendEntry> friends,
                              List<FriendEntry> incoming,
                              List<FriendEntry> outgoing) {}

    public FriendLists lists(UUID userId) {
        List<FriendEntry> accepted = db.query(
            "SELECT f.friend_id AS id, u.name, u.avatar FROM friendships f "
                + "JOIN users u ON u.id = f.friend_id "
                + "WHERE f.user_id = ? AND f.status = 'accepted'",
            (rs, n) -> new FriendEntry(
                rs.getObject("id", UUID.class), rs.getString("name"),
                rs.getString("avatar"), false),
            userId);
        // Presence is in-memory — decorate after the query.
        accepted = accepted.stream()
            .map(f -> new FriendEntry(f.userId(), f.name(), f.avatar(),
                !sessions.sessionsOf(f.userId()).isEmpty()))
            .toList();
        List<FriendEntry> incoming = pending(
            "WHERE f.friend_id = ? AND f.status = 'pending'", "user_id", userId);
        List<FriendEntry> outgoing = pending(
            "WHERE f.user_id = ? AND f.status = 'pending'", "friend_id", userId);
        return new FriendLists(accepted, incoming, outgoing);
    }

    private List<FriendEntry> pending(String where, String idColumn, UUID userId) {
        String other = idColumn.equals("user_id") ? "f.user_id" : "f.friend_id";
        return db.query(
            "SELECT " + other + " AS id, u.name, u.avatar FROM friendships f "
                + "JOIN users u ON u.id = " + other + " " + where,
            (rs, n) -> new FriendEntry(
                rs.getObject("id", UUID.class), rs.getString("name"),
                rs.getString("avatar"), false),
            userId);
    }

    /** Send a friend request. Mutual pending → both become accepted. */
    @Transactional
    public String request(UUID userId, UUID targetId) {
        if (userId.equals(targetId)) {
            throw new IllegalArgumentException("cannot friend yourself");
        }
        ensureUser(targetId);
        String existing = statusOf(userId, targetId);
        if ("accepted".equals(existing)) return "already_friends";
        if ("pending".equals(existing)) return "already_requested";
        String reverse = statusOf(targetId, userId);
        if ("pending".equals(reverse)) {
            db.update("UPDATE friendships SET status = 'accepted' "
                    + "WHERE user_id = ? AND friend_id = ?", targetId, userId);
            db.update("INSERT INTO friendships (user_id, friend_id, status) "
                    + "VALUES (?,?,'accepted')", userId, targetId);
            return "accepted";
        }
        db.update("INSERT INTO friendships (user_id, friend_id, status) "
                + "VALUES (?,?,'pending')", userId, targetId);
        return "requested";
    }

    /** Accept an incoming request. */
    @Transactional
    public void accept(UUID userId, UUID fromId) {
        int n = db.update("UPDATE friendships SET status = 'accepted' "
                + "WHERE user_id = ? AND friend_id = ? AND status = 'pending'",
            fromId, userId);
        if (n == 0) throw new IllegalArgumentException("no pending request");
        db.update("INSERT INTO friendships (user_id, friend_id, status) "
                + "VALUES (?,?,'accepted') "
                + "ON CONFLICT (user_id, friend_id) DO UPDATE SET status = 'accepted'",
            userId, fromId);
    }

    /** Decline/remove any relation in either direction. */
    @Transactional
    public void remove(UUID userId, UUID otherId) {
        db.update("DELETE FROM friendships WHERE user_id = ? AND friend_id = ?",
            userId, otherId);
        db.update("DELETE FROM friendships WHERE user_id = ? AND friend_id = ?",
            otherId, userId);
    }

    private String statusOf(UUID from, UUID to) {
        List<String> s = db.queryForList(
            "SELECT status FROM friendships WHERE user_id = ? AND friend_id = ?",
            String.class, from, to);
        return s.isEmpty() ? null : s.get(0);
    }

    private void ensureUser(UUID userId) {
        Integer n = db.queryForObject("SELECT COUNT(*) FROM users WHERE id = ?",
            Integer.class, userId);
        if (n == null || n == 0) throw new IllegalArgumentException("user not found");
    }

    /** Name search for "add friend" (R1.1) — prefix/substring, max 20. */
    public List<FriendEntry> search(String q, UUID exclude) {
        return db.query(
            "SELECT id, name, avatar FROM users "
                + "WHERE name IS NOT NULL AND LOWER(name) LIKE LOWER(?) "
                + "AND id <> ? ORDER BY name LIMIT 20",
            (rs, n) -> new FriendEntry(
                rs.getObject("id", UUID.class), rs.getString("name"),
                rs.getString("avatar"), false),
            "%" + q.replace("%", "").replace("_", "") + "%", exclude);
    }
}
