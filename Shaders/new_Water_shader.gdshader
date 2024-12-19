shader_type spatial;

uniform vec4 primary_color : source_color;
uniform vec4 secondary_color : source_color;
uniform float roughness = 0.2;
uniform sampler2D normalmap_a : hint_normal;
uniform sampler2D normalmap_b : hint_normal;
uniform float normalmap_a_strength : hint_range(0.0,1.0,0.01) = 0.5;
uniform float normalmap_b_strength : hint_range(0.0,1.0,0.01) = 0.25;
uniform vec2 movement_direction = vec2(0.2,0.1);
uniform float movement_strength = 0.12;
uniform float uv_scale = 1.0;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

uniform float depth_distance : hint_range(0.0, 20.0, 0.1) = 4.0;
uniform float beers_law : hint_range(0.0,20.0,0.1) = 12.0;
uniform float water_transparency : hint_range(0.0, 1.0, 0.01) = 0.0;

uniform float refraction_strength : hint_range(0.0,0.8,0.001) = 0.5;

// Wave section
//uniform float noise_scale : hint_range(0.0, 50.0, 0.5) = 10.0;
//uniform float height_scale : hint_range(0.0, 1.0, 0.05) = 0.15;
//uniform sampler2D wave;
//uniform sampler2D DEPTH_TEXTURE: hint_depth_texture;
//uniform sampler2D SCREEN_TEXTURE: hint_screen_texture;

// waves and time
//uniform vec2 wave_direction = vec2(2.0,0.0);
//uniform vec2 wave_direction2 = vec2(0.0,1.0);
//uniform float time_scale : hint_range(0.0, 0.2, 0.005) = 0.025;

// varying variables
//varying float height;
//varying vec3 world_pos;


// edge
//uniform float edge_scale : hint_range(0.0, 1.0, 0.05) = 0.1;
//uniform float near = 0.5;
//uniform float far = 100.0;
//uniform vec3 edge_color : source_color;

//float edge(float depth) {
	//depth = 2.0 * depth - 1.0;
	//return near * far / (far + depth * (near - far));
//}

//void vertex() {
	//world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	//height = texture(wave, world_pos.xz / noise_scale + TIME * time_scale).r;
	//VERTEX.y += height * height_scale;
//}

float fresnel(float amount, vec3 normal, vec3 view){
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)),0.0,1.0)),amount);
}

void fragment(){
	
	//float z_depth = edge(texture(DEPTH_TEXTURE, SCREEN_UV).x);
	//float z_pos = edge(FRAGCOORD.z);
	//float z_dif = z_depth - z_pos;
	
	float basic_fresnel = fresnel(3.0,NORMAL,VIEW);
	
	vec2 uv = UV * uv_scale;
	vec2 uv_movement = movement_direction * TIME * movement_strength;
	
	vec3 normalmap = texture(normalmap_a, uv + uv_movement).rgb * normalmap_a_strength;
	normalmap += texture(normalmap_b, uv + uv_movement).rgb * normalmap_b_strength;
	
	vec3 ref_normalmap = normalmap * 2.0 - (normalmap_a_strength + normalmap_b_strength);
	vec3 ref_normal = mix(NORMAL, TANGENT * ref_normalmap + BINORMAL * ref_normalmap + NORMAL * ref_normalmap,1.0);
	vec2 ref_ofs = SCREEN_UV - ref_normal.xy * refraction_strength;
	
	//float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	//vec3 screen = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float depth_clean = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	float depth = textureLod(depth_texture, ref_ofs, 0.0).r;
	vec3 screen = textureLod(screen_texture, ref_ofs, 0.0).rgb;
	
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec3 ndc_clean = vec3(SCREEN_UV * 2.0 - 1.0, depth_clean);
	
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc,1.0);
	view.xyz /=view.w;
	float linear_depth = -view.z + VERTEX.z;
	
	vec4 world;
	
	if (linear_depth < 0.00001){
		world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc_clean,1.0);
	}
	else{
		world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	}
	
	//vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float depth_texture_y = world.y / world.w;
	float vertex_y = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	
	float depth_blend = clamp((vertex_y - depth_texture_y)/ depth_distance, 0.0, 1.0);
	depth_blend = exp(-depth_blend * beers_law);
	
	vec3 depth_color = mix(secondary_color, primary_color, depth_blend).rgb;
	
	vec3 refraction_texture;
	if(linear_depth < 0.0001){
		refraction_texture = textureLod(screen_texture, SCREEN_UV, ROUGHNESS * 2.0).rgb;
	} 
	else {
		refraction_texture = textureLod(screen_texture, ref_ofs, ROUGHNESS * 2.0).rgb;
	}
	
	
	vec3 final_color = mix(depth_color, refraction_texture, water_transparency * depth_blend);
	//vec3 depth_color_adj = mix(edge_color, color, step(edge_scale, z_dif));
	
	ALBEDO = final_color;
	//ALBEDO = clamp(final_color + edge_color);
	ROUGHNESS = roughness * (1.0 - basic_fresnel);
	NORMAL_MAP = normalmap;
	//ALPHA = 1. - z_depth; // z_dif works too
}


