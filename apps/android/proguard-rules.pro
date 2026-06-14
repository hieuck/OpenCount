# OpenCount ProGuard Rules
# Keep Kotlin serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class kotlinx.serialization.json.** { kotlinx.serialization.KSerializer serializer(...); }
-keep,includedescriptorclasses class com.opencount.shared.**$$serializer { *; }
-keepclassmembers class com.opencount.shared.** { *** Companion; }
-keepclasseswithmembers class com.opencount.shared.** { kotlinx.serialization.KSerializer serializer(...); }

# Keep Ktor
-keep class io.ktor.** { *; }
-dontwarn io.ktor.**

# Keep Compose
-keep class androidx.compose.** { *; }
