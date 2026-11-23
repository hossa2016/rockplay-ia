"""Despertador: permisos, receptores de flutter_local_notifications, sonido
de respaldo y desugaring de Java. Ejecutar después de `flutter create` y de
setup_android.py. Idempotente.
"""
import os
import re
import shutil
import sys

MAIN = os.path.join("android", "app", "src", "main")
MANIFEST = os.path.join(MAIN, "AndroidManifest.xml")
if not os.path.exists(MANIFEST):
    sys.exit(f"No existe {MANIFEST}")
m = open(MANIFEST, encoding="utf-8").read()

if "xmlns:tools=" not in m:
    m = re.sub(r"<manifest\b", '<manifest xmlns:tools="http://schemas.android.com/tools"', m, count=1)

PERMS = [
    "android.permission.SCHEDULE_EXACT_ALARM",
    "android.permission.USE_EXACT_ALARM",
    "android.permission.USE_FULL_SCREEN_INTENT",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.VIBRATE",
    "android.permission.WAKE_LOCK",
    "android.permission.POST_NOTIFICATIONS",
]
block = ""
for p in PERMS:
    if f'android:name="{p}"' not in m:
        block += f'    <uses-permission android:name="{p}"/>\n'
if block:
    m = re.sub(r"(<manifest\b[^>]*>\s*\n)", lambda x: x.group(1) + block, m, count=1)

# La actividad puede mostrarse sobre la pantalla bloqueada y encenderla.
def patch_activity(match):
    tag = match.group(0)
    if "showWhenLocked" not in tag:
        tag = tag.replace("<activity", '<activity android:showWhenLocked="true" android:turnScreenOn="true"', 1)
    return tag

m = re.sub(r"<activity\b[^>]*>", patch_activity, m, count=1)

if "ScheduledNotificationReceiver" not in m:
    rec = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
'''
    m = m.replace("</application>", rec + "    </application>", 1)
open(MANIFEST, "w", encoding="utf-8").write(m)

# Sonido de respaldo como recurso (lo usa el aviso del sistema).
raw = os.path.join(MAIN, "res", "raw")
os.makedirs(raw, exist_ok=True)
shutil.copyfile(os.path.join("assets", "sounds", "rock_riff.wav"), os.path.join(raw, "rock_riff.wav"))
open(os.path.join(raw, "keep.xml"), "w", encoding="utf-8").write(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@raw/rock_riff" />\n')

# Desugaring (lo pide flutter_local_notifications).
kts = os.path.join("android", "app", "build.gradle.kts")
groovy = os.path.join("android", "app", "build.gradle")
if os.path.exists(kts):
    g = open(kts, encoding="utf-8").read()
    if "isCoreLibraryDesugaringEnabled" not in g:
        g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", g, count=1)
    if "desugar_jdk_libs" not in g:
        g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    open(kts, "w", encoding="utf-8").write(g)
elif os.path.exists(groovy):
    g = open(groovy, encoding="utf-8").read()
    if "coreLibraryDesugaringEnabled" not in g:
        g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        coreLibraryDesugaringEnabled true", g, count=1)
    if "desugar_jdk_libs" not in g:
        g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    open(groovy, "w", encoding="utf-8").write(g)
print("Despertador configurado")
