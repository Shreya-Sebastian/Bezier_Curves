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
        if (current_position.x <= screen_dimensions.x && current_position.y <= screen_dimensions.y)
        {
        
            vec2 texturePosition = current_position/screen_dimensions;
            int pixelID = texture(rasterized_texture, texturePosition).x;

            if (pixelID > 0)
            {
                return current_position; // Return intersection
            }
        }
        current_position = current_position + step_size*direction;
     }
     return vec2(-1, -1); // No intersection found
}

vec2 hash2(vec2 p) {
    // Hash function adapted for 2D input
    p = vec2(dot(p, vec2(127.1, 311.7)),
             dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

uint xseed = 632891u;
uint yseed = 283954u;

void main()
{

    vec2 pixelCenter = gl_FragCoord.xy;


    vec3 accumulatedColour = vec3(0.0);
    int totalSamples = 0;
    vec4 circleColour;

    //If a shape is hit we can sample it
    bool hit = false;
    vec2 intersectionPos = vec2(-1,-1);

    vec2 xy = pixelCenter* get_random_numbers(xseed);
    xy *= get_random_numbers(yseed);
    
    vec2 random_direction = hash2(xy);

    random_direction = normalize(random_direction);
    
    intersectionPos = march_ray(pixelCenter, random_direction, step_size);

    vec2 texCoord = intersectionPos/screen_dimensions;
        

    if (intersectionPos.x > -1 && intersectionPos.y > -1)
    {
        hit = true;
    }

    if(hit){
        // ---- Circle
        if (shape_type == 0) {

            int circleID = texture(rasterized_texture, texCoord).x;
            circleColour = circles[circleID].color;
                
                
            //check if pixelCenter is within circle (circleID)
            if (distance(pixelCenter,circles[circleID].position) < circles[circleID].radius)
            {
                accumulatedColour += circleColour.xyz;
                totalSamples += 1;  // Increase the sample count
                    
            }
                
        }
            
        // ---- Line
        else if (shape_type == 1) {
            
            //outColor = texture(rasterized_texture, pixelCenter /screen_dimensions);
            // Get the line ID from the rasterized texture
            int lineID = texture(rasterized_texture, texCoord).x;
            
            // Retrieve line data from the buffer
            vec2 lineStart = lines[lineID].start_point;
            vec2 lineEnd = lines[lineID].end_point;
            vec4 colorLeft = lines[lineID].color_left[0];  // Use the left color for sampling
            vec4 colorRight = lines[lineID].color_right[0]; // Use the right color for sampling
            
            // Calculate the line direction and length
            vec2 lineDirection = lineEnd - lineStart;
            float lineLength = length(lineDirection);
            vec2 lineDirNormalized = normalize(lineDirection);
            
            // Project the pixel center onto the line to find the closest point on the line segment
            vec2 startToPixel = pixelCenter - lineStart;
            float projectionLength = dot(startToPixel, lineDirNormalized);
            vec2 closestPointOnLine;
            
            // Determine the closest point on the line segment
            if (projectionLength < 0.0) {
                closestPointOnLine = lineStart;  // Before the start of the line
            } else if (projectionLength > lineLength) {
                closestPointOnLine = lineEnd;    // After the end of the line
            } else {
                closestPointOnLine = lineStart + lineDirNormalized * projectionLength;
            }
            
            // Calculate the distance from the pixel to the closest point on the line
            float distanceToLine = distance(closestPointOnLine, pixelCenter);
            
            // Handle round caps at the start and end points
            float distanceToStart = distance(lineStart, pixelCenter);
            float distanceToEnd = distance(lineEnd, pixelCenter);

            float side = sign((lineEnd.x - lineStart.x) * (pixelCenter.y - lineStart.y) - (lineEnd.y - lineStart.y) * (pixelCenter.x - lineStart.x));

            // Weight calculation
            float weight = 1.0 / (length(pixelCenter - intersectionPos) + 0.001); // epsilon value
            // If the pixel is close enough to the line, add color to the accumulated colour
            // Choose color based on the distance to start or end for linear gradient
            if (distanceToStart <= step_size) {
                accumulatedColour += weight * colorLeft.xyz; // Color from the start cap
            } else if (distanceToEnd < step_size) {
                accumulatedColour += weight * colorRight.xyz; // Color from the end cap
            } else {
                // Blend colors for a smooth transition along the line
                float blendFactor = 1.0 - (distanceToLine / step_size); // Blending based on distance
                accumulatedColour += mix(colorLeft.xyz, colorRight.xyz, blendFactor);
            }
            totalSamples += 1;  // Increase the sample count
        }
    }

    vec3 previousAccumulatedColor = texture(accumulator_texture, pixelCenter/screen_dimensions).xyz;

    accumulatedColour = (previousAccumulatedColor + accumulatedColour)/2.f;

    outColor = vec4(accumulatedColour, totalSamples);
}
