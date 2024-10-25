#version 410

// Output for on-screen color
layout(location = 0) out vec4 outColor;

//Textures
uniform sampler2D accumulator_texture;
uniform ivec2 screen_dimensions;

//Set gl_FragCoord to pixel center
layout(pixel_center_integer) in vec4 gl_FragCoord;

void main()
{
    vec2 pixelCoords = gl_FragCoord.xy;
    vec2 texCoord = pixelCoords/screen_dimensions;
    vec4 accumulatedData = texture(accumulator_texture, texCoord);
    
    vec3 averageColor = accumulatedData.xyz;
	float sampleCount = accumulatedData.w;
    
    outColor = vec4(averageColor/sampleCount, 1);  



}
