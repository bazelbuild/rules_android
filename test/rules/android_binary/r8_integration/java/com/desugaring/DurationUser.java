package com.desugaring;

import java.time.Duration;

/**
 * A class that uses Duration.toSeconds(), which was added in API 31.
 * This simulates a third-party library (like Google Nav SDK) that calls
 * methods not available on all supported API levels.
 *
 * Without core library desugaring, this causes NoSuchMethodError on
 * API 26-30 devices.
 */
public class DurationUser {
    public static long getSeconds(Duration duration) {
        // Duration.toSeconds() requires API 31+
        return duration.toSeconds();
    }
}
