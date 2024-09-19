#version 120

uniform sampler2D lightmap;

varying vec2 texcoord;
varying vec4 color;

void main() {
	color = gl_Color * texture2D(lightmap, clamp(gl_MultiTexCoord1.xy / 256.0f, 0.5f / 16.0f, 15.5f / 16.0f));
	texcoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();
}