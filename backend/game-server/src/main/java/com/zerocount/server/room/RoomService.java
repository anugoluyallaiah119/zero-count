package com.zerocount.server.room;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;

/**
 * Room lifecycle (E2.5): create → join → ready/leave, over the pluggable
 * RoomStore. All rules enforced here — controllers stay thin.
 */
@Service
public class RoomService {

    /** Unambiguous alphabet: no 0/O, 1/I/L — codes are read aloud/typed. */
    private static final char[] CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".toCharArray();
    private static final int CODE_LEN = 6;
    private static final int CODE_ATTEMPTS = 10;

    private final RoomStore store;
    private final SecureRandom random = new SecureRandom();

    public RoomService(RoomStore store) {
        this.store = store;
    }

    /** Host creates a room and is its first member (not yet ready). */
    public Room create(UUID hostId, String hostName, Room.GameSettings settings) {
        for (int i = 0; i < CODE_ATTEMPTS; i++) {
            String code = newCode();
            Room room = new Room(code, hostId, settings,
                List.of(new Room.Member(hostId, displayOrDefault(hostName), false, Instant.now())),
                Instant.now());
            try {
                store.create(room);
                return room;
            } catch (IllegalStateException collision) {
                // code collision — try another
            }
        }
        throw new IllegalStateException("could not allocate a room code");
    }

    public Room join(String code, UUID userId, String displayName) {
        Room room = mustFind(code);
        Room updated = room.withMember(
            new Room.Member(userId, displayOrDefault(displayName), false, Instant.now()));
        store.update(updated);
        return updated;
    }

    public Room setReady(String code, UUID userId, boolean ready) {
        Room room = mustFind(code);
        Room updated = room.withReady(userId, ready);
        store.update(updated);
        return updated;
    }

    /** Leave; empty rooms are deleted. Returns null when the room is gone. */
    public Room leave(String code, UUID userId) {
        Room room = mustFind(code);
        Room updated = room.withoutMember(userId);
        if (updated.members().isEmpty()) {
            store.delete(code);
            return null;
        }
        store.update(updated);
        return updated;
    }

    public Room get(String code) {
        return mustFind(code);
    }

    private Room mustFind(String code) {
        if (code == null || code.isBlank())
            throw new IllegalArgumentException("room code is required");
        return store.find(code.toUpperCase().trim())
            .orElseThrow(() -> new RoomNotFoundException("room not found"));
    }

    private String newCode() {
        StringBuilder sb = new StringBuilder(CODE_LEN);
        for (int i = 0; i < CODE_LEN; i++)
            sb.append(CODE_ALPHABET[random.nextInt(CODE_ALPHABET.length)]);
        return sb.toString();
    }

    private static String displayOrDefault(String name) {
        return (name == null || name.isBlank()) ? "Player" : name.trim();
    }

    /** 404-worthy: the room code does not exist (or expired). */
    public static class RoomNotFoundException extends RuntimeException {
        public RoomNotFoundException(String message) { super(message); }
    }
}
