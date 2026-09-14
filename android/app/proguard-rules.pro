## ProGuard 规则（加固防崩溃备用）
## 针对 flutter_local_notifications 与 Gson 反序列化

## --- Gson 规则 ---
# Gson 反序列化依赖保存在 class 文件中的泛型类型签名。
# ProGuard / R8 默认会剥离这些信息，导致 TypeToken 反序列化时丢失具体泛型类型崩溃。
-keepattributes Signature
-keepattributes *Annotation*

# 忽略 sun.misc 警告
-dontwarn sun.misc.**

# 保留 TypeAdapter 及相关工厂接口
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# 保留带 @SerializedName 注解的字段成员，防止被混淆或剔除导致数据为空
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# 保留 TypeToken 及其子类的泛型签名信息（解决 R8 3.0+ 的 TypeToken 反序列化崩溃）
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

## --- flutter_local_notifications 规则 ---
# 保留插件包下所有类（包含 ScheduledNotificationReceiver, NotificationDetails 等）
-keep class com.dexterous.flutterlocalnotifications.** { *; }

## --- workmanager 规则 ---
-keep class dev.fluttercommunity.workmanager.** { *; }
