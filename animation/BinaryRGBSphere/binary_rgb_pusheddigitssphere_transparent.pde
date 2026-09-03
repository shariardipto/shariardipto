float[][] result; // RGBA buffer for transparent motion blur
float t;              // global time in [0,1[
float c;              // testing variable controlled by mouse

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
// Synchronized RGB cycle
// Red → Purple → Blue → Cyan → Green → Yellow → Red

int[][] RGB_FLOW = {
  {255,   0,   0},   // Red
  {170,   0, 255},   // Purple
  {  0,  90, 255},   // Blue
  {  0, 220, 255},   // Cyan
  {  0, 255, 110},   // Green
  {255, 225,   0}    // Yellow
};

color syncedRGB(float phase)
{
  phase = ((phase % 1.0) + 1.0) % 1.0;

  float scaled = phase * RGB_FLOW.length;
  int i0 = floor(scaled) % RGB_FLOW.length;
  int i1 = (i0 + 1) % RGB_FLOW.length;

  float f = scaled - floor(scaled);

  // Smooth interpolation so transitions do not feel abrupt.
  f = f*f*(3.0 - 2.0*f);

  float r = lerp(RGB_FLOW[i0][0], RGB_FLOW[i1][0], f);
  float g = lerp(RGB_FLOW[i0][1], RGB_FLOW[i1][1], f);
  float b = lerp(RGB_FLOW[i0][2], RGB_FLOW[i1][2], f);

  return color(r, g, b);
}

//-----------------------------------

void draw()
{
  if (!recording) // test mode
  {
    t = (mouseX*1.3/width) % 1;
    c = mouseY*1.0/height;

    if (mousePressed)
      println(c);

    draw_();
  }
  else // render mode with transparent motion blur
  {
    // Reset RGBA accumulation buffer.
    for (int i=0; i<width*height; i++)
      for (int a=0; a<4; a++)
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

      // Premultiplied-alpha accumulation.
      // This keeps transparent motion blur clean and avoids black halos.
      for (int i=0; i<pixels.length; i++)
      {
        float a = alpha(pixels[i]) / 255.0;

        result[i][0] += red(pixels[i])   * a;
        result[i][1] += green(pixels[i]) * a;
        result[i][2] += blue(pixels[i])  * a;
        result[i][3] += alpha(pixels[i]);
      }
    }

    loadPixels();

    for (int i=0; i<pixels.length; i++)
    {
      float alphaSum = result[i][3];

      if (alphaSum <= 0.001)
      {
        pixels[i] = color(0, 0, 0, 0);
      }
      else
      {
        float weightSum = alphaSum / 255.0;

        int rr = int(result[i][0] / weightSum);
        int gg = int(result[i][1] / weightSum);
        int bb = int(result[i][2] / weightSum);

        int aa = int(alphaSum / samplesPerFrame);

        rr = constrain(rr, 0, 255);
        gg = constrain(gg, 0, 255);
        bb = constrain(bb, 0, 255);
        aa = constrain(aa, 0, 255);

        pixels[i] = color(rr, gg, bb, aa);
      }
    }

    updatePixels();

    // PNG is used instead of GIF because PNG preserves transparency.
    if (frameCount <= numFrames)
    {
      saveFrame("data/fr###.png");
      println(frameCount, "/", numFrames);
    }

    if (frameCount == numFrames)
      stop();
  }
}

// End of template
//////////////////////////////////////////////////////////////////////////////

int samplesPerFrame = 8;
int numFrames = 330;
float shutterAngle = 0.8;

boolean recording = false;

PFont mono;

int numberOfDigits = 210;
float R = 125;

// 3D is handled with a custom projection while using P2D.

float cameraZ()
{
  return 300.0;
}

PVector positionTransform(PVector v)
{
  PVector res;

  // Same globe tilt / subtle temporal movement.
  res = rotZ(
    v.copy(),
    0.17 * PI + 0.03 * PI * sin(TAU*(t-0.3))
  );

  return res;
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

  float alphaFactor2 =
    map(position.z, -R, R, 0.45, 1.3) * alphaFactor;

  float zDistanceFromCamera = cameraZ() - position.z;

  if (zDistanceFromCamera > 0)
  {
    // 3D -> 2D perspective projection.
    float x2D =
      projectionFactor * position.x / zDistanceFromCamera;

    float y2D =
      projectionFactor * position.y / zDistanceFromCamera;

    PVector pixelPosition = new PVector(x2D, y2D);

    // One synchronized color for the whole globe at this moment.
    color globeColor = syncedRGB(t);

    if (isDigit)
    {
      float textSz = 29;

      float scl =
        0.1 * sizeFactor *
        projectionFactor /
        zDistanceFromCamera;

      push();

      translate(
        pixelPosition.x - 0.5*textSz/2,
        pixelPosition.y + 0.5*textSz/2
      );

      scale(scl);

      // Slight 2D rotational breathing.
      rotate(
        0.03 *
        sin(TAU*(t-0.3)) *
        PI
      );

      float digitAlpha =
        constrain(alphaFactor2 * 275, 0, 255);

      fill(globeColor, digitAlpha);
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

      float dotAlpha =
        constrain(21 * alphaFactor2, 0, 255);

      stroke(globeColor, dotAlpha);
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

    // Spherical coordinates.
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

    // Cartesian coordinates from spherical coordinates.
    float x =
      R2 * sin(theta) * cos(phi);

    float y =
      R2 * cos(theta);

    float z =
      R2 * sin(theta) * sin(phi);

    PVector pos =
      new PVector(x, y, z);

    float sizeFactor = 0.73;
    boolean isDigit = false;
    float alphaFactor = 14.0;

    showParticle(
      pos,
      sizeFactor,
      isDigit,
      0,
      alphaFactor
    );
  }

  // Large dots at the two sphere poles.
  PVector pole1Position =
    new PVector(0, R2, 0);

  PVector pole2Position =
    new PVector(0, -R2, 0);

  showParticle(
    pole1Position,
    4,
    false,
    0,
    1000
  );

  showParticle(
    pole2Position,
    4,
    false,
    0,
    1000
  );
}

class Digit
{
  PVector position0;
  int digitValue;

  Digit(int i)
  {
    // CHANGE 1:
    // Use only binary digits instead of 0–9.
    digitValue = i % 2;

    // Evenly distributed points over the sphere.
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
        1 - delayedP,
        2.0
      );

    // Wave-driven movement around the sphere.
    PVector position =
      rotY(
        position0,
        angleChangeProgress * TAU
      );

    // Digit size wave.
    float wo =
      (1234 - 4*p + delayFromAngle) % 1;

    float wv =
      pow(
        c01(
          sin(PI*wo)
        ),
        3.3
      );

    float sizeFactor =
      2.8 + 1.3*wv;

    // Size bump when the movement begins / ends.
    float bumpMax = 0.5;

    float bump =
      1 +
      bumpMax *
      pow(
        1 - c01(27*delayedP),
        2.3
      );

    float bump2 =
      1 +
      bumpMax *
      pow(
        1 - c01(
          100*(1-delayedP)
        ),
        2.0
      );

    float sizeFactor2 =
      sizeFactor *
      bump *
      bump2;

    boolean isDigit = true;
    float alphaFactor = 1.0;

    showParticle(
      position,
      sizeFactor2,
      isDigit,
      digitValue,
      alphaFactor
    );
  }

  // Replacement technique retained so the motion structure stays intact.
  void show()
  {
    int K = 2;

    for (int i=0; i<K; i++)
    {
      show(
        (i+t) / K
      );
    }
  }
}

ArrayList<Digit> digitsArray =
  new ArrayList<Digit>();

void setup()
{
  size(600, 600, P2D);

  // RGBA instead of RGB-only buffer.
  result =
    new float[width*height][4];

  smooth(8);

  // Optional custom font:
  // mono = createFont("Manrope-Medium.ttf", 128);
  // textFont(mono);

  for (int i=0; i<numberOfDigits; i++)
  {
    digitsArray.add(
      new Digit(i)
    );
  }
}

void draw_()
{
  // CHANGE 2:
  // Fully transparent background instead of background(0).
  clear();

  push();

  translate(
    width/2,
    height/2
  );

  for (Digit digit : digitsArray)
  {
    digit.show();
  }

  showDashedCurve();

  pop();
}
