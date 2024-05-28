#version 330

uniform bool winding;
uniform float gradient_mode;
uniform int gradient_size;
uniform vec3[~gradient_points] gradient_points;
uniform float[~gradient_size] gradient_scale;
uniform vec4[~gradient_size] gradient_color;

in vec4 color;
in float fill_all;
in float orientation;
in vec2 uv_coords;
in vec3 xyz_coords;

out vec4 frag_color;

#INSERT add_gradient.glsl

vec2 gradient_interpolate(float[~gradient_size] gradient_scale, float alpha) {
    int index = 0;
    for (int i = 0; i < ~gradient_size; i++) {
        if (alpha <= gradient_scale[i]) {
            index = max(i-1, 0);
            break;
        }
    }
    float color_alpha = 0.0;
    color_alpha = clamp((alpha - gradient_scale[index]) / (gradient_scale[index + 1] - gradient_scale[index]), 0.0, 1.0);
    return vec2(index, color_alpha);
}

vec4 mixed_gradient_color(vec3 coord) {
    vec4 resultColor = vec4(0.0);
    float totalWeight = 0.0;
    float distance_01 = length(gradient_points[1] - gradient_points[0]);
    float scale_factor = distance_01/gradient_points[~gradient_points - 1].x;
    for (int i = 0; i < ~gradient_size; i++) {
        float offset = scale_factor*gradient_scale[i];
        float distance = length(coord - gradient_points[i]);
        if (distance < 0.001 + offset) {
            return gradient_color[i];
        }
        distance -= offset;
        float weight = 1.0 / (distance * distance);
        resultColor += gradient_color[i] * weight;
        totalWeight += weight;
    }
    if (totalWeight > 0.0) {
        resultColor /= totalWeight;
    }
    return resultColor;
}

vec4 mixed_diamond_gradient(vec3 coord) {
    vec4 resultColor = vec4(0.0);
    float totalWeight = 0.0;
    for (int i = 0; i < ~gradient_points; i++) {
        float distance = abs(coord.x - gradient_points[i].x) + abs(coord.y - gradient_points[i].y);
        if (distance < 0.001) {
            return gradient_color[i];
        }
        float weight = 1.0 / (distance * distance);
        resultColor += gradient_color[i] * weight;
        totalWeight += weight;
    }
    if (totalWeight > 0.0) {
        resultColor /= totalWeight;
    }
    return resultColor;
}

void main() {
    if (color.a == 0) discard;
    if (gradient_mode == 0){
        frag_color = color;
    }
    else if (gradient_mode == 1){
        float alpha = 0.0; 
        alpha = alpha_along_gradient_line(xyz_coords, gradient_points[0], gradient_points[1]);
        if (alpha >= 1){
            frag_color = gradient_color[gradient_size - 1];
        }
        else if (alpha < 1){
            vec2 gradient_interpolate = gradient_interpolate(gradient_scale, alpha);
            int index = int(gradient_interpolate[0]);
            float color_alpha = gradient_interpolate[1];
            frag_color = mix(gradient_color[index],gradient_color[index+1], color_alpha);
        }
    }
    else if (gradient_mode == 2){
        float alpha = 0.0;
        float dist = distance(gradient_points[0].xy, gradient_points[1].xy);
        alpha = distance(gradient_points[0].xy, xyz_coords.xy)/dist;
        if (alpha >= 1){
            frag_color = gradient_color[gradient_size - 1];
        }
        else if (alpha < 1){
            vec2 gradient_interpolate = gradient_interpolate(gradient_scale, alpha);
            int index = int(gradient_interpolate[0]);
            float color_alpha = gradient_interpolate[1];
            frag_color = mix(gradient_color[index],gradient_color[index+1], color_alpha);
        }
    }
    else if (gradient_mode == 3){
        frag_color = mixed_gradient_color(xyz_coords);
    }
    /*
    We want negatively oriented triangles to be canceled with positively
    oriented ones. The easiest way to do this is to give them negative alpha,
    and change the blend function to just add them. However, this messes with
    usual blending, so instead the following line is meant to let this canceling
    work even for the normal blending equation:

    (1 - alpha) * dst + alpha * src

    We want the effect of blending with a positively oriented triangle followed
    by a negatively oriented one to return to whatever the original frag value
    was. You can work out this will work if the alpha for negative orientations
    is changed to -alpha / (1 - alpha). This has a singularity at alpha = 1,
    so we cap it at a value very close to 1. Effectively, the purpose of this
    cap is to make sure the original fragment color can be recovered even after
    blending with an (alpha = 1) color.
    */
    if(winding){
        float a = 0.95 * frag_color.a;
        if(orientation < 0) a = -a / (1 - a);
        frag_color.a = a;
    }

    if (bool(fill_all)) return;

    float x = uv_coords.x;
    float y = uv_coords.y;
    float Fxy = (y - x * x);
    if(!winding && orientation < 0) Fxy *= -1;
    if(Fxy < 0) discard;
}
