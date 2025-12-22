package com.example.bundle.features.assets;

import android.app.Activity;
import android.os.Bundle;

/** Activity provided by the dynamic feature module. */
public class FeatureActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    public static String getFeatureName() {
        return "Asset Feature with Code";
    }
}
