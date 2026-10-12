import math
from PIL import Image, ImageDraw, ImageFont
B="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"; R="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

# ---------- ikona 512x512 ----------
S=4; W=512*S
im=Image.new("RGBA",(W,W),(0,0,0,0)); d=ImageDraw.Draw(im)
# tło: zaokrąglony kwadrat, gradient lodu
bg=Image.new("RGBA",(W,W))
for y in range(W):
    t=y/W; c=(int(10+20*t),int(70+40*t),int(160+40*t),255)
    ImageDraw.Draw(bg).line([(0,y),(W,y)],fill=c)
mask=Image.new("L",(W,W),0); ImageDraw.Draw(mask).rounded_rectangle([0,0,W-1,W-1],radius=110*S,fill=255)
im.paste(bg,(0,0),mask)
# owal toru (lodowisko) z strzałką okrążenia
cx,cy=W/2,W*0.40; rx,ry=190*S,105*S
d.ellipse([cx-rx,cy-ry,cx+rx,cy+ry],outline=(200,235,255,255),width=18*S)
# przerwa + grot strzałki (kierunek przeciwny do wskazówek zegara)
a0=math.radians(-35)
gap=[cx+rx*math.cos(a0)-30*S,cy+ry*math.sin(a0)-30*S,cx+rx*math.cos(a0)+30*S,cy+ry*math.sin(a0)+30*S]
px,py=cx+rx*math.cos(math.radians(-20)),cy+ry*math.sin(math.radians(-20))
d.polygon([(px-34*S,py+6*S),(px+30*S,py+14*S),(px+4*S,py-48*S)],fill=(255,255,255,255))
# łyżwa
k=S
boot=[(150,300),(150,215),(175,195),(250,195),(262,250),(330,268),(362,290),(362,330),(150,330)]
d.polygon([(x*k,y*k) for x,y in boot],fill=(255,255,255,255))
d.rounded_rectangle([140*k,326*k,372*k,340*k],radius=6*k,fill=(30,40,60,255))
for x in (175,330):
    d.rectangle([(x-6)*k,340*k,(x+6)*k,368*k],fill=(180,190,205,255))
d.rounded_rectangle([120*k,364*k,400*k,380*k],radius=8*k,fill=(220,230,240,255))
for i,yy in enumerate((222,246,270)):
    d.line([(178*k,yy*k),(240*k,(yy-6)*k)],fill=(20,80,170,255),width=6*k)
# napis
f=ImageFont.truetype(B,70*S)
txt="LAPS"; tw=d.textlength(txt,font=f)
d.text(((W-tw)/2,400*S),txt,font=f,fill=(255,255,255,255))
im.resize((512,512),Image.LANCZOS).save("icon-512.png")

# ---------- podgląd ekranu 240x240 (układ z SkateView.mc) ----------
S=3; w=h=240*S
sc=Image.new("RGB",(w,h),(0,0,0)); d=ImageDraw.Draw(sc)
def t(x,y,s,sz,col,bold=False):
    f=ImageFont.truetype(B if bold else R,int(sz*S)); tw=d.textlength(s,font=f)
    d.text((x*w-tw/2,y*h),s,font=f,fill=col)
t(.5,.10,"Okr. 12  +40%",15,(0,255,0))
t(.5,.18,"07:09",54,(255,255,255),True)
t(.30,.41,"HR",13,(170,170,170)); t(.70,.41,"kcal",13,(170,170,170))
t(.30,.47,"142",26,(255,0,0),True); t(.70,.47,"86",26,(255,170,0),True)
t(.30,.62,"km",13,(170,170,170)); t(.70,.62,"km/h",13,(170,170,170))
t(.30,.68,"1.80",26,(255,255,255),True); t(.70,.68,"16.4",26,(255,255,255),True)
t(.5,.84,"śr 15.1  max 19.8",14,(170,170,170))
m=Image.new("L",(w,h),0); ImageDraw.Draw(m).ellipse([0,0,w-1,h-1],fill=255)
out=Image.new("RGBA",(w,h),(0,0,0,0)); out.paste(sc,(0,0),m)
out.resize((480,480),Image.LANCZOS).save("screenshot-480.png")
out.resize((240,240),Image.LANCZOS).save("screenshot-240.png")
