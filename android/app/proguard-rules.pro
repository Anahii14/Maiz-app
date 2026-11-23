# Reglas para la versión release (R8 reduce el código y podría borrar clases
# que TensorFlow Lite usa por reflexión o desde código nativo).
-keep class org.tensorflow.** { *; }
-keep interface org.tensorflow.** { *; }
-dontwarn org.tensorflow.**
