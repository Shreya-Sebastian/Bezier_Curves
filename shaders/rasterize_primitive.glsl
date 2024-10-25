#version 410

// Output for shape id
layout(location = 0) out int shape_id;

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

//The type of the shape we are rasterizing, the same as the enumerator in shapes.h
// 0 - circles
// 1 - lines
// 2 - BezierCurves (Unused)
uniform uint shape_type;

//The maximum distance to the shape for a pixel to be part of the shape
uniform float rasterize_width;

void main()
{
    // ---- CIRCLE
    if (shape_type == 0) {
        
        vec2 pixelCentre = gl_FragCoord.xy;
        shape_id = -1;
        for(int x = 0; x < circle_count; x++)
        {

            vec2 circleCenter = circles[x].position;
            float r = circles[x].radius;
            float inner = r - rasterize_width;
            float outer = r + rasterize_width;

            //calc if pixel center within threshold 
            float dist = distance(circleCenter, pixelCentre);

            if(dist < outer && dist > inner)
            {
                if(shape_id < 0)
                {
                    shape_id = x; 
                    break;
                }
            }
        }
    }

    // ---- LINE
    else if (shape_type == 1) {
        vec2 pixelCentre = gl_FragCoord.xy;
        shape_id = -1;

        for (int x = 0; x < line_count; x++) {
            vec2 lineStart = lines[x].start_point;
            vec2 lineEnd = lines[x].end_point;

            // Calculate the direction vector and length of the line
            vec2 lineDirection = lineEnd - lineStart;
            float lineLength = length(lineDirection);

            // Project the pixel onto the line to find the closest point on the line segment
            vec2 startToPixel = pixelCentre - lineStart;
            float projectionLength = dot(startToPixel, lineDirection) / lineLength;
            vec2 closestPointOnLine = vec2(-1.f, -1.f);

            if (projectionLength <= 0.f) {
                closestPointOnLine = lineStart;  // Before the start of the line
            } else if (projectionLength >= lineLength) {
                closestPointOnLine = lineEnd;    // After the end of the line
            } else {
                closestPointOnLine = lineStart + normalize(lineDirection) * projectionLength;
            }

            // Calculate the distance from the pixel to the closest point on the line
            float distanceToLine = distance(pixelCentre, closestPointOnLine);

            // Handle the round caps at the start and end points
            float distanceToStart = distance(lineStart, pixelCentre);
            float distanceToEnd = distance(lineEnd, pixelCentre);

            if ((distanceToLine <= rasterize_width)) {
                if (shape_id < 0) {
                    shape_id = x;
                    break;
                }
            }
        }
    }
}