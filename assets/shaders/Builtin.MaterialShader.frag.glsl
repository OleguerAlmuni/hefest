#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) out vec4 out_color;

layout(set = 0, binding = 0) uniform global_uniform_object {
    mat4 projection;
    mat4 view;
    vec4 ambient_color;
    vec4 light_direction;
    vec4 light_color;
    vec4 view_position;
} global_ubo;

layout(set = 1, binding = 0) uniform local_uniform_object {
    vec4 diffuse_color;
} object_ubo;

// Samplers
layout(set = 1, binding = 1) uniform sampler2D diffuse_sampler;

// Data transfer object
layout(location = 1) in struct dto {
    vec2 texture_coordinates;
    vec3 normal;
    vec3 frag_position;
} in_dto;

// TODO: this belongs to the material, once it carries surface properties.
const float SHININESS = 32.0;

void main() {
    vec3 normal = normalize(in_dto.normal);

    // light_direction is the direction the light travels, so the vector that
    // points towards the light is its negation.
    vec3 to_light = normalize(-global_ubo.light_direction.xyz);
    vec3 to_view = normalize(global_ubo.view_position.xyz - in_dto.frag_position);

    vec4 base_color = object_ubo.diffuse_color * texture(diffuse_sampler, in_dto.texture_coordinates);

    // Ambient term, so faces turned away from the light are not pure black.
    vec4 ambient = global_ubo.ambient_color * base_color;

    // Diffuse term (Lambert).
    float diffuse_factor = max(dot(normal, to_light), 0.0);
    vec4 diffuse = global_ubo.light_color * diffuse_factor * base_color;

    // Specular term (Blinn-Phong). Suppressed on faces that receive no diffuse
    // light, which would otherwise show a highlight on their dark side.
    vec3 halfway = normalize(to_light + to_view);
    float specular_factor = pow(max(dot(normal, halfway), 0.0), SHININESS);
    specular_factor *= step(0.0001, diffuse_factor);
    vec4 specular = global_ubo.light_color * specular_factor;

    out_color = ambient + diffuse + specular;
    out_color.a = base_color.a;
}
