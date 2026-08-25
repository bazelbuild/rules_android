# Proguard / R8 configuration for r8app

# Keep the entry point activity
-keep class com.r8app.MainActivity {
    <init>(...);
}
