"""Parchea android/app/src/main/AndroidManifest.xml para RockPlay.

Ejecutar en la raíz del proyecto, después de `flutter create --platforms=android`.
Idempotente.
"""
import os
import re
import sys

MANIFEST = os.path.join("android", "app", "src", "main", "AndroidManifest.xml")
if not os.path.exists(MANIFEST):
    sys.exit(f"No existe {MANIFEST}")

m = open(MANIFEST, encoding="utf-8").read()
try:
    pub = open("pubspec.yaml", encoding="utf-8").read()
except OSError:
    pub = ""
uses_audio_service = "audio_service" in pub or "just_audio_background" in pub

# --- namespace tools (lo necesitan tools:ignore del service/receiver) ---
if "xmlns:tools=" not in m:
    m = re.sub(
        r"<manifest\b",
        '<manifest xmlns:tools="http://schemas.android.com/tools"',
        m,
        count=1,
    )

# --- permisos ---
PERMS = [
    "android.permission.INTERNET",
    "android.permission.ACCESS_NETWORK_STATE",
    "android.permission.WAKE_LOCK",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
]
block = ""
for p in PERMS:
    if f'android:name="{p}"' not in m:
        block += f'    <uses-permission android:name="{p}"/>\n'
if block:
    m = re.sub(r"(<manifest\b[^>]*>\s*\n)", lambda x: x.group(1) + block, m, count=1)

# --- <application>: nombre y cleartext ---
def patch_application(match):
    tag = match.group(0)
    if re.search(r'android:label="[^"]*"', tag):
        tag = re.sub(r'android:label="[^"]*"', 'android:label="RockPlay IA"', tag, count=1)
    else:
        tag = tag.replace("<application", '<application android:label="RockPlay IA"', 1)
    if "android:usesCleartextTraffic" not in tag:
        tag = tag.replace("<application", '<application android:usesCleartextTraffic="true"', 1)
    return tag

m = re.sub(r"<application\b[^>]*>", patch_application, m, count=1)

# --- audio_service ---
if uses_audio_service:
    m = m.replace(
        'android:name=".MainActivity"',
        'android:name="com.ryanheise.audioservice.AudioServiceActivity"',
    )
    if "com.ryanheise.audioservice.AudioService\"" not in m:
        extra = '''
        <service
            android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true"
            tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>

        <receiver
            android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true"
            tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
'''
        m = m.replace("</application>", extra + "    </application>", 1)

open(MANIFEST, "w", encoding="utf-8").write(m)
print("AndroidManifest.xml parcheado")
