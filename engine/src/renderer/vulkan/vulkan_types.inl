#pragma once

#include "defines.h"
#include "core/asserts.h"
#include "renderer/renderer_types.inl"
#include "resources/resource_types.h"

#include <vulkan/vulkan.h>

// Checks the given expression's return value against VK_SUCCESS.
#define VK_CHECK(expr)               \
    {                                \
        HASSERT(expr == VK_SUCCESS); \
    }

typedef struct vulkan_buffer {
    u64 total_size;
    VkBuffer handle;
    VkBufferUsageFlagBits usage;
    b8 is_locked;
    VkDeviceMemory memory;
    i32 memory_index;
    u32 memory_property_flags;
} vulkan_buffer;

typedef struct vulkan_swapchain_support_info {
    VkSurfaceCapabilitiesKHR capabilities;
    u32 format_count;
    VkSurfaceFormatKHR* formats;
    u32 present_mode_count;
    VkPresentModeKHR* present_modes;
} vulkan_swapchain_support_info;

typedef struct vulkan_device {
    VkPhysicalDevice physical_device;
    VkDevice logical_device;
    vulkan_swapchain_support_info swapchain_support;
    
    i32 graphics_queue_index;
    i32 present_queue_index;
    i32 transfer_queue_index;

    VkQueue graphics_queue;
    VkQueue present_queue;
    VkQueue transfer_queue;

    VkCommandPool graphics_command_pool;

    VkPhysicalDeviceProperties properties;
    VkPhysicalDeviceFeatures features;
    VkPhysicalDeviceMemoryProperties memory;

    VkFormat depth_format;
} vulkan_device;

typedef struct vulkan_image {
    VkImage handle;
    VkDeviceMemory memory;
    VkImageView view;
    u32 width;
    u32 height;
} vulkan_image;

typedef enum vulkan_render_pass_state {
    READY,
    RECORDING,
    IN_RENDER_PASS,
    RECORDING_ENDED,
    SUBMITTED,
    NOT_ALLOCATED
} vulkan_render_pass_state;

typedef struct vulkan_renderpass {
    VkRenderPass handle;
    vec4 render_area;
    vec4 clear_color;

    f32 depth;
    u32 stencil;

    u8 clear_flags;
    b8 has_prev_pass;
    b8 has_next_pass;

    vulkan_render_pass_state state;
} vulkan_renderpass;

// Upper bound on the number of images a swapchain may report. The driver decides
// the actual count (vkGetSwapchainImagesKHR), which can exceed the requested
// minimum and varies by device/driver, so per-image resources are sized at runtime
// from swapchain.image_count and only fixed-size arrays are bounded by this.
#define VULKAN_MAX_SWAPCHAIN_IMAGE_COUNT 8

typedef struct vulkan_swapchain {
    VkSurfaceFormatKHR image_format;
    u8 max_frames_in_flight;
    VkSwapchainKHR handle;
    u32 image_count;
    VkImage* images;
    VkImageView* views;

    vulkan_image depth_attachment;

    // Framebuffers used for on-screen rendering, one per swapchain image.
    VkFramebuffer framebuffers[VULKAN_MAX_SWAPCHAIN_IMAGE_COUNT];
} vulkan_swapchain;

typedef enum vulkan_command_buffer_state {
    COMMAND_BUFFER_STATE_READY,
    COMMAND_BUFFER_STATE_RECORDING,
    COMMAND_BUFFER_STATE_IN_RENDER_PASS,
    COMMAND_BUFFER_STATE_RECORDING_ENDED,
    COMMAND_BUFFER_STATE_SUBMITTED,
    COMMAND_BUFFER_STATE_NOT_ALLOCATED
} vulkan_command_buffer_state;

typedef struct vulkan_command_buffer {
    VkCommandBuffer handle;

    // Command buffer state.
    vulkan_command_buffer_state state;
} vulkan_command_buffer;

typedef struct vulkan_shader_stage {
    VkShaderModuleCreateInfo create_info;
    VkShaderModule handle;
    VkPipelineShaderStageCreateInfo shader_stage_create_info;
} vulkan_shader_stage;

typedef struct vulkan_pipeline {
    VkPipeline handle;
    VkPipelineLayout pipeline_layout;
} vulkan_pipeline;

#define MATERIAL_SHADER_STAGE_COUNT 2

typedef struct vulkan_descriptor_state {
    // One per swapchain image (indexed by image index).
    u32 generations[VULKAN_MAX_SWAPCHAIN_IMAGE_COUNT];
    u32 ids[VULKAN_MAX_SWAPCHAIN_IMAGE_COUNT];
} vulkan_descriptor_state;

#define VULKAN_MATERIAL_SHADER_DESCRIPTOR_COUNT 2
#define VULKAN_MATERIAL_SHADER_SAMPLER_COUNT 1

typedef struct vulkan_material_shader_instance_state {
    // One per swapchain image (indexed by image index).
    VkDescriptorSet descriptor_sets[VULKAN_MAX_SWAPCHAIN_IMAGE_COUNT];

    // Per descriptor
    vulkan_descriptor_state descriptor_states[VULKAN_MATERIAL_SHADER_DESCRIPTOR_COUNT];
} vulkan_material_shader_instance_state;

// Max number of material instances
// TODO: make configurable
#define VULKAN_MAX_MATERIAL_COUNT 1024

// Max number of simultaneously uploaded geometries
// TODO: make configurable
#define VULKAN_MAX_GEOMETRY_COUNT 4096

/**
 * @brief Internal buffer data for geometry.
 */
typedef struct vulkan_geometry_data {
    u32 id;
    u32 generation;
    u32 vertex_count;
    u32 vertex_element_size;
    u32 vertex_buffer_offset;
    u32 index_count;
    u32 index_element_size;
    u32 index_buffer_offset;
} vulkan_geometry_data;

typedef struct vulkan_material_shader_global_ubo {
    mat4 projection;    // 64 bytes
    mat4 view;          // 64 bytes
    mat4 m_reserved0;   // 64 bytes, reserved for future use
    mat4 m_reserved1;   // 64 bytes, reserved for future use
} vulkan_material_shader_global_ubo;

typedef struct vulkan_material_shader_instance_ubo {
    vec4 diffuse_color; // 16 bytes
    vec4 v_reserved0;   // 16 bytes, reserved for future use
    vec4 v_reserved1;   // 16 bytes, reserved for future use
    vec4 v_reserved2;   // 16 bytes, reserved for future use
} vulkan_material_shader_instance_ubo;

typedef struct vulkan_material_shader {
    // vertex, fragment
    vulkan_shader_stage stages[MATERIAL_SHADER_STAGE_COUNT];

    VkDescriptorPool global_descriptor_pool;
    VkDescriptorSetLayout global_descriptor_set_layout;

    // One descriptor set per swapchain image. Sized to the maximum supported image
    // count; only swapchain.image_count entries are actually allocated and used.
    VkDescriptorSet global_descriptor_sets[VULKAN_MAX_SWAPCHAIN_IMAGE_COUNT];

    // Global uniform object.
    vulkan_material_shader_global_ubo global_ubo;

    // Global uniform buffer.
    vulkan_buffer global_uniform_buffer;

    VkDescriptorPool object_descriptor_pool;
    VkDescriptorSetLayout object_descriptor_set_layout;
    // Object uniform buffers;
    vulkan_buffer object_uniform_buffer;
    // TODO: Manage a free list of some kind here instead.
    u32 object_uniform_buffer_index;

    texture_use sampler_uses[VULKAN_MATERIAL_SHADER_SAMPLER_COUNT];

    // TODO: Make dynamic.
    vulkan_material_shader_instance_state instance_states[VULKAN_MAX_MATERIAL_COUNT];
    vulkan_pipeline pipeline;
} vulkan_material_shader;

#define UI_SHADER_STAGE_COUNT 2
#define VULKAN_UI_SHADER_DESCRIPTOR_COUNT 2
#define VULKAN_UI_SHADER_SAMPLER_COUNT 1

// Max number of UI control instances
// TODO: make configurable
#define VULKAN_MAX_UI_COUNT 1024

typedef struct vulkan_ui_shader_instance_state {
    // One per swapchain image (indexed by image index).
    VkDescriptorSet descriptor_sets[VULKAN_MAX_SWAPCHAIN_IMAGE_COUNT];

    // Per descriptor
    vulkan_descriptor_state descriptor_states[VULKAN_UI_SHADER_DESCRIPTOR_COUNT];
} vulkan_ui_shader_instance_state;

typedef struct vulkan_ui_shader_global_ubo {
    mat4 projection;    // 64 bytes
    mat4 view;          // 64 bytes
    mat4 m_reserved0;   // 64 bytes, reserved for future use
    mat4 m_reserved1;   // 64 bytes, reserved for future use
} vulkan_ui_shader_global_ubo;

typedef struct vulkan_ui_shader_instance_ubo {
    vec4 diffuse_color; // 16 bytes
    vec4 v_reserved0;   // 16 bytes, reserved for future use
    vec4 v_reserved1;   // 16 bytes, reserved for future use
    vec4 v_reserved2;   // 16 bytes, reserved for future use
} vulkan_ui_shader_instance_ubo;

typedef struct vulkan_ui_shader {
    // vertex, fragment
    vulkan_shader_stage stages[UI_SHADER_STAGE_COUNT];

    VkDescriptorPool global_descriptor_pool;
    VkDescriptorSetLayout global_descriptor_set_layout;

    // One descriptor set per swapchain image. Sized to the maximum supported image
    // count; only swapchain.image_count entries are actually allocated and used.
    VkDescriptorSet global_descriptor_sets[VULKAN_MAX_SWAPCHAIN_IMAGE_COUNT];

    // Global uniform object.
    vulkan_ui_shader_global_ubo global_ubo;

    // Global uniform buffer.
    vulkan_buffer global_uniform_buffer;

    VkDescriptorPool object_descriptor_pool;
    VkDescriptorSetLayout object_descriptor_set_layout;
    // Object uniform buffers.
    vulkan_buffer object_uniform_buffer;
    // TODO: Manage a free list of some kind here instead.
    u32 object_uniform_buffer_index;

    texture_use sampler_uses[VULKAN_UI_SHADER_SAMPLER_COUNT];

    // TODO: Make dynamic.
    vulkan_ui_shader_instance_state instance_states[VULKAN_MAX_UI_COUNT];

    vulkan_pipeline pipeline;
} vulkan_ui_shader;

typedef struct vulkan_context {
    f32 frame_delta_time;

    // The framebuffer's current width.
    u32 framebuffer_width;

    // The framebuffer's current height.
    u32 framebuffer_height;

    // Current generation of framebuffer size. If it does not match framebuffer_size_last_generation,
    // a new one should be generated.
    u64 framebuffer_size_generation;

    // The generation of the framebuffer when it was last created. Set to framebuffer_size_generation
    // when updated.
    u64 framebuffer_size_last_generation;

    VkInstance instance;
    VkAllocationCallbacks* allocator;
    VkSurfaceKHR surface;

#if defined(_DEBUG)
    VkDebugUtilsMessengerEXT debug_messenger;
#endif

    vulkan_device device;

    vulkan_swapchain swapchain;
    vulkan_renderpass main_renderpass;
    vulkan_renderpass ui_renderpass;

    vulkan_buffer object_vertex_buffer;
    vulkan_buffer object_index_buffer;

    // darray
    vulkan_command_buffer* graphics_command_buffers;

    // darray
    VkSemaphore* image_available_semaphores;

    // darray
    VkSemaphore* queue_complete_semaphores;

    u32 in_flight_fence_count;
    VkFence in_flight_fences[VULKAN_MAX_SWAPCHAIN_IMAGE_COUNT];

    // Holds pointers to fences which exist and are owned elsewhere, one per swapchain image.
    VkFence* images_in_flight[VULKAN_MAX_SWAPCHAIN_IMAGE_COUNT];

    u32 image_index;
    u32 current_frame;

    b8 recreating_swapchain;

    vulkan_material_shader material_shader;
    vulkan_ui_shader ui_shader;

    u64 geometry_vertex_offset;
    u64 geometry_index_offset;

    // TODO: make dynamic
    vulkan_geometry_data geometries[VULKAN_MAX_GEOMETRY_COUNT];

    // Framebuffers used for world rendering, one per swapchain image.
    VkFramebuffer world_framebuffers[VULKAN_MAX_SWAPCHAIN_IMAGE_COUNT];

    i32 (*find_memory_index)(u32 type_filter, u32 property_flags);

} vulkan_context;

typedef struct vulkan_texture_data {
    vulkan_image image;
    VkSampler sampler;
} vulkan_texture_data;
