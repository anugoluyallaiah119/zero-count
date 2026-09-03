package com.zerocount.server.room;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * A game room in LOBBY state (E2.5). Rooms are ephemeral pre-match state:
 * they live in the RoomStore (Redis in prod, in-memory in dev) and become a
 * Postgres `games` row only when the match actually starts (M1.x).
 *
 * Immutable snapshot semantics: mutator methods return a NEW Room; stores
 * persist the returned value. Callers never mutate in place.
 */
public record Room(
        String code,
        UUID hostId,
        GameSettings settings,
        List<Member> members,
        Instant createdAt) {

    public record GameSettings(int maxPlayers, int handSize, int target) {
        public GameSettings {
            if (maxPlayers < 2 || maxPlayers > 4)
                throw new IllegalArgumentException("maxPlayers must be 2–4");
            if (handSize != 7 && handSize != 13)
                throw new IllegalArgumentException("handSize must be 7 or 13");
            if (target != 100 && target != 200 && target != 500)
                throw new IllegalArgumentException("target must be 100, 200 or 500");
        }
    }

    public record Member(UUID userId, String displayName, boolean ready, Instant joinedAt) {}

    public Member member(UUID userId) {
        return members.stream().filter(m -> m.userId().equals(userId)).findFirst()
            .orElseThrow(() -> new IllegalArgumentException("user not in room"));
    }

    public boolean isFull() {
        return members.size() >= settings.maxPlayers();
    }

    public boolean isMember(UUID userId) {
        return members.stream().anyMatch(m -> m.userId().equals(userId));
    }

    public Room withMember(Member m) {
        if (isFull()) throw new IllegalStateException("room is full");
        if (isMember(m.userId())) throw new IllegalStateException("user already in room");
        List<Member> next = new ArrayList<>(members);
        next.add(m);
        return new Room(code, hostId, settings, List.copyOf(next), createdAt);
    }

    public Room withoutMember(UUID userId) {
        List<Member> next = members.stream()
            .filter(m -> !m.userId().equals(userId)).toList();
        // Host leaving: the earliest-joining remaining member becomes host.
        UUID nextHost = next.isEmpty() ? null : next.get(0).userId();
        return new Room(code, nextHost, settings, next, createdAt);
    }

    public Room withReady(UUID userId, boolean ready) {
        List<Member> next = members.stream()
            .map(m -> m.userId().equals(userId)
                ? new Member(m.userId(), m.displayName(), ready, m.joinedAt()) : m)
            .toList();
        return new Room(code, hostId, settings, next, createdAt);
    }

    /** Lobby is startable when full and everyone is ready (host included). */
    public boolean startable() {
        return isFull() && members.stream().allMatch(Member::ready);
    }
}
