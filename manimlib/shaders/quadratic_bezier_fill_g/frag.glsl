#version 330

uniform bool winding;
uniform vec3[2] gradient_line;

in vec4 color;
in float fill_all;
in float orientation;
in vec2 uv_coords;
in vec3 xyz_coords;

out vec4 frag_color;

#INSERT add_gradient.glsl

vec2 gradient_interpolate(float[3] gradient_scale, float alpha) {
    int index = 0;
    for (int i = 0; i < 37; i++) {
        if (alpha <= gradient_scale[i]) {
            index = max(i-1, 0);
            break;
        }
    }
    float color_alpha = 0.0;
    color_alpha = clamp((alpha - gradient_scale[index]) / (gradient_scale[index + 1] - gradient_scale[index]), 0.0, 1.0);
    return vec2(index, color_alpha);
}

void main() {
    if (color.a == 0) discard;
    float distance = distance(gradient_line[0], gradient_line[1]);
    if (distance == 0.0){
        frag_color = color;
    }
    else{
        float alpha = 0.0; 
        alpha = alpha_along_gradient_line(xyz_coords, gradient_line[0], gradient_line[1]);
        int num = 2;
        float[3] gradient_scale = float[3](0, .3, 1);
        vec4[3] gradient_color = vec4[3](vec4(1,0,0,1), vec4(0,1,0,1), vec4(0,0,1,1));
        vec2 gradient_interpolate = gradient_interpolate(gradient_scale, alpha);
        int index = int(gradient_interpolate[0]);
        float color_alpha = gradient_interpolate[1];
        frag_color = mix(gradient_color[index],gradient_color[index+1], color_alpha);
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
