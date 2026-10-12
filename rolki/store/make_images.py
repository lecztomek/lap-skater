# Grafiki Rolek do Connect IQ Store: ikona 512x512 i podgląd ekranu (układ z RolkiView.mc, przykładowe dane)
import math
from PIL import Image, ImageDraw, ImageFont
B="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"; R="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

# ---------- ikona ----------
S=4; W=512*S
im=Image.new("RGBA",(W,W),(0,0,0,0)); d=ImageDraw.Draw(im)
bg=Image.new("RGBA",(W,W))
for y in range(W):
    t=y/W; ImageDraw.Draw(bg).line([(0,y),(W,y)],fill=(int(0+20*t),int(120+40*t),int(80+30*t),255))
mask=Image.new("L",(W,W),0); ImageDraw.Draw(mask).rounded_rectangle([0,0,W-1,W-1],radius=110*S,fill=255)
im.paste(bg,(0,0),mask)
k=S
# linie ruchu
for i,yy in enumerate((215,250,285)):
    d.rounded_rectangle([60*k,yy*k,(130-i*15)*k,(yy+10)*k],radius=5*k,fill=(200,255,220,200))
# but
boot=[(170,300),(170,150),(200,128),(285,128),(298,215),(380,240),(410,268),(410,318),(170,318)]
d.polygon([(x*k,y*k) for x,y in boot],fill=(255,255,255,255))
for yy in (165,192,219):
    d.line([(200*k,yy*k),(270*k,(yy-6)*k)],fill=(0,130,85,255),width=7*k)
# szyna i kółka
d.rounded_rectangle([160*k,316*k,420*k,334*k],radius=7*k,fill=(30,40,50,255))
for cx in (195,262,329,392):
    d.ellipse([(cx-30)*k,(332)*k,(cx+30)*k,(392)*k],fill=(255,200,0,255))
    d.ellipse([(cx-10)*k,(352)*k,(cx+10)*k,(372)*k],fill=(120,90,0,255))
f=ImageFont.truetype(B,64*S); txt="ROLKI"; tw=d.textlength(txt,font=f)
d.text(((W-tw)/2,405*S),txt,font=f,fill=(255,255,255,255))
im.resize((512,512),Image.LANCZOS).save("icon-512.png")

# ---------- podgląd ekranu ----------
S=3; w=h=240*S; cx=w/2
sc=Image.new("RGB",(w,h),(0,0,0)); d=ImageDraw.Draw(sc)
def t(y,s,sz,col,bold=False,vc=False):
    f=ImageFont.truetype(B if bold else R,int(sz*S)); bb=d.textbbox((0,0),s,font=f)
    x=cx-(bb[2]-bb[0])/2-bb[0]; yy=y*h-((bb[3]+bb[1])/2 if vc else 0)
    d.text((x,yy),s,font=f,fill=col)
d.ellipse([cx-5*S,h*0.07-5*S,cx+5*S,h*0.07+5*S],fill=(0,255,0))
t(.13,"42:17",26,(255,255,255),True)
t(.48,"12.36",58,(255,255,255),True,vc=True)
t(.62,"km",13,(170,170,170))
t(.72,"18.4 km/h",24,(255,255,255),True)
m=Image.new("L",(w,h),0); ImageDraw.Draw(m).ellipse([0,0,w-1,h-1],fill=255)
o=Image.new("RGBA",(w,h),(0,0,0,0)); o.paste(sc,(0,0),m)
o.resize((480,480),Image.LANCZOS).save("screenshot-480.png")
o.resize((240,240),Image.LANCZOS).save("screenshot-240.png")
