#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec2 in_texture_coordinates;
layout(location = 2) in vec3 in_normal;

layout(set = 0, binding = 0) uniform global_uniform_object {
    mat4 projection;
    mat4 view;
    vec4 ambient_color;
    vec4 light_direction;
    vec4 light_color;
    vec4 view_position;
} global_ubo;

layout(push_constant) uniform push_constants {
    // only guaranteed a total of 128 bytes.
    mat4 model; // 64 bytes
} u_push_constants;

layout(location = 0) out int out_mode;

// Data transfer object
layout(location = 1) out struct dto {
    vec2 texture_coordinates;
    vec3 normal;
    vec3 frag_position;
} out_dto;

void main() {
    out_dto.texture_coordinates = in_texture_coordinates;

    // NOTE: the model matrix currently carries only rotation and translation,
    // so its upper-left 3x3 is enough to bring the normal into world space.
    // Non-uniform scaling would require the inverse transpose instead.
    out_dto.normal = normalize(mat3(u_push_constants.model) * in_normal);
    out_dto.frag_position = vec3(u_push_constants.model * vec4(in_position, 1.0));

    gl_Position = global_ubo.projection * global_ubo.view * u_push_constants.model * vec4(in_position, 1.0);
}
