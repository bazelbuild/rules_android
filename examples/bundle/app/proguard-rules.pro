# Proguard rules for base module
-keepattributes SourceFile,LineNumberTable

# Ignore missing androidx annotations (they are compile-time only)
-dontwarn androidx.annotation.**
-dontwarn com.google.android.play.core.**
