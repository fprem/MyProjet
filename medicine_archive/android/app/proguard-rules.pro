# The ML Kit plugin references the optional Chinese, Devanagari, Japanese and
# Korean text models. The app only bundles the Latin one, so let R8 skip them.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
