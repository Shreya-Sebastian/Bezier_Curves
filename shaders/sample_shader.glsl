#version 410

#define M_PI 3.14159265359f

// Output for accumulated color
layout(location = 0) out vec4 outColor;

//Set gl_FragCoord to pixel center
layout(pixel_center_integer) in vec4 gl_FragCoord;


//Circle and line struct equivalent to the one in shape.h
struct Circle {
    vec4 color;
    vec2 position;
    float radius;
};

struct Line {
    vec2 start_point;
    vec2 end_point;
    vec4 color_left[2];
    vec4 color_right[2];
};

//The uniform buffers for the shapes containing the count of shapes in the first slot and after that, the actual shapes
//We need to give the arrays a fixed size to work with opengl 4.1
layout(std140) uniform circleBuffer
{
    int circle_count;
    Circle circles[32];
};

layout(std140) uniform lineBuffer
{
    int line_count;
    Line lines[800];
};

//Textures for the rasterized shapes, and the accumulator
uniform isampler2D rasterized_texture;
uniform sampler2D accumulator_texture;

//The type of the shape we are rasterizing, the same as the enumerator in shapes.h
// 0 - circles
// 1 - lines
// 2 - BezierCurves (Unused)
uniform uint shape_type;

//The number of samples we have already taken
uniform uint frame_nr;
//Screen dimensions
uniform ivec2 screen_dimensions;

//Step size for ray-marching
uniform float step_size; 

//The maximum amount of raymarching steps we can take
uniform uint max_raymarch_iter;

//Random number generator outputs numbers between [0-1]
float get_random_numbers(inout uint seed) {
    seed = 1664525u * seed + 1013904223u;
    seed += 1664525u * seed;
    seed ^= (seed >> 16u);
    seed += 1664525u * seed;
    seed ^= (seed >> 16u);
    return seed * pow(0.5, 32.0);
}
vec2 march_ray(vec2 origin, vec2 direction, float step_size) 
{
    vec2 current_position = origin;

    for (uint x = 0; x <= max_raymarch_iter; x++)
    {
        if (current_position.x > screen_dimensions.x && current_position.y > screen_dimensions.y)
        {
            current_position = current_position + step_size*direction;
        
            vec2 texturePosition = current_position/screen_dimensions;
            int pixelID = texture(rasterized_texture, texturePosition).x;

            if (pixelID >= 0)
            {
                return current_position;
            }
        }
     }
}

void main()
{
    int numSamples = 100;

    vec2 pixelCenter = gl_FragCoord.xy;
    uint xseed = 69420u * int(pixelCenter.x);
    uint yseed = 69420u * int(pixelCenter.y);

    vec3 averageColor = vec3(0.f);

    for(int i = 0; i < numSamples; i++)
    {
        //If a shape is hit we can sample it
        bool hit = false;
        vec2 intersectionPos = vec2(-1,-1);

        float x = get_random_numbers(xseed);
        float y = get_random_numbers(yseed);

        vec2 random_direction = vec2(x, y);
    
        intersectionPos = march_ray(pixelCenter, random_direction, step_size);

        vec2 texCoord = intersectionPos/screen_dimensions;

        if (intersectionPos.x > -1 && intersectionPos.y > -1)
        {
            hit = true;
        }

        if(hit){
            // ---- Circle
            if (shape_type == 0) {
                vec4 pixelColour;
                int circleID = texture(rasterized_texture, texCoord).x;
                vec4 circleColour = circles[circleID].color;
                //check if pixelCenter is within circle (circleID)
                if (distance(pixelCenter,circles[circleID].position) < circles[circleID].radius)
                {
                
                    //keep sample
                    //pixelColour = ;
                }
                
            }
            // ---- Line
            else if (shape_type == 1) {
            }
        }
    }

    outColor = vec4(0);
}
