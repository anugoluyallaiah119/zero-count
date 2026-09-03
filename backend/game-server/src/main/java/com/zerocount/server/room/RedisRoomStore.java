package com.zerocount.server.room;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Duration;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * Redis room registry — production store (app.rooms.store=redis).
 *
 * One JSON document per room, key `room:{code}`, with TTL — Redis expires
 * abandoned lobbies natively. Multi-instance safe for V2.2 scale-out; atomic
 * lobby joins arrive with the match service (M1.x), where per-room locks live.
 */
@Component
@ConditionalOnProperty(name = "app.rooms.store", havingValue = "redis")
public class RedisRoomStore implements RoomStore {

    private static final String KEY_PREFIX = "room:";

    private final StringRedisTemplate redis;
    private final ObjectMapper json = new ObjectMapper().findAndRegisterModules();
    private final Duration ttl;

    public RedisRoomStore(StringRedisTemplate redis,
                          @Value("${app.rooms.ttl-hours:2}") long ttlHours) {
        this.redis = redis;
        this.ttl = Duration.ofHours(ttlHours);
    }

    @Override
    public void create(Room room) {
        Boolean ok = redis.opsForValue()
            .setIfAbsent(KEY_PREFIX + room.code(), write(room), ttl);
        if (!Boolean.TRUE.equals(ok))
            throw new IllegalStateException("room code collision: " + room.code());
    }

    @Override
    public Optional<Room> find(String code) {
        String raw = redis.opsForValue().get(KEY_PREFIX + code);
        if (raw == null) return Optional.empty();
        return Optional.of(read(raw));
    }

    @Override
    public void update(Room room) {
        if (find(room.code()).isEmpty())
            throw new IllegalStateException("room not found: " + room.code());
        redis.opsForValue().set(KEY_PREFIX + room.code(), write(room), ttl);
    }

    @Override
    public void delete(String code) {
        redis.delete(KEY_PREFIX + code);
    }

    private String write(Room room) {
        try {
            return json.writeValueAsString(room);
        } catch (Exception e) {
            throw new IllegalStateException("room serialization failed", e);
        }
    }

    private Room read(String raw) {
        try {
            return json.readValue(raw, Room.class);
        } catch (Exception e) {
            throw new IllegalStateException("room deserialization failed", e);
        }
    }
}
