package com.zerocount.server.room;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * In-memory room registry — dev/test default (single JVM). Applies the same
 * TTL semantics as the Redis store so behavior matches production.
 */
@Component
@ConditionalOnProperty(name = "app.rooms.store", havingValue = "memory", matchIfMissing = true)
public class InMemoryRoomStore implements RoomStore {

    private final Duration ttl;
    private final Map<String, Entry> rooms = new ConcurrentHashMap<>();

    private record Entry(Room room, Instant expiresAt) {}

    public InMemoryRoomStore(
            @org.springframework.beans.factory.annotation.Value("${app.rooms.ttl-hours:2}") long ttlHours) {
        this.ttl = Duration.ofHours(ttlHours);
    }

    @Override
    public synchronized void create(Room room) {
        purgeExpired();
        if (rooms.containsKey(room.code()))
            throw new IllegalStateException("room code collision: " + room.code());
        rooms.put(room.code(), new Entry(room, Instant.now().plus(ttl)));
    }

    @Override
    public Optional<Room> find(String code) {
        Entry e = rooms.get(code);
        if (e == null) return Optional.empty();
        if (Instant.now().isAfter(e.expiresAt())) {
            rooms.remove(code);
            return Optional.empty();
        }
        return Optional.of(e.room());
    }

    @Override
    public synchronized void update(Room room) {
        if (find(room.code()).isEmpty())
            throw new IllegalStateException("room not found: " + room.code());
        rooms.put(room.code(), new Entry(room, Instant.now().plus(ttl)));
    }

    @Override
    public synchronized void delete(String code) {
        rooms.remove(code);
    }

    private void purgeExpired() {
        Instant now = Instant.now();
        rooms.entrySet().removeIf(e -> now.isAfter(e.getValue().expiresAt()));
    }
}
