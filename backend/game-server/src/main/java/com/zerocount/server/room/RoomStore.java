package com.zerocount.server.room;

import java.util.Optional;

/**
 * Lobby registry (E2.5). Two implementations:
 *  - in-memory: dev/test default, single-JVM
 *  - redis:     production, shared across server instances (app.rooms.store=redis)
 *
 * Rooms are keyed by 6-char code and carry a TTL so abandoned lobbies
 * self-clean without a sweeper job.
 */
public interface RoomStore {

    /** Persist a new room. Fails if the code already exists. */
    void create(Room room);

    Optional<Room> find(String code);

    /** Replace the room state (post-mutation snapshot). */
    void update(Room room);

    void delete(String code);
}
