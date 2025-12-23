# Proguard rules for dynamic feature module

# Keep the FeatureActivity class name for launching via Intent
-keep class com.example.bundle.features.assets.FeatureActivity {
    <init>();
}

# Obfuscate everything else
-optimizationpasses 5
-allowaccessmodification
