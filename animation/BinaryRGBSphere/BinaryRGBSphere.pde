int[][] result; // RGB motion blur buffer
float t;              // global time in [0,1[
float c;              // testing variable

//-----------------------------------
// Utility functions

float c01(float x)
{
  return constrain(x, 0, 1);
}

PVector rotZ(PVector v, float theta)
{
  float x = v.x*cos(theta) - v.y*sin(theta);
  float y = v.x*sin(theta) + v.y*cos(theta);
  return new PVector(x, y, v.z);
}

PVector rotY(PVector v, float theta)
{
  float x = v.x*cos(theta) - v.z*sin(theta);
  float z = v.x*sin(theta) + v.z*cos(theta);
  return new PVector(x, v.y, z);
}

PVector rotX(PVector v, float theta)
{
  float y = v.y*cos(theta) - v.z*sin(theta);
  float z = v.y*sin(theta) + v.z*cos(theta);
  return new PVector(v.x, y, z);
}

//-----------------------------------
// synchronized RGB cycle:
// Red → Purple → Blue → Cyan → Green → Yellow → Red

int[][] RGB_FLOW = {
  {255,   0,   0},   // Red
  {168,   0, 255},   // Purple
  {  0,  82, 255},   // Blue
  {  0, 220, 255},   // Cyan
  {  0, 255, 110},   // Green
  {255, 220,   0}    // Yellow
};

color syncedRGB(float phase)
{
  phase = ((phase % 1.0) + 1.0) % 1.0;

  float p = phase * RGB_FLOW.length;
  int a = floor(p) % RGB_FLOW.length;
  int b = (a + 1) % RGB_FLOW.length;

  float f = p - floor(p);
  f = f*f*(3.0 - 2.0*f); // smoothstep

  return color(
    lerp(RGB_FLOW[a][0], RGB_FLOW[b][0], f),
    lerp(RGB_FLOW[a][1], RGB_FLOW[b][1], f),
    lerp(RGB_FLOW[a][2], RGB_FLOW[b][2], f)
  );
}

//-----------------------------------

void draw()
{
  if (!recording)
  {
    // interactive preview
    t = (mouseX*1.3/width) % 1;
    c = mouseY*1.0/height;

    if (mousePressed)
      println(c);

    draw_();
  }
  else
  {
    // Original-style RGB motion blur accumulation.
    for (int i=0; i<width*height; i++)
      for (int a=0; a<3; a++)
        result[i][a] = 0;

    c = 0;

    for (int sa=0; sa<samplesPerFrame; sa++)
    {
      t = map(
        frameCount - 1 + sa*shutterAngle/samplesPerFrame,
        0,
        numFrames,
        0,
        1
      );

      t %= 1;

      draw_();
      loadPixels();

      for (int i=0; i<pixels.length; i++)
      {
        result[i][0] += red(pixels[i]);
        result[i][1] += green(pixels[i]);
        result[i][2] += blue(pixels[i]);
      }
    }

    loadPixels();

    for (int i=0; i<pixels.length; i++)
    {
      pixels[i] =
        0xff << 24 |
        int(result[i][0] / float(samplesPerFrame)) << 16 |
        int(result[i][1] / float(samplesPerFrame)) << 8 |
        int(result[i][2] / float(samplesPerFrame));
    }

    updatePixels();

    // PNG sequence first; black is removed later by GitHub Actions.
    if (frameCount <= numFrames)
    {
      saveFrame("data/fr###.png");
      println(frameCount, "/", numFrames);
    }

    if (frameCount == numFrames)
      stop();
  }
}

// End of render template
//////////////////////////////////////////////////////////////////////////////

int samplesPerFrame = 8;
int numFrames = 330;
float shutterAngle = 0.8;

boolean recording = false;

PFont uiFont;

// IMPORTANT:
// Lower density than the 0–9 version.
// With only 0 and 1, 210 digits visually turns into a solid shell.
// 160 keeps the open "cloud globe" look.
int numberOfDigits = 160;

float R = 125;

float cameraZ()
{
  return 300.0;
}

PVector positionTransform(PVector v)
{
  // Preserve the same tilted, gently breathing globe movement.
  return rotZ(
    v.copy(),
    0.17 * PI + 0.03 * PI * sin(TAU*(t-0.3))
  );
}

float projectionFactor = 440.0;

void showParticle(
  PVector position,
  float sizeFactor,
  boolean isDigit,
  int digitValue,
  float alphaFactor
)
{
  position = positionTransform(position);

  // Stronger depth separation:
  // back = much dimmer, front = bright.
  float alphaFactor2 =
    map(position.z, -R, R, 0.12, 1.15) * alphaFactor;

  float zDistanceFromCamera =
    cameraZ() - position.z;

  if (zDistanceFromCamera > 0)
  {
    float x2D =
      projectionFactor * position.x / zDistanceFromCamera;

    float y2D =
      projectionFactor * position.y / zDistanceFromCamera;

    PVector pixelPosition =
      new PVector(x2D, y2D);

    color col = syncedRGB(t);

    if (isDigit)
    {
      // Slightly smaller than the original so 0/1 stay separated.
      float textSz = 25;

      float scl =
        0.1 *
        sizeFactor *
        projectionFactor /
        zDistanceFromCamera;

      push();

      translate(
        pixelPosition.x - 0.5*textSz/2,
        pixelPosition.y + 0.5*textSz/2
      );

      scale(scl);

      rotate(
        0.03 *
        sin(TAU*(t-0.3)) *
        PI
      );

      float a =
        constrain(alphaFactor2 * 235, 0, 235);

      fill(
        red(col),
        green(col),
        blue(col),
        a
      );

      noStroke();
      textSize(textSz);
      text(digitValue, 0, 0);

      pop();
    }
    else
    {
      float sz =
        sizeFactor *
        projectionFactor /
        zDistanceFromCamera;

      float a =
        constrain(17 * alphaFactor2, 0, 210);

      stroke(
        red(col),
        green(col),
        blue(col),
        a
      );

      strokeWeight(sz);

      point(
        pixelPosition.x,
        pixelPosition.y
      );
    }
  }
}

void showDashedCurve()
{
  int dashParam = 20;

  float R2 = 1.05 * R;

  int m = 1000;

  for (int i=0; i<m; i++)
  {
    if (i % (2*dashParam) > dashParam)
      continue;

    float theta =
      map(
        (i + 38*t*float(dashParam)) % m,
        0,
        m,
        0,
        PI
      );

    float phi =
      (t + 0.006) * TAU;

    float x =
      R2 * sin(theta) * cos(phi);

    float y =
      R2 * cos(theta);

    float z =
      R2 * sin(theta) * sin(phi);

    PVector pos =
      new PVector(x, y, z);

    showParticle(
      pos,
      0.70,
      false,
      0,
      11.0
    );
  }

  // Pole dots.
  PVector pole1Position =
    new PVector(0, R2, 0);

  PVector pole2Position =
    new PVector(0, -R2, 0);

  showParticle(
    pole1Position,
    3.6,
    false,
    0,
    600
  );

  showParticle(
    pole2Position,
    3.6,
    false,
    0,
    600
  );
}

class Digit
{
  PVector position0;
  int digitValue;

  Digit(int i)
  {
    // Binary only, but randomised once so the globe does not form
    // visually obvious 010101 bands.
    digitValue = int(random(2));

    // Fibonacci sphere distribution.
    float phi =
      PI * (3.0 - sqrt(5.0));

    float theta =
      phi * i;

    float y =
      map(
        i,
        0,
        numberOfDigits - 1,
        1,
        -1
      );

    float radius =
      sqrt(1 - y*y);

    y *= R;

    float x =
      cos(theta) *
      R *
      radius;

    float z =
      sin(theta) *
      R *
      radius;

    position0 =
      new PVector(x, y, z);
  }

  void show(float p)
  {
    float delayFromAngle =
      atan2(
        position0.z,
        position0.x
      ) / TAU;

    float delay =
      delayFromAngle / 2;

    float delayedP =
      (1234 + p - delay) % 1;

    float angleChangeProgress =
      -pow(
        1-delayedP,
        2.0
      );

    // Core push-wave movement.
    PVector position =
      rotY(
        position0,
        angleChangeProgress * TAU
      );

    // Size wave.
    float wo =
      (1234 - 4*p + delayFromAngle) % 1;

    float wv =
      pow(
        c01(
          sin(PI*wo)
        ),
        3.3
      );

    // Slightly restrained sizing for binary glyphs.
    float sizeFactor =
      2.45 + 1.20*wv;

    // Push bump.
    float bumpMax = 0.42;

    float bump =
      1 +
      bumpMax *
      pow(
        1-c01(27*delayedP),
        2.3
      );

    float bump2 =
      1 +
      bumpMax *
      pow(
        1-c01(
          100*(1-delayedP)
        ),
        2.0
      );

    float sizeFactor2 =
      sizeFactor *
      bump *
      bump2;

    showParticle(
      position,
      sizeFactor2,
      true,
      digitValue,
      1.0
    );
  }

  void show()
  {
    // Preserve the two-pass replacement behaviour.
    int K = 2;

    for (int i=0; i<K; i++)
      show((i+t)/K);
  }
}

ArrayList<Digit> digitsArray =
  new ArrayList<Digit>();

void setup()
{
  size(600, 600, P2D);

  result =
    new int[width*height][3];

  smooth(8);

  // Stable binary layout every render.
  randomSeed(2603);

  // Clean sans glyphs so 0 and 1 stay readable.
  uiFont =
    createFont(
      "SansSerif",
      128,
      true
    );

  textFont(uiFont);

  for (int i=0; i<numberOfDigits; i++)
  {
    digitsArray.add(
      new Digit(i)
    );
  }
}

void draw_()
{
  // Keep black during rendering.
  // The workflow converts black to transparency afterwards.
  // This retains the original clean motion-blur behaviour.
  background(0);

  push();

  translate(
    width/2,
    height/2
  );

  for (Digit digit : digitsArray)
    digit.show();

  showDashedCurve();

  pop();
}
