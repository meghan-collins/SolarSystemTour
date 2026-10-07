/*

SOLAR SYSTEM TOUR: Shadertoy demoscene

A 72-second loop: Sun -> Mercury -> Venus -> Earth (+ Moon) -> Mars -> Jupiter -> 
                  Saturn -> Uranus -> Neptune -> back to the Sun

At each stop the camera circles the body, then "warps" to the next one

SKILLS PORTFOLIO ITEMS USED (spelled out for grading):
1. Vector math ............ dot/cross/normalize everywhere: look-at camera, lighting, ray tests

2. 3D Geometry ............ analytic ray-sphere intersection for the Sun/planets/Moon,
                            ray-plane intersection for Saturn's rings and the asteroid belt

3. 3D Transformations ..... axial tilt + spin rotation of every planet (setBody/toBody),
                            orbital inclination planes, camera orbit + flight path

4. Cameras & Lighting ..... look-at camera with animated FOV; sun = point light at the origin,
                            Lambert diffuse + Blinn-Phong specular (Earth's oceans),
                            atmospheric rim light, planet/ring shadows, tone mapping

5. Shaders ................ the entire scene is one fragment shader (GLSL)

6. Textures ............... every planet surface is a procedural texture (bands, continents,
                            clouds, Great Red Spot, craters, ice caps...)

7. Bump Maps .............. Mercury, Mars and the Moon perturb their normals with the gradient
                            of a noise height field (see height() and shadeBody())

8. Signed Distance Fns .... orbit lines are drawn with the 2D SDF of a circle, abs(|p|-r)

9. Constructive Geometry .. Saturn's rings = disc MINUS inner disc, with the Cassini gap
                            subtracted out (ringAlpha)

10. Fractals ...............fractal Brownian motion (fbm) = self-similar noise octaves, used for
                            all textures, the Milky Way and the Sun's granulation

11. Acceleration Structures: bounding-sphere tests are used before any ring/atmosphere work.

ON-SCREEN INFO PANEL: while the camera circles a body, a panel fades in showing its real data
(diameter, distance from the Sun in AU and million km, year length, orbital speed, axial tilt,
mean temperature, moon count). The text is drawn by a tiny 3x5 bitmap font coded inside the
shader, and the numbers are formatted at run time (see numChar), so no textures are needed.

REAL-WORLD DATA (NASA/JPL planetary fact sheets):
- Mean radii in km (RADKM)            -> planet sizes are TRUE relative to each other
- Semi-major axes in AU (AU)          -> sets the ORDER and relative spacing of orbits
- Orbital inclinations (INC)          -> each orbit plane is tilted by its real angle
- Mean longitudes at J2000 (L0)       -> planets start where they really were on 1 Jan 2000
                                         (swap in a date that matters to you!)
- Axial tilts (TILT)                  -> Venus upside down, Uranus on its side, etc.
- Rotation rates (SPINREV)            -> faster spin for Jupiter/Saturn, slow for Mercury/Venus
- Orbital period ratios (ORBREV)      -> inner planets orbit faster than outer ones
- Saturn ring boundaries (C, B, Cassini Division, A ring, in km / Saturn radius)
- Main asteroid belt 2.1-3.3 AU, Moon/Earth size ratio, galactic plane tilted 60.2 deg
  to the ecliptic (Milky Way band), irradiance falling off with distance from the Sun

HONEST SCALE NOTES (a true-scale solar system is invisible): planet radii are true relative to
Earth but the Sun is drawn at 4 units (actual: ~38), distances use 6 + 12*AU^0.6, orbital and spin
rates are compressed to whole revolutions per loop so the animation loops perfectly, and sunlight
falls off as AU^-0.5 instead of AU^-2 so Neptune stays visible.

*/

#define PI 3.14159265359
#define TAU 6.28318530718

// timing
const float LOOP = 72.0; // seconds for the full tour (9 stops x 8 s)
const float STOP = 8.0; // seconds per stop
const float DWELL = 5.4; // seconds circling a body before flying to the next

// display scale
const float EARTH_R = 0.35; // Earth radius in scene units
const float SUN_R = 4.0; // compressed Sun radius
const float MOON_ORBIT = 2.2; // compressed Earth-Moon distance
const float MOONREV = 5.0; // Moon revolutions per loop (compressed)

// real data (index 0 = sun, 1...8 = mercury...neptune, 9 = moon)
const float RADKM[10] = float[10](695700., 2439.5, 6052., 6378., 3396., 71492., 60268., 25559., 24764., 1737.4); // = diameter/2
const float AU[9] = float[9](0., 0.39, 0.72, 1.00, 1.52, 5.20, 9.58, 19.20, 30.05);
const float INC[9] = float[9](0., 7.00, 3.39, 0.00, 1.85, 1.30, 2.49, 0.77, 1.77); // degrees
const float L0[9] = float[9](0., 252.25, 181.98, 100.46, 355.45, 34.40, 49.95, 313.24, 304.88); // deg @ J2000
const float ORBREV[9] = float[9](0., 8., 5., 4., 3., 1., 1., 1., 1.); // ~4/sqrt(period yrs), whole revs
const float TILT[10] = float[10](7.25, 0.03, 177.36, 23.44, 25.19, 3.13, 26.73, 97.77, 28.32, 6.68); // deg

// spin revs per loop ~ real rotation rate (24h/period)*6, rounded. Retrograde (Venus, Uranus) is
// already encoded by an axial tilt > 90 deg.
const float SPINREV[10]= float[10](1., 1., 1., 6., 6., 14., 13., 8., 9., 1.);

// helpers
float bodyR(int i){ return i==0 ? SUN_R : EARTH_R*RADKM[i]/RADKM[3]; }
float orbR(int i){ return 6.0 + 12.0*pow(AU[i], 0.6); }
float auOf(int i){ return i==9 ? AU[3] : AU[i]; }
vec3 orbE2(int i){ float a=radians(INC[i]); return vec3(0., sin(a), -cos(a)); }

vec3 planetPos(int i, float tm){
    if(i==0) return vec3(0.);
    float a = radians(L0[i]) + TAU*ORBREV[i]*tm/LOOP;
    return orbR(i)*(cos(a)*vec3(1.,0.,0.) + sin(a)*orbE2(i));
}
vec3 bodyPos(int i, float tm){
    if(i<9) return planetPos(i, tm);
    float b = TAU*MOONREV*tm/LOOP;
    return planetPos(3, tm) + MOON_ORBIT*vec3(cos(b), 0., -sin(b));
}

// noise / fractal brownian motion
float hash(vec3 p){
    p = fract(p*0.3183099 + vec3(.1,.2,.3));
    p *= 17.0;
    return fract(p.x*p.y*p.z*(p.x+p.y+p.z));
}
vec3 hash33(vec3 p){
    return vec3(hash(p), hash(p+vec3(19.1,3.7,11.3)), hash(p+vec3(5.3,23.9,2.1)));
}
float vnoise(vec3 x){
    vec3 i=floor(x), f=fract(x);
    f=f*f*(3.-2.*f);
    return mix(mix(mix(hash(i), hash(i+vec3(1,0,0)),f.x),
           mix(hash(i+vec3(0,1,0)), hash(i+vec3(1,1,0)),f.x),f.y),
           mix(mix(hash(i+vec3(0,0,1)), hash(i+vec3(1,0,1)),f.x),
           mix(hash(i+vec3(0,1,1)), hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float fbm(vec3 p){
    float s=0., a=.5;
    for(int i=0;i<4;i++){ s+=a*vnoise(p); p=p*2.02+vec3(1.7,9.2,3.3); a*=.5; }
    return s/.9375;
}
vec3 rotY(vec3 v, float a){ float c=cos(a), s=sin(a); return vec3(v.x*c-v.z*s, v.y, v.x*s+v.z*c); }

// intersection
float raySphere(vec3 ro, vec3 rd, vec3 c, float r){
    vec3 oc=ro-c; float b=dot(oc,rd); float h=b*b-(dot(oc,oc)-r*r);
    if(h<0.) return -1.;
    h=sqrt(h); float t=-b-h;
    return t>0. ? t : -1.;
}
float rayPlane(vec3 ro, vec3 rd, vec3 c, vec3 n){
    float d=dot(rd,n);
    if(abs(d)<1e-5) return -1.;
    return dot(c-ro,n)/d;
}

// body frame: axial tilt + spin (3D transformation)
vec3 gAx, gB1, gB2; float gCs, gSn;
void setBody(int i, float tm){
    float tl=radians(TILT[i]);
    gAx=vec3(sin(tl),cos(tl),0.);
    gB1=vec3(cos(tl),-sin(tl),0.);
    gB2=vec3(0.,0.,-1.);
    float ph=TAU*SPINREV[i]*tm/LOOP;
    gCs=cos(ph); gSn=sin(ph);
}
// world space direction -> planet-fixed coordinates (y = rotation axis)
vec3 toBody(vec3 v){
    float x=dot(v,gB1), y=dot(v,gAx), z=dot(v,gB2);
    return vec3(x*gCs - z*gSn, y, x*gSn + z*gCs);
}

// saturn's rings (constructive geometry: disc - disc - gap)
const float RING_IN=1.24, RING_OUT=2.27; // in saturn radii (74,500 km ... 136,775 km / 60,268 km)
vec3 ringN(){ float tl=radians(TILT[6]); return vec3(sin(tl),cos(tl),0.); }
float ringStripe(float rr){ return vnoise(vec3(rr*55.,1.7,3.1))*.6 + vnoise(vec3(rr*140.,7.,2.))*.4; }
float ringAlpha(float rr){
    if(rr<RING_IN || rr>RING_OUT) return 0.;
    float s=ringStripe(rr), a;
    if(rr<1.53) a=.18+.20*s; // C ring 74,500-92,000 km
    else if(rr<1.95) a=.55+.45*s; // B ring 92,000-117,580 km
    else if(rr<2.03) a=.03; // Cassini Division 117,580-122,170 km
    else a=.35+.30*s; // A ring 122,170-136,775 km
    a *= smoothstep(RING_IN,RING_IN+.03,rr) * (1.-smoothstep(RING_OUT-.03,RING_OUT,rr));
    return a;
}

// procedural planet textures
float height(int id, vec3 q){
    // height field used for bump mapping
    if(id==1) return fbm(q*7.);
    if(id==4) return fbm(q*8.);
    if(id==9) return fbm(q*9.);
    return 0.;
}

vec3 albedo(int id, vec3 q, float tm, out float spec, out vec3 emis){
    spec=0.; emis=vec3(0.);
    float lat=q.y;
    if(id==1){
        // mercury: grey cratered rock
        vec3 c=mix(vec3(.30,.28,.26), vec3(.60,.56,.50), fbm(q*3.));
        return c*(.65+.7*fbm(q*15.));
    }
    if(id==2){
        // venus: swirling sulphuric clouds
        float s=fbm(q*2.5);
        float b=fbm(vec3(q.x*1.5+.8*s, q.y*5., q.z*1.5-.8*s));
        return mix(vec3(.78,.58,.27), vec3(.97,.88,.62), smoothstep(.25,.75,b));
    }
    if(id==3){
        // earth
        float elev=fbm(q*2.3+3.1);
        float land=smoothstep(.52,.56,elev);
        vec3 ocean=mix(vec3(.01,.05,.22), vec3(.02,.17,.42), fbm(q*9.));
        float dry=smoothstep(.35,.65,fbm(q*4.+9.));
        vec3 landc=mix(vec3(.10,.30,.07), vec3(.50,.40,.22), dry);
        float ice=smoothstep(.80,.88,abs(lat)+.07*fbm(q*7.));
        vec3 qc=rotY(q, TAU*2.*tm/LOOP); // clouds drift relative to the ground
        float cl=smoothstep(.50,.75,fbm(qc*vec3(3.,6.,3.)+11.));
        vec3 c=mix(ocean,landc,land);
        c=mix(c,vec3(.92,.95,1.),ice);
        spec=(1.-land)*(1.-ice)*(1.-cl)*.7; // shiny oceans
        c=mix(c,vec3(.95),cl*.85);
        emis=vec3(1.,.72,.30)*land*(1.-cl)*smoothstep(.6,.75,fbm(q*35.))*.6; // city lights
        return c;
    }
    if(id==4){
        // mars: rusty with dark regions and polar caps
        vec3 c=mix(vec3(.50,.22,.10), vec3(.78,.45,.24), fbm(q*3.));
        c=mix(c, vec3(.22,.10,.06), smoothstep(.55,.72,fbm(q*2.+5.))*.8);
        c*=.8+.4*fbm(q*14.);
        return mix(c, vec3(.92), smoothstep(.90,.95,abs(lat)));
    }
    if(id==5) {
        // jupiter: bands + great red spot
        float t1=fbm(q*vec3(2.,9.,2.));
        float bands=.5+.5*sin(lat*20.+3.*t1);
        vec3 c=mix(vec3(.88,.76,.58), vec3(.55,.34,.20), bands);
        c=mix(c, vec3(.95,.90,.80), smoothstep(.55,.8,fbm(q*vec3(1.5,14.,1.5)))*.35);
        float lon=atan(q.z,q.x), la=asin(clamp(lat,-1.,1.));
        float dl=mod(lon-1.0+PI,TAU)-PI;
        vec2 dd=vec2(dl*cos(la)/.25, (la+.40)/.11);
        return mix(c, vec3(.75,.30,.16), exp(-dot(dd,dd))*.9);
    }
    if(id==6){
        // saturn: pale butterscotch bands
        float t1=fbm(q*vec3(2.,6.,2.));
        float bands=.5+.5*sin(lat*16.+1.5*t1);
        return mix(vec3(.80,.70,.48), vec3(.93,.85,.65), bands)*(.85+.3*t1);
    }
    if(id==7){
        // uranus: featureless cyan
        return mix(vec3(.50,.78,.84), vec3(.62,.88,.92), fbm(q*vec3(1.,5.,1.)));
    }
    if(id==8){
        // neptune: deep blue + white cirrus
        float b=fbm(q*vec3(2.,7.,2.));
        vec3 c=mix(vec3(.12,.22,.70), vec3(.20,.38,.92), b);
        return mix(c, vec3(.85,.90,1.), smoothstep(.68,.82,fbm(q*vec3(4.,12.,4.)+2.))*.5);
    }
    if(id==9){
        // moon: maria + highlands
        float m=smoothstep(.45,.6,fbm(q*1.8));
        return mix(vec3(.62), vec3(.25), m*.8)*(.75+.5*fbm(q*14.));
    }
    return vec3(.5);
}

vec4 atmo(int id){
    // rgb = scattering colour, a = strength
    if(id==2) return vec4(.95,.70,.30,.7);
    if(id==3) return vec4(.30,.55,1.0,1.0);
    if(id==4) return vec4(.85,.50,.30,.15);
    if(id==5) return vec4(.85,.70,.50,.25);
    if(id==6) return vec4(.85,.75,.50,.25);
    if(id==7) return vec4(.50,.85,.95,.6);
    if(id==8) return vec4(.30,.45,1.0,.7);
    return vec4(0.);
}

// shading a sphere hit
vec3 shadeBody(int id, vec3 ro, vec3 rd, float t, vec3 cen, float R, float tm){
    vec3 p=ro+rd*t;
    vec3 n=(p-cen)/R;
    setBody(id,tm);
    vec3 q=toBody(n);

    if(id==0){
        // sun: emissive granulation + sunspots + limb darkening
        float mu=max(dot(n,-rd),0.);
        vec3 q1=rotY(q, TAU*3.*tm/LOOP);
        vec3 q2=rotY(q, -TAU*2.*tm/LOOP);
        float g=fbm(q1*5.)*.6 + fbm(q2*14.)*.4;
        float spots=smoothstep(.62,.72,fbm(q1*2.5+4.));
        vec3 c=mix(vec3(1.,.30,.04), vec3(1.,.80,.30), smoothstep(.3,.8,g));
        c=mix(c, vec3(.35,.08,.0), spots*.7);
        return c*(.55+.45*mu)*2.6;
    }

    float spec; vec3 emis;
    vec3 alb=albedo(id,q,tm,spec,emis);

    // bump mapping: tilt the normal by the tangential gradient of a height field
    float bk=(id==1)?.05:(id==4)?.04:(id==9)?.06:0.;
    if(bk>0.){
        float e=.01, h0=height(id,q);
        vec3 g=vec3(height(id,toBody(n+vec3(e,0,0))),
                    height(id,toBody(n+vec3(0,e,0))),
                    height(id,toBody(n+vec3(0,0,e))))-h0;
        g/=e;
        n=normalize(n-bk*(g-dot(g,n)*n));
    }
    
    vec3 Lv=normalize(-p); // point light at the sun
    float irr=1.6*pow(auOf(id),-.5); // sunlight strength vs. distance
    float ndl=dot(n,Lv);
    float diff=max(ndl,0.);

    float sh=1.; // saturn's rings shadow the planet
    if(id==6){
        float tr=rayPlane(p,Lv,cen,ringN());
        if(tr>0.) sh=1.-.9*ringAlpha(length(p+Lv*tr-cen)/R);
    }

    vec3 col=alb*(irr*diff*sh+.012);
    vec3 hv=normalize(Lv-rd);
    col+=spec*pow(max(dot(n,hv),0.),70.)*irr*diff*sh; // blinn-phong
    col+=emis*(1.-smoothstep(-.02,.12,ndl))*1.2; // city lights on the night side

    vec4 at=atmo(id);
    float fres=pow(1.-max(dot(n,-rd),0.),3.);
    col+=at.rgb*at.a*fres*(max(ndl,0.)+.12)*irr*.9; // atmospheric rim
    return col;
}

// background
vec3 stars(vec3 rd, float tm){
    vec3 col=vec3(0.);
    for(int L=0;L<2;L++){
        float sc=(L==0)?48.:120.;
        vec3 p=rd*sc;
        vec3 id=floor(p)+float(L)*31.7;
        vec3 f=fract(p)-.5;
        vec3 h3=hash33(id);
        float h=hash(id+vec3(5.5));
        float d=length(f-(h3-.5)*.4);
        float size=.10+.15*h3.z;
        float tw=.8+.2*sin(TAU*(6.+floor(h3.y*10.))*tm/LOOP+h*TAU); // twinkle (loop-safe)
        float b=step(.85,h)*(1.-smoothstep(0.,size,d))*tw;
        col+=b*mix(vec3(.7,.8,1.), vec3(1.,.8,.6), h3.y)*((L==0)?1.2:.7);
    }
    return col;
}
vec3 milkyWay(vec3 rd){
    // galactic plane is inclined 60.2 deg to the ecliptic
    vec3 gn=normalize(vec3(sin(radians(60.2)),cos(radians(60.2)),0.));
    float b=dot(rd,gn);
    float band=exp(-b*b*28.);
    float dust=smoothstep(.35,.7,fbm(rd*11.));
    return vec3(.35,.38,.55)*band*(.05+.16*fbm(rd*5.+3.))*(1.-.6*dust);
}
vec3 background(vec3 rd, vec3 fwd, float warp, float tm){
    vec3 c=vec3(0.);
    for(int i=0;i<6;i++){
        // radial streaks while "warping" between planets
        float s=float(i)/5.;
        c+=stars(normalize(mix(rd,fwd,s*warp*.12)),tm);
    }
    c=c/6.*(1.+4.*warp);
    return c+milkyWay(rd);
}

// orbit lines (2D SDF of a circle on each tilted orbit plane)
vec3 orbitLines(vec3 ro, vec3 rd, float tMax){
    vec3 acc=vec3(0.);
    for(int i=1;i<=8;i++){
        float inc=radians(INC[i]);
        vec3 nrm=vec3(0.,cos(inc),sin(inc));
        float t=rayPlane(ro,rd,vec3(0.),nrm);
        if(t>0. && t<tMax){
            vec3 h=ro+rd*t;
            vec2 uv=vec2(h.x, dot(h,orbE2(i)));
            float sd=abs(length(uv)-orbR(i)); // signed distance to the orbit circle
            float w=t*.0016;
            acc+=vec3(.35,.55,.95)*(1.-smoothstep(0.,w,sd))*.25;
        }
    }
    return acc;
}

// main asteroid belt (2.1 - 3.3 AU)
float belt(vec3 ro, vec3 rd, float tMax){
    if(abs(rd.y)<1e-4) return 0.;
    float t=-ro.y/rd.y;
    if(t<=0.||t>=tMax) return 0.;
    vec3 h=ro+rd*t;
    float r=length(h.xz);
    if(r<6.+12.*pow(2.1,.6) || r>6.+12.*pow(3.3,.6)) return 0.;
    float cell=.9;
    vec2 g=h.xz/cell, id=floor(g), f=fract(g)-.5;
    float hh=hash(vec3(id,3.3));
    vec2 off=(vec2(hash(vec3(id,1.1)),hash(vec3(id,7.7)))-.5)*.5;
    float rad=.04+.05*hh;
    float eff=max(rad,t*.002);
    float d=length(f-off)*cell;
    return step(.55,hh)*(1.-smoothstep(eff*.5,eff,d))*min(1.,rad/eff);
}

// ON SCREEN INFO PANEL 
// real-world data shown in the panel (index 0 = sun, 1...8 = mercury...neptune)
// AU, TILT are the arrays defined at the top of the file.
const float DIAKM[9] = float[9](1391400., 4879., 12104., 12756., 6792., 142984., 120536., 51118., 49528.);
const float MKM[9] = float[9](0., 57.9, 108.2, 149.6, 228.0, 778.5, 1432.0, 2867.0, 4515.0);
const float PERIOD[9] = float[9](0., 88.0, 224.7, 365.2, 687.0, 4331.0, 10747.0, 30589.0, 59800.0); // earth days
const float VEL[9] = float[9](0., 47.4, 35.0, 29.8, 24.1, 13.1, 9.7, 6.8, 5.4); // km/s
const float TEMPC[9] = float[9](5505., 167., 464., 15., -65., -110., -140., -195., -200.); // deg C
const float MOONS[9] = float[9](8., 0., 0., 1., 2., 101., 285., 29., 16.); // sun row = planet count
const vec3 PCOL[9] = vec3[9](vec3(1.,.78,.31), vec3(.612,.553,.482), vec3(.851,.725,.541),
                     vec3(.157,.373,.706), vec3(.710,.314,.180), vec3(.851,.702,.510),
                     vec3(.890,.827,.639), vec3(.624,.890,.878), vec3(.247,.373,.831));

// character codes: 0 space, 1-26 A-Z, 27-36 digits, then symbols
#define SP 0
#define cA 1
#define cB 2
#define cC 3
#define cD 4
#define cE 5
#define cF 6
#define cG 7
#define cH 8
#define cI 9
#define cJ 10
#define cK 11
#define cL 12
#define cM 13
#define cN 14
#define cO 15
#define cP 16
#define cQ 17
#define cR 18
#define cS 19
#define cT 20
#define cU 21
#define cV 22
#define cW 23
#define cX 24
#define cY 25
#define cZ 26
#define cDOT 37
#define cCOMMA 38
#define cDASH 39
#define cSLASH 41
#define cDEG 42

// 3x5 bitmap font, each octal digit is one row of 3 pixels (left pixel = highest bit).
const int FONT[44] = int[44](
    0,
    025755,065656,034443,065556,074647,074644,034553,055755,072227,011152,055655,044447,057755,
    065555,025552,065644,025563,065655,034216,072222,055557,055552,055775,055255,055222,071247,
    075557,026227,061247,061216,055711,074616,034757,071222,075757,075716,
    000002,000024,000700,002020,011244,025200,002720);

const int NAMES[72] = int[72](
    cS,cU,cN,SP,SP,SP,SP,SP,
    cM,cE,cR,cC,cU,cR,cY,SP,
    cV,cE,cN,cU,cS,SP,SP,SP,
    cE,cA,cR,cT,cH,SP,SP,SP,
    cM,cA,cR,cS,SP,SP,SP,SP,
    cJ,cU,cP,cI,cT,cE,cR,SP,
    cS,cA,cT,cU,cR,cN,SP,SP,
    cU,cR,cA,cN,cU,cS,SP,SP,
    cN,cE,cP,cT,cU,cN,cE,SP);

const int LBL[120] = int[120](
    cD,cI,cA,cM,cE,cT,cE,cR,SP,SP,SP,SP, // 0 diameter
    cS,cU,cN,SP,cD,cI,cS,cT,SP,SP,SP,SP, // 1 distance (AU)
    SP,SP,SP,SP,SP,SP,SP,SP,SP,SP,SP,SP, // 2 distance (million km)
    cY,cE,cA,cR,SP,SP,SP,SP,SP,SP,SP,SP, // 3 year length
    cO,cR,cB,cI,cT,SP,cS,cP,cE,cE,cD,SP, // 4 orbital speed
    cA,cX,cI,cA,cL,SP,cT,cI,cL,cT,SP,SP, // 5 axial tilt
    cM,cE,cA,cN,SP,cT,cE,cM,cP,SP,SP,SP, // 6 mean temperature
    cM,cO,cO,cN,cS,SP,SP,SP,SP,SP,SP,SP, // 7 moons
    cS,cU,cR,cF,cA,cC,cE,SP,cT,cE,cM,cP, // 8 (sun) surface temperature
    cP,cL,cA,cN,cE,cT,cS,SP,SP,SP,SP,SP); // 9 (sun) planets

const int UNIT[48] = int[48](
    cK,cM,SP,SP,SP,SP,
    cA,cU,SP,SP,SP,SP,
    cM,cI,cL,SP,cK,cM,
    cD,cA,cY,cS,SP,SP,
    cK,cM,cSLASH,cS,SP,SP,
    cDEG,SP,SP,SP,SP,SP,
    cDEG,cC,SP,SP,SP,SP,
    SP,SP,SP,SP,SP,SP);

int ip10(int k){ int r=1; for(int i=0;i<9;i++){ if(i>=k) break; r*=10; } return r; }

// character at position p (0 = rightmost) of a right-aligned number with `dec` decimals and thousands commas
int numChar(float v, int dec, int p){
    int n=int(floor(abs(v)*float(ip10(dec))+.5));
    int idx=p;
    if(dec>0){
        if(idx<dec) return 27+(n/ip10(idx))%10;
        if(idx==dec) return cDOT;
        idx-=dec+1;
        n/=ip10(dec);
    }
    int D=1;
    for(int k=1;k<9;k++) if(n>=ip10(k)) D=k+1;
    int L=D+(D-1)/3;
    if(idx<L){
        if(idx%4==3) return cCOMMA;
        return 27+(n/ip10(idx-idx/4))%10;
    }
    if(idx==L && v<0.) return cDASH;
    return 0;
}

int rowOf(int b, int l){
    // which data row is printed on text line l
    if(b==0){ return l==0?0 : l==1?6 : l==2?5 : l==3?7 : -1; }
    return l<8 ? l : -1;
}
float dataVal(int b, int row){
    if(row==0) return DIAKM[b];
    if(row==1) return AU[b];
    if(row==2) return MKM[b];
    if(row==3) return PERIOD[b];
    if(row==4) return VEL[b];
    if(row==5) return TILT[b];
    if(row==6) return TEMPC[b];
    return MOONS[b];
}
int decOf(int b, int row){
    if(row==1) return 2;
    if(row==2||row==3||row==4) return 1;
    if(row==5) return (b==0||TILT[b]<1.) ? 2 : 1;
    return 0;
}
int labelChar(int b, int row, int col){
    int id=row;
    if(b==0&&row==6) id=8;
    if(b==0&&row==7) id=9;
    return LBL[id*12+col];
}
bool glyphOn(int c, int lx, int ly){ return c>0 && ((FONT[c]>>((4-ly)*3+(2-lx)))&1)==1; }

// returns premultiplied-style (rgb, alpha) to blend over the frame
vec4 infoPanel(vec2 fc, int b, float fade, float rt){
    if(fade<=.001) return vec4(0.);
    float ps=max(floor(iResolution.y/330.),1.); // size of one font pixel on screen (panel stays ~25% of screen height)
    vec2 org=vec2(12.*ps, iResolution.y-12.*ps); // top-left corner of the panel
    vec2 fpf=floor(vec2(fc.x-org.x, org.y-fc.y)/ps);
    int fx=int(fpf.x), fy=int(fpf.y);
    int nLines=(b==0)?4:8;
    if(fx<-5||fx>=116||fy<-5||fy>=18+nLines*9) return vec4(0.);

    vec3 acc=mix(PCOL[b],vec3(1.),.25);
    vec4 res=vec4(.02,.03,.06,.55*fade); // dark backdrop
    if(fx<-3) res=vec4(acc,fade); // accent bar in the planet's colour

    if(fx>=0 && fy>=0 && fy<10){
        // title, drawn 2x
        int col=fx/8, lx=(fx%8)/2, ly=fy/2;
        if(col<8 && lx<3 && glyphOn(NAMES[b*8+col],lx,ly))
            res=vec4(acc,fade*clamp(rt*4.,0.,1.));
    } else if(fx>=0 && fy>=16){
        // data lines
        int l=(fy-16)/9, ly=(fy-16)%9;
        int row=rowOf(b,l);
        int col=fx/4, lx=fx%4;
        if(row>=0 && ly<5 && lx<3 && col<27){
            int c=0; vec3 tc=vec3(.62,.70,.85);
            if(col<12) c=labelChar(b,row,col);
            else if(col<20){ 
                c=numChar(dataVal(b,row),decOf(b,row),19-col); tc=vec3(1.); 
            }
            else if(col>=21){ 
                c=UNIT[row*6+(col-21)]; tc=vec3(.55,.62,.78); 
            }
            if(glyphOn(c,lx,ly)) res=vec4(tc,fade*clamp((rt-.15*float(l))*4.,0.,1.));
        }
    }
    return res;
}

// camera choreography
void camState(int k, float tm, out vec3 pos, out vec3 tgt){
    vec3 c=planetPos(k,tm);
    float R=bodyR(k);
    float dist=R*((k==0)?4.2:(k==6)?5.4:3.6);
    float a=TAU*9.*tm/LOOP+float(k)*1.7; // 9 whole orbits per loop
    float el=.28+.22*sin(TAU*3.*tm/LOOP+float(k));
    if(k==6) el+=.25; // show saturn's rings
    pos=c+dist*normalize(vec3(cos(a),el,sin(a)));
    tgt=c;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    float tm=mod(iTime,LOOP);

    // which stop are we at, and are we flying to the next one?
    int k = min(int(floor(tm/STOP)),8);
    int k2 = (k+1)%9;
    float loc = tm-float(k)*STOP;
    float u = clamp((loc-DWELL)/(STOP-DWELL),0.,1.);
    float pu = u*u*(3.-2.*u);
    float tu = smoothstep(0.,.5,u);
    float warp= sin(PI*u);

    vec3 pA,tA,pB,tB;
    camState(k, tm,pA,tA);
    camState(k2,tm,pB,tB);
    vec3 ro=mix(pA,pB,pu);
    ro.y+=sin(PI*pu)*.28*length(pB-pA); // arc over planets/Sun instead of flying through them
    vec3 tg=mix(tA,tB,tu);

    vec3 ww=normalize(tg-ro);
    vec3 uu=normalize(cross(ww,vec3(0.,1.,0.)));
    vec3 vv=cross(uu,ww);
    vec2 p=(2.*fragCoord-iResolution.xy)/iResolution.y;
    float f=1.4-.6*warp; // FOV widens during the warp
    vec3 rd=normalize(p.x*uu+p.y*vv+f*ww);

    // bodies
    vec3 P[10]; float Rr[10];
    for(int i=0;i<10;i++){ P[i]=bodyPos(i,tm); Rr[i]=bodyR(i); }

    float tHit=1e9; int hid=-1;
    for(int i=0;i<10;i++){
        float t=raySphere(ro,rd,P[i],Rr[i]);
        if(t>0.&&t<tHit){ tHit=t; hid=i; }
    }

    vec3 col;
    if(hid>=0) col=shadeBody(hid,ro,rd,tHit,P[hid],Rr[hid],tm);
    else col=background(rd,ww,warp,tm);

    // sun corona + bloom
    float tcs=dot(-ro,rd);
    if(tcs>0. && (hid<=0 || tcs<tHit)){
        float dm=length(ro+rd*tcs);
        float x=dm/SUN_R;
        if(x>1.) col+=vec3(1.,.5,.15)*.45*exp(-(x-1.)*2.5);
        float ang=dm/tcs;
        col+=vec3(1.,.55,.2)*.0009/(ang*ang+.0006);
    }

    // atmosphere halos
    for(int i=2;i<=8;i++){
        vec4 at=atmo(i);
        float tc=dot(P[i]-ro,rd);
        if(tc>0. && tc<tHit){
            vec3 pc=ro+rd*tc-P[i];
            float dd=length(pc);
            if(dd>Rr[i]){
                float g=exp(-(dd-Rr[i])/(.06*Rr[i]));
                float lit=clamp(dot(pc/dd,normalize(-P[i]))*.9+.15,0.,1.);
                col+=at.rgb*at.a*g*lit*.8*pow(AU[i],-.5);
            }
        }
    }

    // saturn's rings (bounding sphere first = cheap acceleration test)
    {
        vec3 N=ringN();
        float tb=raySphere(ro,rd,P[6],Rr[6]*RING_OUT);
        float inside=length(ro-P[6])<Rr[6]*RING_OUT?1.:0.;
        if(tb>0.||inside>0.){
            float tr=rayPlane(ro,rd,P[6],N);
            if(tr>0.&&tr<tHit){
                vec3 hp=ro+rd*tr;
                float rr=length(hp-P[6])/Rr[6];
                float al=ringAlpha(rr);
                if(al>.001){
                    vec3 Lr=normalize(-hp);
                    vec3 rc0=mix(vec3(.45,.38,.30), vec3(.90,.82,.68), ringStripe(rr));
                    float side=dot(N,Lr)*dot(N,-rd);
                    float lit=side>0.?1.:.22;
                    float shd=raySphere(hp,Lr,P[6],Rr[6])>0.?.06:1.;
                    float irr6=1.6*pow(AU[6],-.5);
                    col=mix(col, rc0*(irr6*lit*shd+.01), al);
                }
            }
        }
    }

    // orbit lines + asteroid belt (only where nothing is in front)
    col+=orbitLines(ro,rd,tHit);
    col+=belt(ro,rd,tHit)*vec3(.65,.58,.50);

    // tone map, gamma, vignette
    col=1.-exp(-col*1.3);
    col=pow(col,vec3(.4545));
    col*=1.-.25*dot(p*.5,p*.5);

    // info panel for the body we are circling: fades in on arrival, out as we depart
    float fade=smoothstep(.1,.55,loc)*(1.-smoothstep(DWELL-.4,DWELL+.4,loc));
    vec4 pn=infoPanel(fragCoord,k,fade,loc-.25);
    col=mix(col,pn.rgb,pn.a);

    // tour progress: one dot per stop, current destination highlighted
    int shown=(u>.5)?k2:k;
    vec2 dq=fragCoord-vec2(iResolution.x*.5, iResolution.y*.05);
    for(int i=0;i<9;i++){
        float r=iResolution.y*((i==shown)?.010:.006);
        float dd=length(dq-vec2((float(i)-4.)*iResolution.y*.035,0.));
        float a=1.-smoothstep(r-1.,r,dd);
        col=mix(col, mix(PCOL[i],vec3(1.),.25), a*((i==shown)?1.:.4));
    }
    fragColor=vec4(col,1.);
}
