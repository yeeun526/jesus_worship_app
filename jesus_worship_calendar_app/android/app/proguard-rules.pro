# =========================================================================
# 1. Firebase Core, Auth, Firestore, Storage에 대한 필수 규칙
# =========================================================================
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }
-keep interface com.google.firebase.** { *; }

# Google Play Services 및 Google Services for Firebase
-keep class com.google.android.gms.internal.firebase* { *; }
-keep class com.google.android.gms.** { *; }
-keep interface com.google.android.gms.** { *; }

# =========================================================================
# 2. Flutter Native Shell 및 플러그인에 대한 필수 규칙
# =========================================================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# FlutterFire 및 기타 플러그인 (file_picker, video_player 등)
-keep class io.flutter.plugins.** { *; }
-keep class com.mr.file_picker.** { *; }
-keep class io.flutter.plugins.videoplayer.** { *; }

# =========================================================================
# 3. JSON/모델 직렬화 및 Reflection 관련 보호 규칙
# =========================================================================
-keepnames class * implements java.io.Serializable
-keepclassmembers class * {
  private <init>();
}