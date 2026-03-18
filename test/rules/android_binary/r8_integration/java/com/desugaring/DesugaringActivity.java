package com.desugaring;

import android.app.Activity;
import android.os.Bundle;
import java.time.Duration;

/** Activity that exercises Duration.toSeconds() to test core library desugaring. */
public class DesugaringActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Force the compiler to retain the call to DurationUser.getSeconds
        long seconds = DurationUser.getSeconds(Duration.ofMinutes(5));
        setTitle("Seconds: " + seconds);
    }
}
