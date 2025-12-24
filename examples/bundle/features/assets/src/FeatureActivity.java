package com.example.bundle.features.assets;

import android.app.Activity;
import android.os.Bundle;
import android.widget.TextView;

/** Activity provided by the dynamic feature module. */
public class FeatureActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        TextView tv = new TextView(this);
        tv.setText("Feature Module Loaded: " + getFeatureName());
        tv.setTextSize(24);
        tv.setPadding(32, 32, 32, 32);
        setContentView(tv);
    }

    public static String getFeatureName() {
        return "Asset Feature with Code";
    }
}
