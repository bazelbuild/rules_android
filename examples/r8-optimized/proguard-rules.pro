# Proguard / R8 configuration for r8app.
# Default Android optimization rules (proguard-android-optimize.txt) are
# automatically supplied by rules_android when proguard_specs is non-empty,
# though supplying duplicate rules here will not break the build.

# Keep the entry point activity
-keep class com.r8app.MainActivity {
    <init>(...);
}
