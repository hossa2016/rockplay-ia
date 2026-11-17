"""Instala el icono de RockPlay IA (R rockera roja con destello).

Los PNG ya están hechos en tools/icon/. Ejecutar en la raíz del proyecto,
después de `flutter create` y antes de compilar. No necesita Pillow.
"""
import glob
import os
import shutil

RES = os.path.join("android", "app", "src", "main", "res")
for name in ["mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"]:
    d = os.path.join(RES, "mipmap-" + name)
    os.makedirs(d, exist_ok=True)
    shutil.copyfile(os.path.join("tools", "icon", f"ic_launcher_{name}.png"),
                    os.path.join(d, "ic_launcher.png"))
# Quita iconos adaptativos que pisarían el nuevo.
for x in glob.glob(os.path.join(RES, "mipmap-anydpi*", "ic_launcher*.xml")):
    os.remove(x)
print("Icono instalado.")
