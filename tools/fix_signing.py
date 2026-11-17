"""Firma el APK de release con tools/debug.keystore (firma fija)."""
import os, re, sys

kts = 'android/app/build.gradle.kts'
groovy = 'android/app/build.gradle'

if os.path.exists(kts):
    p = kts
    s = open(p).read()
    block = '''    signingConfigs {
        create("rp") {
            storeFile = file("../../tools/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }
'''
    new, n = re.subn(r'signingConfigs\.getByName\("debug"\)', 'signingConfigs.getByName("rp")', s)
else:
    p = groovy
    s = open(p).read()
    block = '''    signingConfigs {
        rp {
            storeFile file("../../tools/debug.keystore")
            storePassword "android"
            keyAlias "androiddebugkey"
            keyPassword "android"
        }
    }
'''
    new, n = re.subn(r'signingConfigs\.debug', 'signingConfigs.rp', s)

if n == 0:
    print('NO se encontro la firma de release en', p)
    sys.exit(1)
i = new.index('buildTypes')
new = new[:i] + block[4:] + '    ' + new[i:]
open(p, 'w').write(new)
print('Firma fija aplicada en', p)
