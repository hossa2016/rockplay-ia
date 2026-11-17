"""Genera el icono de RockPlay IA (púa con destellos) y lo instala en la app Android.

Ejecutar en la raíz del proyecto, después de `flutter create` y antes de compilar.
Necesita Pillow:  pip install pillow
"""
import glob
import os

from PIL import Image, ImageDraw, ImageFilter, ImageChops
import math, random
S=1024
def lerp(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(3))
# fondo: carbón con viñeta roja
bg=Image.new("RGB",(S,S),(10,10,13))
px=bg.load()
for y in range(S):
    for x in range(S):
        d=math.hypot(x-S*0.5,y-S*0.55)/(S*0.7)
        t=max(0,1-d)**2
        px[x,y]=lerp((8,9,16),(52,30,130),t*0.95)
# grano
random.seed(3)
g=Image.effect_noise((S,S),22).convert("L")
bg=Image.blend(bg,Image.merge("RGB",(g,g,g)),0.05)
# púa de guitarra (triángulo redondeado)
def pick_pts(cx,cy,w,h,n=240):
    pts=[]
    # superelipse tipo púa: ancha arriba, punta abajo
    for i in range(n):
        a=2*math.pi*i/n
        x=math.cos(a); y=math.sin(a)
        # forma: lados rectos hacia la punta
        k=0.5*(1+y)  # 0 arriba,1 abajo
        wx=w*(1-0.82*(k**1.6))
        pts.append((cx+x*wx*0.5*(1 if abs(x)<1 else 1), cy+y*h*0.5))
    return pts
pick=Image.new("L",(S,S),0)
dp=ImageDraw.Draw(pick)
dp.polygon([(S/2-300,250),(S/2+300,250),(S/2,820)],fill=255)
pick=pick.filter(ImageFilter.GaussianBlur(55)).point(lambda v:255 if v>150 else 0).filter(ImageFilter.GaussianBlur(1.5))
# degradado rojo→ámbar en la púa
grad=Image.new("RGB",(S,S))
gp=grad.load()
for y in range(S):
    t=min(1,max(0,(y-S*0.15)/(S*0.7)))
    c=lerp((124,92,255),(46,214,255),t)
    for x in range(S): gp[x,y]=c
# sombra
sh=Image.new("RGB",(S,S),(0,0,0))
shadow=pick.filter(ImageFilter.GaussianBlur(30)).point(lambda v:int(v*0.7))
bg.paste(sh,(0,24),shadow)
bg.paste(grad,(0,0),pick)
# borde metálico
edge=ImageChops.subtract(pick,pick.filter(ImageFilter.MinFilter(15)))
bg.paste(Image.new("RGB",(S,S),(215,235,255)),(0,0),edge.point(lambda v:int(v*0.55)))
# rayo oscuro dentro de la púa
d=ImageDraw.Draw(bg)
def star(cx,cy,r,k=0.22):
    pts=[]
    for i in range(8):
        a=math.pi/2*i/2-math.pi/2
        rr=r if i%2==0 else r*k
        pts.append((cx+rr*math.cos(a),cy+rr*math.sin(a)))
    return pts
st=Image.new("L",(S,S),0); sd=ImageDraw.Draw(st)
sd.polygon(star(488,470,150),fill=255)
sd.polygon(star(628,372,58),fill=255)
st=st.filter(ImageFilter.GaussianBlur(1.2))
bg.paste(Image.new("RGB",(S,S),(10,10,20)),(0,0),st)

m = Image.new("L", (S, S), 0)
ImageDraw.Draw(m).rounded_rectangle((0, 0, S, S), radius=230, fill=255)
full = Image.new("RGBA", (S, S), (0, 0, 0, 0))
full.paste(bg, (0, 0), m)

RES = os.path.join("android", "app", "src", "main", "res")
for name, px in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
    d = os.path.join(RES, "mipmap-" + name)
    os.makedirs(d, exist_ok=True)
    full.resize((px, px), Image.LANCZOS).save(os.path.join(d, "ic_launcher.png"))
# Quita iconos adaptativos que pisarían el nuevo.
for x in glob.glob(os.path.join(RES, "mipmap-anydpi*", "ic_launcher*.xml")):
    os.remove(x)
print("Icono instalado.")
