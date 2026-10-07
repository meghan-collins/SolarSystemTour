<<<<<<< HEAD
# Solar System Tour

A 72-second looping flight through the solar system, written entirely as a [Shadertoy](https://www.shadertoy.com/) shader with its own generated soundtrack. The camera starts at the Sun, circles each planet, warps through space to the next one, and finishes back at the Sun, so the animation loops seamlessly.

There are no image files, 3D models, or audio samples. Everything you see and hear is computed in GLSL from math and the clock.

**Live demo:** [Solar System Tour Shadertoy Project](https://www.shadertoy.com/view/f3G3WV)

## What it does

- Visits the Sun, Mercury, Venus, Earth (with the Moon), Mars, Jupiter, Saturn (with rings), Uranus and Neptune, then returns to the Sun.
- Each stop lasts 8 seconds: about 5.4 seconds circling the body, then a 2.6-second warp flight to the next one. The star field streaks and the field of view widens during each flight.
- While the camera circles a body, an on-screen panel fades in with its real data: diameter, distance from the Sun (AU and million km), year length, orbital speed, axial tilt, mean temperature and moon count.
- A row of dots at the bottom shows tour progress.
- The sound has a quiet ambient layer (pads, bells and twinkles) under louder planet notes, arrival chimes and warp whooshes.

## Files

| File | Where it goes in Shadertoy | What it is |
|---|---|---|
| `image.glsl` | **Image** tab | The visuals: scene, camera, shading, info panel |
| `sound.glsl` | **Sound** tab | The soundtrack |

## How to run it

1. Go to [shadertoy.com/new](https://www.shadertoy.com/new).
2. Delete the default code in the **Image** tab and paste in `image.glsl`.
3. Click the **+** (sound) button at the bottom of the code editor to open a **Sound** tab. Paste in `sound.glsl`.
4. Compile (Alt+Enter) and press play. Use the rewind button to restart the picture and the sound together.

No input channels or textures are needed. Headphones are recommended, because the notes pan with the camera.

**Performance tip:** the planet surfaces use a lot of noise. If the frame rate drops, shrink the Shadertoy canvas, or lower the octave count (`i<4`) in the `fbm` function.

## How it works

### The clock
Everything is a function of `tm = mod(iTime, 72)`.

- `k = floor(tm / 8)` is the current stop (0 = Sun, 1 = Mercury, ... 8 = Neptune).
- `loc = tm - 8k` is the seconds into that stop.
- `u = clamp((loc - 5.4) / 2.6, 0, 1)` is the flight progress. It stays 0 while circling and runs 0 to 1 during the flight.

The sound shader recomputes the same clock from its own `time` using the same constants, so nothing is shared between the two tabs.

### Camera
For stop `k` and the next stop `k+1`, the shader builds a camera position and target at the current time, so it tracks planets as they move. It blends between them with an eased `u`, lifts the camera on an arc so it flies over the Sun and planets instead of through them, and turns toward the next body slightly early.

### Rendering
There is no ray marching. Each pixel casts a ray, intersects it analytically with 10 spheres (Sun, eight planets, Moon) and keeps the nearest hit. It then computes color and lighting for that hit, adds atmosphere halos, blends in Saturn's rings, adds orbit lines and the asteroid belt, tone-maps, and finally draws the info panel and progress dots.

### Textures and bump maps
Every surface is procedural, built from 3D value noise and fractal Brownian motion (`fbm`: noise octaves at doubling frequency and halving strength). Noise is sampled in each planet's own rotating frame, which avoids seams and pinched poles. Examples: gas-giant bands warped by noise, Jupiter's Great Red Spot as an ellipse, Earth's continents, ice caps and drifting clouds, Mars's dark regions, the Sun's granulation and sunspots. Mercury, Mars and the Moon also use bump mapping, tilting the surface normal by the gradient of a noise height field.

### Lighting
The Sun is a point light at the origin, using Lambert diffuse shading, Blinn-Phong specular highlights on Earth's oceans, and a colored atmospheric rim glow. Saturn's rings shadow the planet and the planet shadows the rings. Moon shadows and eclipses are not modeled.

### Earth's night side
City lights are procedural, not real data. A warm orange emission appears only where the surface is land, not cloud-covered, and a fine noise threshold passes. It is shown only on the dark side, using the angle between the surface normal and the Sun direction.

### Orbits
Planets are placed on circular orbits, tilted by their real inclination, starting from their real positions on 1 January 2000. Orbit lines are drawn as the distance to a circle on each orbit plane. The asteroid belt is a plane between 2.1 and 3.3 AU divided into cells, where a hash decides which cells hold a rock.

### Sound
- **Planet notes:** pitch comes from each planet's real orbital period. The longer the year, the lower the note (Mercury highest, Neptune lowest), snapped to a pentatonic scale. The Sun is a low drone.
- **Switching:** the note changes when `floor(tm / 8)` changes. The old note has already faded out, and the new one fades in over about a second.
- **Warp whoosh:** noise sampled at a rising rate plus a rising tone, active only during each flight.
- **Panning:** notes pan using the same orbit angle as the camera.
- **Echo:** shaders have no memory, so echoes are made by evaluating the sound again at earlier times.
- **Ambient layer:** six chords in A minor (Am, Fmaj7, Cmaj7, G6, Dm9, Em7), 12 seconds each, plus a sparse bell melody and tiny high twinkles. The "random" notes come from a hash of their slot number, so they repeat every loop.
- **Mix:** change `PLANET_GAIN` and `AMBIENT_GAIN` at the top of `sound.glsl`.

### Perfect looping
Everything repeats exactly every 72 seconds. Orbits and spins are whole numbers of revolutions per loop, twinkling and cloud drift use whole cycles, and every sound frequency is rounded so a whole number of cycles fits in 72 seconds. Sound and picture run on separate clocks, so rewind both to restart them together.

## Real-world data

Values were entered from NASA/JPL planetary fact sheets. [Add your own source links here.]

| Body | Diameter (km) | Distance (AU) | Year (Earth days) | Axial tilt (deg) |
|---|---:|---:|---:|---:|
| Mercury | 4,879 | 0.39 | 88.0 | 0.03 |
| Venus | 12,104 | 0.72 | 224.7 | 177.4 |
| Earth | 12,756 | 1.00 | 365.2 | 23.4 |
| Mars | 6,792 | 1.52 | 687.0 | 25.2 |
| Jupiter | 142,984 | 5.20 | 4,331.0 | 3.1 |
| Saturn | 120,536 | 9.58 | 10,747.0 | 26.7 |
| Uranus | 51,118 | 19.20 | 30,589.0 | 97.8 |
| Neptune | 49,528 | 30.05 | 59,800.0 | 28.3 |

Other real data used: orbital inclinations, mean longitudes at J2000, orbital speeds, mean temperatures, moon counts, Saturn's ring boundaries (C ring, B ring, Cassini Division, A ring), the main asteroid belt (2.1 to 3.3 AU), the Moon-to-Earth size ratio, and the Milky Way's 60.2-degree tilt to the ecliptic.

## Honest scale notes

A true-scale solar system is almost entirely empty space, so some things are bent to keep it watchable:

- Planet sizes are true relative to each other, but the Sun is drawn at 4 units instead of its real ~38.
- Distances use `6 + 12 * AU^0.6`, a compressed curve. The order and relative spacing are kept, but not the true ratios.
- Orbit and spin speeds are rounded to whole revolutions per loop. The inner planets orbit faster than the outer ones, but the real period ratios are only roughly kept. Saturn, Uranus and Neptune each make one orbit per loop.
- Orbits are circles; real orbits are slightly elliptical.
- Sunlight falls off as `AU^-0.5` instead of `AU^-2` so Neptune stays visible.
- Earth's continents are procedural noise, not the real map.
- The info panel shows real moon counts (for example Jupiter 101, Saturn 285), but only Earth's Moon is drawn.

## Techniques used

Vector math; 3D geometry (ray-sphere and ray-plane intersection); 3D transformations (axial tilt, spin, orbit planes, camera paths); cameras and lighting; shaders; procedural textures; bump maps; signed distance functions (orbit lines); constructive geometry (Saturn's rings as a disc minus a hole minus the Cassini gap); fractals (fractal Brownian motion); and bounding-sphere tests to skip unnecessary work.

## Tested on

MacOS with Apple M5 chip on chrome browser at 60fps

## Author

Meghan Collins
=======
# SolarSystemTour
FILL IN LATER
>>>>>>> 7f6dd9ba878596fd35892a708dc16f3190442703
