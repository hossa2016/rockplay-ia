"""Agrega el widget de pantalla de inicio «Seguir escuchando» (home_widget).

Ejecutar en la raíz del proyecto, después de `flutter create` y de
setup_android.py. Idempotente.
"""
import glob
import os
import re
import sys

MAIN = os.path.join("android", "app", "src", "main")
MANIFEST = os.path.join(MAIN, "AndroidManifest.xml")
if not os.path.exists(MANIFEST):
    sys.exit(f"No existe {MANIFEST}")

# Paquete: el de MainActivity.kt que generó flutter create.
acts = glob.glob(os.path.join(MAIN, "kotlin", "**", "MainActivity.kt"), recursive=True)
if not acts:
    sys.exit("No encontré MainActivity.kt")
src = open(acts[0], encoding="utf-8").read()
pkg = re.search(r"^package\s+([\w.]+)", src, re.M).group(1)
kdir = os.path.dirname(acts[0])

KT = f'''package {pkg}

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Widget «Seguir escuchando»: muestra lo último que sonó y abre la app. */
class NowPlayingWidget : HomeWidgetProvider() {{
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {{
        for (id in appWidgetIds) {{
            val views = RemoteViews(context.packageName, R.layout.now_playing_widget)
            views.setTextViewText(
                R.id.np_title,
                widgetData.getString("np_title", null) ?: "Tu mix te espera"
            )
            views.setTextViewText(
                R.id.np_artist,
                widgetData.getString("np_artist", null) ?: "Toca para abrir RockPlay IA"
            )
            val pending = HomeWidgetLaunchIntent.getActivity(
                context,
                com.ryanheise.audioservice.AudioServiceActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.np_root, pending)
            appWidgetManager.updateAppWidget(id, views)
        }}
    }}
}}
'''
open(os.path.join(kdir, "NowPlayingWidget.kt"), "w", encoding="utf-8").write(KT)

os.makedirs(os.path.join(MAIN, "res", "layout"), exist_ok=True)
os.makedirs(os.path.join(MAIN, "res", "xml"), exist_ok=True)
os.makedirs(os.path.join(MAIN, "res", "drawable"), exist_ok=True)

open(os.path.join(MAIN, "res", "drawable", "np_widget_bg.xml"), "w", encoding="utf-8").write(
    '''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient android:angle="0" android:startColor="#FF5A0F0D" android:endColor="#FF14141A" />
    <corners android:radius="24dp" />
    <stroke android:width="1dp" android:color="#33FFB02E" />
</shape>
''')

open(os.path.join(MAIN, "res", "layout", "now_playing_widget.xml"), "w", encoding="utf-8").write(
    '''<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/np_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/np_widget_bg"
    android:orientation="vertical"
    android:gravity="center_vertical"
    android:padding="16dp">

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="SEGUIR ESCUCHANDO"
        android:textColor="#FFFFB02E"
        android:textSize="11sp"
        android:textStyle="bold"
        android:letterSpacing="0.15" />

    <TextView
        android:id="@+id/np_title"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="4dp"
        android:ellipsize="end"
        android:maxLines="1"
        android:text="Tu mix te espera"
        android:textColor="#FFF4F4F6"
        android:textSize="17sp"
        android:textStyle="bold" />

    <TextView
        android:id="@+id/np_artist"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:ellipsize="end"
        android:maxLines="1"
        android:text="Toca para abrir RockPlay IA"
        android:textColor="#FFA6A6B2"
        android:textSize="13sp" />
</LinearLayout>
''')

open(os.path.join(MAIN, "res", "xml", "now_playing_widget_info.xml"), "w", encoding="utf-8").write(
    '''<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:initialLayout="@layout/now_playing_widget"
    android:minWidth="250dp"
    android:minHeight="80dp"
    android:targetCellWidth="4"
    android:targetCellHeight="1"
    android:resizeMode="horizontal"
    android:updatePeriodMillis="0"
    android:widgetCategory="home_screen" />
''')

m = open(MANIFEST, encoding="utf-8").read()
if "NowPlayingWidget" not in m:
    rec = '''
        <receiver
            android:name=".NowPlayingWidget"
            android:exported="true"
            android:label="Seguir escuchando">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/now_playing_widget_info" />
        </receiver>
'''
    m = m.replace("</application>", rec + "    </application>", 1)
    open(MANIFEST, "w", encoding="utf-8").write(m)
print(f"Widget agregado en {pkg}")
