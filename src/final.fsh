#version 120

#define BLOOM
#define BLOOM_STRENGTH 0.25	// [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define BLOOM_LOD 16		// [1 2 4 8 16 32 64]
#define BLUR_STEPS_X 64		// [1 2 4 8 16 32 64]
#define BLUR_SCALE_X 2		// [1 2 3 4]
//#define BLOOM_DEBUG

//#define DEBUG_OVERBRIGHT

#define CROSSPROCESS

#define TONEMAP

uniform sampler2D colortex0;
uniform sampler2D colortex1;

uniform int hideGUI;

uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;

bool isEven(int num) {
	return ((num / 2) * 2) == num;
}

vec3 getBlur() {
	float lod = BLOOM_LOD;
	vec2 offset;
	if(lod > 1) {
		offset = vec2(0.25f);
	}else{
		offset = vec2(0.0f);
	}
	
	vec3 blur = vec3(0.0f);
	
	vec2 newTexcoord = (texcoord / lod) + offset;
	
	
	int quality = BLUR_STEPS_X;
	float scale = BLUR_SCALE_X;
	float qh;
	if(isEven(quality)){
		qh = quality / 2 - 0.5f;
	}else{
		qh = quality / 2;
	}
	float total = 0.0f;
	
	for(int i=0; i < quality; i++){
		vec2 offset = vec2((1.0f / viewWidth) * (i - qh) * scale, 0.0f);
		float strength = sin(((i + 1) / float(quality + 1)) * 3.14159);
		
		//if(newTexcoord.x >= 0.0f && newTexcoord.y >= 0.0f && newTexcoord.x <= 1.0f && newTexcoord.y <= 1.0f) { }
		blur += texture2D(colortex1, newTexcoord + offset).rgb * strength;
		total += strength;
	}
	
	blur /= total;
	//blur = pow(blur, vec3(2.0f));
	
	return blur;
}

// Tonemaps from https://github.com/dmnsgn/glsl-tone-map

vec3 aces(vec3 x) {
	/*
	const float a = 2.51;
	const float b = 0.03;
	const float c = 2.43;
	const float d = 0.59;
	const float e = 0.14;
	*/
	/*
	const float a = 1.4;
	const float b = 0.09;
	const float c = 1.0;
	const float d = 0.5;
	const float e = 0.15;
	*/
	/*
	const float a = 1.5;
	const float b = 0.39;
	const float c = 1.0;
	const float d = 0.8;
	const float e = 0.25;
	*/
	const float a = 1.7;
	const float b = 0.29;
	const float c = 1.0;
	const float d = 0.8;
	const float e = 0.25;
	
	return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

vec3 uncharted2Tonemap(vec3 x) {
	/*
	Original
	float A = 0.15;
	float B = 0.50;
	float C = 0.10;
	float D = 0.20;
	float E = 0.02;
	float F = 0.30;
	float W = 11.2;
	*/
	/*
	float A = 0.3;
	float B = 2.00;
	float C = 0.10;
	float D = 1.50;
	float E = 0.02;
	float F = 1.50;
	float W = 11.2;
	*/
	float A = 0.15;
	float B = 0.50;
	float C = 0.10;
	float D = 0.20;
	float E = 0.02;
	float F = 0.30;
	float W = 11.2;
	return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

vec3 uncharted2(vec3 color) {
	const float W = 11.2;
	float exposureBias = 8.0;
	vec3 curr = uncharted2Tonemap(exposureBias * color);
	vec3 whiteScale = 1.0 / uncharted2Tonemap(vec3(W));
	return curr * whiteScale;
}

float getLuma(vec3 color) {
  return dot(color, vec3(0.299, 0.587, 0.114));
}

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void main() {
	vec3 color = texture2D(colortex0, texcoord).rgb;
	
	#ifdef BLOOM
	vec3 bloom = getBlur();
	
	color = color + bloom * BLOOM_STRENGTH;
	#endif
	
	//color *= 1.25f;
	
	#ifdef CROSSPROCESS
	//float brightness = getLuma(color);			
	float brightness = rgb2hsv(color).b;
	
	/*
	if(texcoord.x < 0.5f) {
		vec3 darkColor = color * vec3(0.0f, 0.7f, 1.0f) * 1.4f;
		vec3 brightColor = color * vec3(1.0f, 0.7f, 0.0f) * 1.4f;
		//vec3 brightColor = color * vec3(1.0f, 0.75f, 0.3f) * 1.6f;
		
		color = mix(color, darkColor, (1.0f - brightness) * 0.15f);
		color = mix(color, brightColor, brightness * 0.25f);
	}
	*/
	float crossProcessGamma = 1.6f;
	float crossProcessStrength = 0.5f;
	
	float darkFactor = (1.0f - pow(brightness, 1.0f / crossProcessGamma)) - 0.5f;
	float brightFactor = (pow(brightness, crossProcessGamma)) - 0.5f;
	
	vec3 darkColor = color * vec3(0.0f, 0.7f, 1.0f) * 1.3f;
	vec3 brightColor = color * vec3(1.0f, 1.0f, 0.0f) * 1.3f;
	
	color = mix(color, darkColor, clamp(darkFactor * crossProcessStrength, 0.0f, 1.0f));
	//color = mix(color, brightColor, clamp(brightColor * crossProcessStrength, 0.0f, 1.0f));
	
	#endif
	
	#ifdef TONEMAP
	color = aces(color);	
	//color = uncharted2(color);	
	#endif
	
	#ifdef DEBUG_OVERBRIGHT
	if(color.r < 0.0f || color.g < 0.0f || color.b < 0.0f) color.rgb = vec3(0.0f, 0.0f, 1.0f);
	if(color.r > 1.0f || color.g > 1.0f || color.b > 1.0f) color.rgb = vec3(1.0f, 1.0f, 0.0f);
	#endif
	
	/*
	vec3 newColor;
	newColor.r = (1.086 * color.r) + (-0.072 * color.g) + (-0.014 * color.b);
	newColor.g = (0.097 * color.r) + (0.845 * color.g) + (0.058 * color.b);
	newColor.b = (-0.014 * color.r) + (-0.028 * color.g) + (1.042 * color.b);
	color = clamp(newColor, 0.0, 1.0);
	*/
	/*
	vec3 newColor;
	newColor.r = (0.914 * color.r) + (0.078 * color.g) + (0.008 * color.b);
	newColor.g = (-0.105 * color.r) + (1.172 * color.g) + (-0.067 * color.b);
	newColor.b = (0.010 * color.r) + (0.032 * color.g) + (0.958 * color.b);
	color = clamp(newColor, 0.0, 1.0);
	*/
	
	#ifdef BLOOM
	#ifdef BLOOM_DEBUG
	if(hideGUI != 0){
		color = bloom;
	}
	#endif
	#endif
	
	gl_FragData[0] = vec4(color, 1.0f);
}