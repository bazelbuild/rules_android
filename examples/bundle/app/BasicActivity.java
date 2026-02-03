// Copyright 2022 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package com.examples.bundle.app;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.view.Menu;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

import com.google.android.play.core.splitinstall.SplitInstallManager;
import com.google.android.play.core.splitinstall.SplitInstallManagerFactory;
import com.google.android.play.core.splitinstall.SplitInstallRequest;
import com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener;
import com.google.android.play.core.splitinstall.model.SplitInstallSessionStatus;

/**
 * The main activity of the Basic Sample App.
 */
public class BasicActivity extends Activity {

  private static final String FEATURE_MODULE_NAME = "asset_feature";
  private static final String FEATURE_ACTIVITY_CLASS =
      "com.example.bundle.features.assets.FeatureActivity";

  private SplitInstallManager splitInstallManager;
  private TextView statusTextView;

  private final SplitInstallStateUpdatedListener listener = state -> {
    switch (state.status()) {
      case SplitInstallSessionStatus.DOWNLOADING:
        statusTextView.setText("Downloading feature module...");
        break;
      case SplitInstallSessionStatus.INSTALLING:
        statusTextView.setText("Installing feature module...");
        break;
      case SplitInstallSessionStatus.INSTALLED:
        statusTextView.setText("Feature module installed!");
        launchFeatureActivity();
        break;
      case SplitInstallSessionStatus.FAILED:
        statusTextView.setText("Installation failed: " + state.errorCode());
        break;
      case SplitInstallSessionStatus.CANCELED:
        statusTextView.setText("Installation canceled");
        break;
    }
  };

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.basic_activity);

    splitInstallManager = SplitInstallManagerFactory.create(this);
    statusTextView = findViewById(R.id.text_hello);

    final Button buttons[] = {
      findViewById(R.id.button_id_fizz), findViewById(R.id.button_id_buzz),
    };

    for (Button b : buttons) {
      b.setOnClickListener(
          new View.OnClickListener() {
            public void onClick(View v) {
              TextView tv = findViewById(R.id.text_hello);
              if (v.getId() == R.id.button_id_fizz) {
                tv.setText("fizz");
              } else if (v.getId() == R.id.button_id_buzz) {
                tv.setText("buzz ");
              }
            }
          });
    }

    Button loadFeatureButton = findViewById(R.id.button_load_feature);
    loadFeatureButton.setOnClickListener(v -> loadFeatureModule());
  }

  @Override
  protected void onResume() {
    super.onResume();
    splitInstallManager.registerListener(listener);
  }

  @Override
  protected void onPause() {
    super.onPause();
    splitInstallManager.unregisterListener(listener);
  }

  private void loadFeatureModule() {
    if (splitInstallManager.getInstalledModules().contains(FEATURE_MODULE_NAME)) {
      statusTextView.setText("Feature already installed!");
      launchFeatureActivity();
      return;
    }

    statusTextView.setText("Requesting feature module...");

    SplitInstallRequest request = SplitInstallRequest.newBuilder()
        .addModule(FEATURE_MODULE_NAME)
        .build();

    splitInstallManager.startInstall(request)
        .addOnSuccessListener(sessionId -> {
          statusTextView.setText("Installation started (session " + sessionId + ")");
        })
        .addOnFailureListener(e -> {
          statusTextView.setText("Failed to start install: " + e.getMessage());
        });
  }

  private void launchFeatureActivity() {
    try {
      Intent intent = new Intent();
      intent.setClassName(getPackageName(), FEATURE_ACTIVITY_CLASS);
      startActivity(intent);
    } catch (Exception e) {
      statusTextView.setText("Failed to launch: " + e.getMessage());
    }
  }

  @Override
  public boolean onCreateOptionsMenu(Menu menu) {
    // Inflate the menu; this adds items to the action bar if it is present.
    getMenuInflater().inflate(R.menu.menu, menu);
    return true;
  }
}
