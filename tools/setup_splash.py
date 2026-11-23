"""Pantalla de arranque nativa: fondo negro RockPlay con el logo al centro.

Ejecutar en la raíz del proyecto, después de `flutter create`. Idempotente.
"""
import os
import shutil

RES = os.path.join("android", "app", "src", "main", "res")
LOGO = os.path.join("assets", "icon", "logo.png")

os.makedirs(os.path.join(RES, "drawable"), exist_ok=True)
os.makedirs(os.path.join(RES, "values"), exist_ok=True)
shutil.copyfile(LOGO, os.path.join(RES, "drawable", "splash_logo.png"))

open(os.path.join(RES, "values", "splash_colors.xml"), "w", encoding="utf-8").write(
    '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="splash_bg">#FF0A0A0D</color>
</resources>
''')

XML = '''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/splash_bg" />
    <item
        android:width="120dp"
        android:height="120dp"
        android:gravity="center"
        android:drawable="@drawable/splash_logo" />
</layer-list>
'''
for d in ("drawable", "drawable-v21"):
    path = os.path.join(RES, d)
    os.makedirs(path, exist_ok=True)
    open(os.path.join(path, "launch_background.xml"), "w", encoding="utf-8").write(XML)

# Android 12+: el sistema usa su propia pantalla; al menos fondo negro.
v31 = os.path.join(RES, "values-v31")
os.makedirs(v31, exist_ok=True)
open(os.path.join(v31, "splash_v31.xml"), "w", encoding="utf-8").write(
    '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowSplashScreenBackground">@color/splash_bg</item>
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
</resources>
''')
print("Pantalla de arranque lista")
