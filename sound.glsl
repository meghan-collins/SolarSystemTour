/*

SOLAR SYSTEM TOUR - COMBINED SOUND
Loud layer : planet notes, arrival chimes, Sun drone, warp whoosh (synced to the tour)
Quiet layer: ambient "intergalactic" pads, bells and twinkles underneath

Timing matches the image shader: 72 s loop, 9 stops of 8 s,
5.4 s circling each body, then 2.6 s of warp flight to the next.

LOUD LAYER (planet sounds)
 - Sun drone + low gong on arrival
 - One sustained note per planet + a chime on arrival. PITCH COMES FROM REAL DATA:
   the longer a planet's year, the lower its note (Mercury highest, Neptune lowest),
   snapped to a pentatonic scale
 - Rising noise + sweep during each warp flight
 - Notes pan left/right following the camera's orbit around the body

QUIET LAYER (ambient background, A minor)
 - Six soft chords (Am - Fmaj7 - Cmaj7 - G6 - Dm9 - Em7), 12 s each
 - Sparse glassy bell melody and tiny high "star" twinkles

Mix: change PLANET_GAIN and AMBIENT_GAIN below to rebalance the two layers.

Seamless loop: every frequency is snapped (sf) so whole cycles fit in 72 s, notes fade
out before the loop restarts, and the "random" ambient notes come from a hash of their
slot number so the same notes play every loop.

*/

#define TAU 6.28318530718
#define PI 3.14159265359

const float LOOP = 72.0;
const float STOP = 8.0;
const float DWELL = 5.4;

const float PLANET_GAIN = 0.60; // loud layer
const float AMBIENT_GAIN = 0.28; // quiet background layer

// snap a frequency so an exact whole number of cycles fits in the loop
float sf(float f){ return floor(f*LOOP+.5)/LOOP; }

// LOUD LAYER: planet sounds
// real data: orbital period in Earth days (index 0 = sun, 1...8 = mercury...neptune)
const float PERIOD[9] = float[9](0., 88.0, 224.7, 365.2, 687.0, 4331.0, 10747.0, 30589.0, 59800.0);

// note frequency for stop k: longer year -> lower pitch, snapped to a pentatonic scale
float noteFreq(int k){
    if(k==0) return 55.0; // sun drone: low A
    float st = 3.6*log2(PERIOD[k]/PERIOD[1]); // semitones below Mercury's note
    float oct = floor(st/12.);
    float r = st-12.*oct;
    const float SC[6] = float[6](0.,2.,4.,7.,9.,12.); // major pentatonic
    float best=0., bd=99.;
    for(int i=0;i<6;i++){ float d=abs(r-SC[i]); if(d<bd){ bd=d; best=SC[i]; } }
    return 523.25*exp2(-(oct*12.+best)/12.); // mercury = C5 (523 Hz)
}

// the sustained note, chime and sun drone, as a stereo pair, at time t
vec2 voice(float t){
    float tm = mod(t,LOOP);
    int k = min(int(floor(tm/STOP)),8);
    float loc = tm-float(k)*STOP;
    float f = noteFreq(k);

    // fade in on arrival, fade out while flying away
    float env = smoothstep(0.,1.2,loc)*(1.-smoothstep(DWELL-.2,STOP,loc));
    float vib = .3*sin(TAU*sf(5.)*tm); // gentle vibrato (phase modulation)

    // slightly detuned left/right oscillators = chorus/width
    float L = sin(TAU*sf(f*.998)*tm+vib) + .40*sin(TAU*sf(f*2.)*tm)
            + .18*sin(TAU*sf(f*3.)*tm) + .30*sin(TAU*sf(f*.5)*tm);
    float R = sin(TAU*sf(f*1.002)*tm+vib)+ .40*sin(TAU*sf(f*2.)*tm)
            + .18*sin(TAU*sf(f*3.)*tm) + .30*sin(TAU*sf(f*.5)*tm);

    // arrival chime (inharmonic partials = bell-like)
    float ring = smoothstep(0.,.03,loc)*exp(-loc*2.5);
    float bell = (.5*sin(TAU*sf(f*2.76)*tm)+.3*sin(TAU*sf(f*5.4)*tm))*ring;

    // pan follows the camera's circle around the body
    float pan = .5+.35*sin(TAU*9.*tm/LOOP+float(k)*1.7);
    float gL = 1.4*cos(pan*.5*PI), gR = 1.4*sin(pan*.5*PI);
    vec2 note = vec2(L*gL, R*gR)*env*.22 + vec2(bell*gL, bell*gR)*.15;

    // constant, slowly breathing sun-like drone underneath everything
    float swell = .05+.03*sin(TAU*tm/LOOP);
    float bed = (sin(TAU*sf(55.)*tm)+.5*sin(TAU*sf(82.5)*tm)+.3*sin(TAU*sf(110.)*tm))*swell;

    return note+vec2(bed);
}

// warp whoosh
float h1(float n){ return fract(sin(n*127.1)*43758.5453); }
float vn(float x){
    // smooth 1D noise in [-1,1]
    float i=floor(x), f=fract(x);
    f=f*f*(3.-2.*f);
    return mix(h1(i),h1(i+1.),f)*2.-1.;
}
vec2 whoosh(float t){
    float tm = mod(t,LOOP);
    int k = min(int(floor(tm/STOP)),8);
    float s = tm-float(k)*STOP-DWELL; // seconds since the flight began
    if(s<=0.) return vec2(0.);
    float T = STOP-DWELL;
    float u = s/T;
    float env = sin(PI*u); env*=env; // swells up, then fades
    // noise sampled faster and faster = rising "filter sweep"
    float ph = 150.*s+(4000.-150.)*s*s/(2.*T);
    float sweep = sin(TAU*(60.*s+(300.-60.)*s*s/(2.*T))); // rising tone underneath
    float seed = float(k)*13.7;
    return vec2(vn(ph+seed)+.3*sweep, vn(ph+seed+37.3)+.3*sweep)*env*.18;
}

// QUIET LAYER: ambient music
float semi(float s){ return 110.0*exp2(s/12.0); } // semitones above A2 (110 Hz)
float ah1(float n){ return fract(sin(n*127.1+31.7)*43758.5453); }

// 6 chords x 4 notes, in semitones above A2
const float CHORDS[24] = float[24](
     0., 7., 12., 15., // Am
    -4., 3., 7., 12., // Fmaj7
     3., 10., 14., 19., // Cmaj7
    -2., 5., 14., 19., // G6
     5., 12., 15., 19., // Dm9
    -5., 2., 5., 10.); // Em7

// soft pad: one chord, lt = seconds since that chord started
vec2 padChord(int c, float lt, float tm){
    if(lt<0. || lt>16.) return vec2(0.);
    float env = smoothstep(0.,4.,lt)*(1.-smoothstep(10.,16.,lt)); // slow fade in, long release
    vec2 s = vec2(0.);
    for(int i=0;i<4;i++){
        float f = semi(CHORDS[c*4+i]);
        float trem = .7+.3*sin(TAU*sf(.125)*tm+float(i)*1.3); // slow shimmer
        float L = sin(TAU*sf(f*.997)*tm) + .25*sin(TAU*sf(f*2.)*tm);
        float R = sin(TAU*sf(f*1.003)*tm)+ .25*sin(TAU*sf(f*2.)*tm);
        s += vec2(L,R)*trem*.055;
    }
    return s*env;
}
vec2 pad(float tm){
    int c = int(floor(tm/12.));
    float lt = tm-float(c)*12.;
    return padChord(c,lt,tm) + padChord((c+5)%6, lt+12., tm); // previous chord still fading out
}

// bell melody: slot n starts at n*1.5 s
vec2 bellNote(int n, float tm){
    float lt = tm-float(n)*1.5;
    if(lt<0. || lt>6.) return vec2(0.);
    int ni = (n+48)%48;
    float r = ah1(float(ni));
    if(r<.4) return vec2(0.); // rests keep it sparse
    int c = ni/8;
    int idx = min(int(floor(ah1(float(ni)+9.)*4.)),3);
    float oct = (ah1(float(ni)+17.)>.5) ? 36. : 24.;
    float f = semi(CHORDS[c*4+idx]+oct);
    float env = smoothstep(0.,.01,lt)*exp(-lt*1.5);
    float tone = sin(TAU*sf(f)*tm) + .18*sin(TAU*sf(f*2.76)*tm)*exp(-lt*3.);
    float pan = .2+.6*ah1(float(ni)+3.);
    return vec2(tone*(1.-pan), tone*pan)*env*.10;
}

// tiny high twinkles: slot m starts at m*0.5 s
vec2 twinkle(int m, float tm){
    float lt = tm-float(m)*.5;
    if(lt<0. || lt>.8) return vec2(0.);
    int mi = (m+144)%144;
    if(ah1(float(mi)+100.)<.72) return vec2(0.);
    const float RAT[5] = float[5](1., 1.2, 1.3333, 1.5, 1.7778); // A minor pentatonic ratios
    int idx = min(int(floor(ah1(float(mi)+7.)*5.)),4);
    float f = 1760.*RAT[idx]*((ah1(float(mi)+41.)>.5)?1.:.5);
    float env = smoothstep(0.,.004,lt)*exp(-lt*7.);
    float tone = sin(TAU*sf(f)*tm)*env*.035;
    float pan = ah1(float(mi)+55.);
    return vec2(tone*(1.-pan), tone*pan)*1.4;
}

vec2 ambient(float t){
    float tm = mod(t,LOOP);
    vec2 m = pad(tm);

    int nb = int(floor(tm/1.5));
    for(int j=0;j<4;j++) m += bellNote(nb-j, tm);

    int nt = int(floor(tm/.5));
    for(int j=0;j<2;j++) m += twinkle(nt-j, tm);

    float drone = (sin(TAU*sf(55.)*tm)+.5*sin(TAU*sf(82.5)*tm))*(.03+.015*sin(TAU*tm/LOOP));
    return m+vec2(drone);
}

//  MIX
vec2 mainSound(int samp, float time){
    // loud layer: planet notes with echoes, plus the warp whoosh
    vec2 planets = voice(time)+.45*voice(time-.31)+.28*voice(time-.67)+whoosh(time);

    // quiet layer: ambient music with echoes
    vec2 amb = ambient(time)+.4*ambient(time-.75)+.22*ambient(time-1.6);

    vec2 o = planets*PLANET_GAIN + amb*AMBIENT_GAIN;
    return o/(1.+abs(o)); // soft clip, never harsh
}
