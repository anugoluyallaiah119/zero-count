package com.zerocount.server.notification;

import java.util.UUID;

/**
 * ⚠️ DORMANT — activates in V2.3 (Engagement, story R1.6). INTERFACE ONLY.
 *
 * Do NOT implement this in V2.0–V2.2. When activated, delivery is via FCM
 * push with respectful caps (max 1 unsolicited push/day; never between
 * 22:00–08:00 user-local) — engagement policy, not just transport.
 */
public interface NotificationService {

    /** Queue a notification for delivery, honoring user prefs and caps. */
    void notifyUser(UUID userId, Notification notification);

    /** Register/refresh a device's FCM token (called on app start). */
    void registerDevice(UUID userId, String fcmToken);

    /** Opt a user out of a notification kind (user settings). */
    void muteKind(UUID userId, Notification.Kind kind);
}
