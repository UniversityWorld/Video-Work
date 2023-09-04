vec4 add_gradient(vec4 raw_color, vec3 point, vec3 unit_normal, vec3 light_coords, float gloss, float shadow){
    if(gloss == 0.0 && shadow == 0.0) return vec4(0,0,0,raw_color.a);

    // TODO, do we actually want this?  It effectively treats surfaces as two-sided
    if(unit_normal.z < 0){
        unit_normal *= -1;
    }

    float camera_distance = 6;  // TODO, read this in as a uniform?
    // Assume everything has already been rotated such that camera is in the z-direction
    vec3 to_camera = vec3(0, 0, camera_distance) - point;
    vec3 to_light = light_coords - point;
    vec3 light_reflection = -to_light + 2 * unit_normal * dot(to_light, unit_normal);
    float dot_prod = dot(normalize(light_reflection), normalize(to_camera));
    float shine = gloss * exp(-3 * pow(1 - dot_prod, 2));
    float dp2 = dot(normalize(to_light), unit_normal);
    float darkening = mix(1, max(dp2, 0), shadow);
    return vec4(
        shine, darkening, 1, raw_color.a
    );
}

float alpha_along_gradient_line(vec3 point, vec3 point_start, vec3 point_end){
	float projection_a = dot(point_end.xy - point_start.xy, point_end.xy - point_start.xy);
	float projection_b = dot(point.xy - point_start.xy, point_end.xy - point_start.xy);
	float alpha = clamp(projection_b/projection_a,0,1);
	return alpha;
}

float alpha_with_focal(vec3 point, vec3 center, vec3 focal, float r){
    float alpha = 0.0;
    float dist_p_to_f = distance(point.xy, focal.xy);     
    float dist_c_to_f = distance(center.xy, focal.xy);
    float center_pro_to_line_f_p = dot(center.xy - focal.xy, normalize(point.xy - focal.xy));
    float dist_f_to_circle = sqrt(r *r + center_pro_to_line_f_p * center_pro_to_line_f_p -  dist_c_to_f * dist_c_to_f) + center_pro_to_line_f_p;
    alpha = dist_p_to_f/dist_f_to_circle;
    return clamp(alpha, 0.0, 1.0);
}

float alpha_with_two_circle(vec3 point, vec3 center_s, vec3 center_b, float r_s, float r_b){
    float alpha = 0.0;
    if (distance(point.xy, center_b.xy) >= r_b){
        alpha = 1.0;
    }
    else if(distance(point.xy, center_s.xy) <= r_s){
        alpha = 0.0;
    }
    else{
        float dist_p_to_s = distance(point.xy, center_s.xy);     
        float dist_s_to_b = distance(center_b.xy, center_s.xy);
        float center_pro_to_line_s_p = dot(center_b.xy - center_s.xy, normalize(point.xy - center_s.xy));
        float dist_s_to_circle = sqrt(r_b *r_b + center_pro_to_line_s_p * center_pro_to_line_s_p -  dist_s_to_b * dist_s_to_b) + center_pro_to_line_s_p;
        alpha = (dist_p_to_s - r_s)/(dist_s_to_circle - r_s);
        alpha = clamp(alpha, 0.0,1.0);   
    }
    return alpha;
}

float alpha_with_two_circle_isolated(vec3 point, vec3 center_s, vec3 center_b, float r_s, float r_b, float s_to_b){
    float alpha = 0.0;
    float theta_max = asin((r_b - r_s)/distance(center_s.xy, center_b.xy));
    vec3 center_o = r_b/(r_b - r_s)*center_s - r_s/(r_b - r_s)*center_b;
    vec3 normal_c_line = vec3(normalize(center_b.xy - center_s.xy),0);
    float theta = acos(dot(point.xy -center_o.x, normal_c_line.xy)/distance(point.xy, center_o.xy));
    if(theta > theta_max){
        alpha = 2.0;
    }
    else{
        float dist_s_to_o = distance(center_o.xy, center_s.xy) + s_to_b* sqrt(r_s*r_s - distance(center_o.xy, center_s.xy)*distance(center_o.xy, center_s.xy)*sin(theta)*sin(theta));
        float dist_b_to_o = r_b/r_s*dist_s_to_o;
        float dist_p_to_o = distance(point.xy, center_o.xy);
        alpha = (dist_s_to_o - dist_p_to_o)/(dist_p_to_o - dist_p_to_o);
        alpha = clamp(alpha, 0.0,1.0);      
    }
    return alpha;
}

int is_clip_in(vec3 point, float[7] clip_data){
    int is_in =1;
    int index = 6;
    if (point.x ==0 && point.y ==0){
        return is_in;
    }
    if (clip_data[0] == 0){
        if (distance(point.xy, vec2(0,0))/clip_data[index] <= clip_data[1]){
            is_in = 1;
        }
        else{
            is_in = 0;
        }
        return is_in;
    }
    else if (clip_data[0] == 1){
        if (abs(point.x)/clip_data[index] <= clip_data[1] && abs(point.y)/clip_data[index] <= clip_data[2]){
            is_in = 1;
        }
        else{
            is_in = 0;
        }
        return is_in;
    }
    else if (clip_data[0] == 2){
        float theta = atan(point.y, point.x);
        if (distance(point.xy, vec2(0,0))/clip_data[index] <= abs(clip_data[2] + clip_data[3] * sin(clip_data[1]*theta) + clip_data[4]*cos(clip_data[1]*theta))){
            is_in = 1;
        }
        else{
            is_in = 0;
        }
        return is_in;
    }
    else if (clip_data[0] == 3){
        float theta = atan(point.y, point.x);
        int k = int(clip_data[1]);
        int m = int(clip_data[index -1]);
        is_in = 0;
        float pi = 3.1415926535897932384626433832795;
        for (int i = 0; i < m; i++){
            for (int j = 0; j < k; j++){
                if (distance(point.xy, vec2(0,0))/clip_data[index] <= cos(clip_data[1]*pi/clip_data[2])/cos(mod(theta - pi/2 + i*2*pi/clip_data[2] + j*2*pi, 2*pi*clip_data[1]/clip_data[2])-clip_data[1]*pi/clip_data[2])){
                    is_in = 1;
                    break;
                }
            }
        }       
        return is_in;
    }
    else if (clip_data[0] == 4){
        float theta = atan(point.y, point.x);
        if (distance(point.xy, vec2(0,0))/clip_data[index] <= clip_data[3] + clip_data[1] * exp(clip_data[2]*theta)){
            is_in = 1;
        }
        else{
            is_in = 0;
        }
        return is_in;
    }
    else{
        return is_in;
    }
}
