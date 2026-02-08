#include "vulkan_object_shader.h"

#include "core/logger.h"
#include "core/hmemory.h"
#include "math/math_types.h"

#include "renderer/vulkan/vulkan_shader_utils.h"
#include "renderer/vulkan/vulkan_pipeline.h"
#include "renderer/vulkan/vulkan_buffer.h"

#define BUILTIN_SHADER_NAME_OBJECT "Builtin.ObjectShader"

b8 vulkan_object_shader_create(vulkan_context* context, vulkan_object_shader* out_shader) {
    // Shader module init per stage.
    char stage_type_strs[OBJECT_SHADER_STAGE_COUNT][5] = {"vert", "frag"};
    VkShaderStageFlagBits stage_types[OBJECT_SHADER_STAGE_COUNT] = {VK_SHADER_STAGE_VERTEX_BIT, VK_SHADER_STAGE_FRAGMENT_BIT};

    for (u32 i = 0; i < OBJECT_SHADER_STAGE_COUNT; ++i)
    {
        if (!create_shader_module(context, BUILTIN_SHADER_NAME_OBJECT, stage_type_strs[i], stage_types[i], i, out_shader->stages)) {
            HERROR("Unable to create %s shader module for %s.", stage_type_strs[i], BUILTIN_SHADER_NAME_OBJECT);
            return false;
        }
    }

    // Global Descriptors
    VkDescriptorSetLayoutBinding global_ubo_layout_binding;
    global_ubo_layout_binding.binding = 0;
    global_ubo_layout_binding.descriptorCount = 1;
    global_ubo_layout_binding.descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
    global_ubo_layout_binding.pImmutableSamplers = 0;
    global_ubo_layout_binding.stageFlags = VK_SHADER_STAGE_VERTEX_BIT;

    VkDescriptorSetLayoutCreateInfo global_layout_info = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
    global_layout_info.bindingCount = 1;
    global_layout_info.pBindings = &global_ubo_layout_binding;
    VK_CHECK(vkCreateDescriptorSetLayout(context->device.logical_device, &global_layout_info, context->allocator, &out_shader->global_descriptor_set_layout));

    // Global descriptor pool: Used for global items such as view/projection matrix.
    VkDescriptorPoolSize global_pool_size;
    global_pool_size.type = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
    global_pool_size.descriptorCount = context->swapchain.max_frames_in_flight;

    VkDescriptorPoolCreateInfo global_pool_create_info = {VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO};
    global_pool_create_info.poolSizeCount = 1;
    global_pool_create_info.pPoolSizes = &global_pool_size;
    global_pool_create_info.maxSets = context->swapchain.max_frames_in_flight;
    global_pool_create_info.flags = VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT;
    VK_CHECK(vkCreateDescriptorPool(context->device.logical_device, &global_pool_create_info, context->allocator, &out_shader->global_descriptor_pool));
    
    // Pipeline creation.
    VkViewport viewport;
    viewport.x = 0.0f;
    viewport.y = (f32)context->framebuffer_height;
    viewport.width = (f32)context->framebuffer_width;
    viewport.height = -(f32)context->framebuffer_height;
    viewport.minDepth = 0.0f;
    viewport.maxDepth = 1.0f;

    // Scissor
    VkRect2D scissor;
    scissor.offset.x = scissor.offset.y = 0;
    scissor.extent.width = context->framebuffer_width;
    scissor.extent.height = context->framebuffer_height;

    // Attributes
    u32 offset = 0;
    const i32 attribute_count = 1;
    VkVertexInputAttributeDescription attribute_descriptions[attribute_count];

    // Position
    VkFormat formats[attribute_count] = {
        VK_FORMAT_R32G32B32_SFLOAT
    };

    u64 sizes[attribute_count] = {
        sizeof(vec3)
    };

    for (u32 i = 0; i < attribute_count; ++i) {
        attribute_descriptions[i].binding = 0;  // binding index - should match binding description.
        attribute_descriptions[i].location = i; // attribute location.
        attribute_descriptions[i].format = formats[i];
        attribute_descriptions[i].offset = offset;
        offset += sizes[i]; 
    }

    // Descriptor set layouts.
    const i32 descriptor_set_layout_count = 1;
    VkDescriptorSetLayout descriptor_set_layouts[1] = {
        out_shader->global_descriptor_set_layout
    };

    // Stages 
    // NOTE: Should match the number of shader->stages.
    VkPipelineShaderStageCreateInfo stage_create_infos[OBJECT_SHADER_STAGE_COUNT];
    hzero_memory(stage_create_infos, sizeof(stage_create_infos));
    for (u32 i = 0; i < OBJECT_SHADER_STAGE_COUNT; ++i) {
        stage_create_infos[i].sType = out_shader->stages[i].shader_stage_create_info.sType;
        stage_create_infos[i] = out_shader->stages[i].shader_stage_create_info;
    }

    if (!vulkan_graphics_pipeline_create(
        context,
        &context->main_renderpass,
        attribute_count,
        attribute_descriptions,
        descriptor_set_layout_count,
        descriptor_set_layouts,
        OBJECT_SHADER_STAGE_COUNT,
        stage_create_infos,
        viewport,
        scissor,
        false,
        &out_shader->pipeline)) {

        HERROR("Failed to load graphics pipeline for object shader.");
        return false;
    }

    // Create uniform buffer.
    if (!vulkan_buffer_create(
        context,
        sizeof(global_uniform_object) * 3,
        VK_BUFFER_USAGE_TRANSFER_DST_BIT | VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
        VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT | VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        true,
        &out_shader->global_uniform_buffer)) {

        HERROR("Vulkan buffer creation failed for object shader.");
        return false;
    }

    // Allocate global descriptor sets.
    u32 max_frames = context->swapchain.max_frames_in_flight;
    VkDescriptorSetLayout* global_layouts = hallocate(sizeof(VkDescriptorSetLayout) * max_frames, MEMORY_TAG_RENDERER);
    for (u32 i = 0; i < max_frames; ++i) {
        global_layouts[i] = out_shader->global_descriptor_set_layout;
    }

    VkDescriptorSetAllocateInfo alloc_info = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
    alloc_info.descriptorPool = out_shader->global_descriptor_pool;
    alloc_info.descriptorSetCount = max_frames;
    alloc_info.pSetLayouts = global_layouts;
    VK_CHECK(vkAllocateDescriptorSets(context->device.logical_device, &alloc_info, out_shader->global_descriptor_sets));

    // Free the temporary layout array.
    hfree(global_layouts, sizeof(VkDescriptorSetLayout) * max_frames, MEMORY_TAG_RENDERER);

    return true;
}

void vulkan_object_shader_destroy(vulkan_context* context, struct vulkan_object_shader* shader) {
    VkDevice logical_device = context->device.logical_device;

    // Destroy uniform buffer.
    vulkan_buffer_destroy(context, &shader->global_uniform_buffer);

    // Destroy pipeline.
    vulkan_pipeline_destroy(context, &shader->pipeline);

    // Destroy global descriptor pool.
    vkDestroyDescriptorPool(logical_device, shader->global_descriptor_pool, context->allocator);

    // Destroy descriptor set layouts.
    vkDestroyDescriptorSetLayout(logical_device, shader->global_descriptor_set_layout, context->allocator);

    // Destroy shader modules.
    for (u32 i = 0; i < OBJECT_SHADER_STAGE_COUNT; ++i) {
        vkDestroyShaderModule(context->device.logical_device, shader->stages[i].handle, context->allocator);
        shader->stages[i].handle = 0;
    }
}

void vulkan_object_shader_use(vulkan_context* context, struct vulkan_object_shader* shader) {
    u32 image_index = context->image_index;
    vulkan_pipeline_bind(&context->graphics_command_buffers[image_index], VK_PIPELINE_BIND_POINT_GRAPHICS, &shader->pipeline);
}

void vulkan_object_shader_update_global_state(vulkan_context* context, struct vulkan_object_shader* shader) {
    u32 image_index = context->image_index;
    VkCommandBuffer command_buffer = context->graphics_command_buffers[image_index].handle;
    VkDescriptorSet global_descriptor = shader->global_descriptor_sets[image_index];

    // Configure the descriptors for the given index.
    u32 range = sizeof(global_uniform_object);
    u64 offset = sizeof(global_uniform_object) * image_index;

    // Copy the data to the buffer.
    vulkan_buffer_load_data(context, &shader->global_uniform_buffer, offset, range, 0, &shader->global_ubo);

    VkDescriptorBufferInfo buffer_info;
    buffer_info.buffer = shader->global_uniform_buffer.handle;
    buffer_info.offset = offset;
    buffer_info.range = range;

    // Update descriptor sets.
    VkWriteDescriptorSet descriptor_write = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};
    descriptor_write.dstSet = shader->global_descriptor_sets[image_index];
    descriptor_write.dstBinding = 0;
    descriptor_write.dstArrayElement = 0;
    descriptor_write.descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
    descriptor_write.descriptorCount = 1;
    descriptor_write.pBufferInfo = &buffer_info;

    vkUpdateDescriptorSets(context->device.logical_device, 1, &descriptor_write, 0, 0);

    // Bind the global descriptor set to be updated.
    vkCmdBindDescriptorSets(command_buffer, VK_PIPELINE_BIND_POINT_GRAPHICS, shader->pipeline.pipeline_layout, 0, 1, &global_descriptor, 0, 0);
}

void vulkan_object_shader_update_object(vulkan_context* context, struct vulkan_object_shader* shader, mat4 model) {
    u32 image_index = context->image_index;
    VkCommandBuffer command_buffer = context->graphics_command_buffers[image_index].handle;

    vkCmdPushConstants(command_buffer, shader->pipeline.pipeline_layout, VK_SHADER_STAGE_VERTEX_BIT, 0, sizeof(mat4), &model);
}