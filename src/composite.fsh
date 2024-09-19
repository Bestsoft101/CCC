#version 120

#define BLOOM
#define BLOOM_TRESHOLD 0.25	// [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define BLOOM_LOD 16		// [1 2 4 8 16 32 64]
#define BLUR_STEPS_Y 4		// [1 2 4 8 16 32 64]
#define BLUR_SCALE_Y 1		// [1 2 3 4]

const bool colortex0MipmapEnabled = true;

uniform sampler2D colortex0;

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
	
	vec2 newTexcoord = (texcoord - offset) * lod;
	float padding = 0.001f * lod;
	
	if(newTexcoord.x > -padding && newTexcoord.y > -padding && newTexcoord.x < 1.0f + padding && newTexcoord.y < 1.0f + padding) {
		int quality = BLUR_STEPS_Y;
		float scale = BLUR_SCALE_Y;
		float qh;
		if(isEven(quality)){
			qh = quality / 2 - 0.5f;
		}else{
			qh = quality / 2;
		}
		float total = 0.0f;
		
		for(int i=0; i < quality; i++){
			vec2 offset = vec2(0.0f, (1.0f / viewHeight) * (i - qh) * (scale * lod));
			float strength = sin(((i + 1) / float(quality + 1)) * 3.14159);
			
			vec3 blurLayer = texture2D(colortex0, newTexcoord + offset).rgb * strength;
			blurLayer = blurLayer * (1.0f + BLOOM_TRESHOLD) - BLOOM_TRESHOLD;
			blurLayer *= vec3(1.0f, 0.7f, 0.0f);
			//blurLayer = pow(blurLayer, vec3(2.0f));
			blurLayer = clamp(blurLayer, 0.0f, 1.0f);
		
			blur += blurLayer;
			total += strength;
		}
		
		blur /= total;
		
	}
	
	return blur;
}

void main() {
	vec3 blur = vec3(0.0f);
	
	#ifdef BLOOM
	blur = getBlur();
	#endif
	
	/* DRAWBUFFERS:01 */
	gl_FragData[0] = texture2D(colortex0, texcoord);
	gl_FragData[1] = vec4(blur, 1.0f);
}