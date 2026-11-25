"""Nombre e ícono del escritorio según el modo de música.

Crea dos accesos (activity-alias): «RockPlay IA» con el ícono rojo y «Pulso»
con el ícono violeta. La app activa uno y apaga el otro al cambiar de modo,
por el canal «rockplay/launcher». Ejecutar después de setup_android.py,
setup_widget.py y setup_alarm.py. Idempotente.
"""
import glob
import os
import re
import sys

MAIN = os.path.join("android", "app", "src", "main")
MANIFEST = os.path.join(MAIN, "AndroidManifest.xml")
acts = glob.glob(os.path.join(MAIN, "kotlin", "**", "MainActivity.kt"), recursive=True)
if not acts or not os.path.exists(MANIFEST):
    sys.exit("Falta MainActivity.kt o el manifiesto")
src = open(acts[0], encoding="utf-8").read()
pkg = re.search(r"^package\s+([\w.]+)", src, re.M).group(1)

# 1) MainActivity propia: hereda de AudioServiceActivity y agrega el canal.
open(acts[0], "w", encoding="utf-8").write(f'''package {pkg}

import android.content.ComponentName
import android.content.pm.PackageManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {{
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rockplay/launcher")
            .setMethodCallHandler {{ call, result ->
                if (call.method == "setMode") {{
                    val pulso = call.argument<Boolean>("pulso") ?: false
                    try {{
                        setAlias("LauncherPulso", pulso)
                        setAlias("LauncherRock", !pulso)
                        result.success(true)
                    }} catch (e: Exception) {{
                        result.error("alias", e.message, null)
                    }}
                }} else {{
                    result.notImplemented()
                }}
            }}
    }}

    private fun setAlias(name: String, on: Boolean) {{
        val c = ComponentName(packageName, "{pkg}." + name)
        val want = if (on) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                   else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        if (packageManager.getComponentEnabledSetting(c) == want) return
        packageManager.setComponentEnabledSetting(c, want, PackageManager.DONT_KILL_APP)
    }}
}}
''')

m = open(MANIFEST, encoding="utf-8").read()
m = m.replace('android:name="com.ryanheise.audioservice.AudioServiceActivity"',
              'android:name=".MainActivity"')

# 2) La actividad deja de ser el ícono; lo son los dos alias.
def strip_launcher(match):
    act = match.group(0)
    return re.sub(r'\s*<category android:name="android.intent.category.LAUNCHER"\s*/>', "", act)
m = re.sub(r'<activity\b[^>]*android:name="\.MainActivity".*?</activity>', strip_launcher, m, count=1, flags=re.S)

if "LauncherRock" not in m:
    alias = '''
        <activity-alias
            android:name=".LauncherRock"
            android:targetActivity=".MainActivity"
            android:enabled="true"
            android:exported="true"
            android:label="RockPlay IA"
            android:icon="@mipmap/ic_launcher">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity-alias>
        <activity-alias
            android:name=".LauncherPulso"
            android:targetActivity=".MainActivity"
            android:enabled="false"
            android:exported="true"
            android:label="Pulso"
            android:icon="@mipmap/ic_launcher_pulso">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity-alias>
'''
    m = re.sub(r'(<activity\b[^>]*android:name="\.MainActivity".*?</activity>)',
               lambda x: x.group(1) + alias, m, count=1, flags=re.S)
open(MANIFEST, "w", encoding="utf-8").write(m)

# 3) Widget: abre MainActivity (ya no AudioServiceActivity).
for f in glob.glob(os.path.join(MAIN, "kotlin", "**", "*.kt"), recursive=True):
    t = open(f, encoding="utf-8").read()
    if "AudioServiceActivity::class.java" in t:
        open(f, "w", encoding="utf-8").write(
            t.replace("com.ryanheise.audioservice.AudioServiceActivity::class.java", f"{pkg}.MainActivity::class.java"))
print("Accesos RockPlay IA / Pulso listos.")
