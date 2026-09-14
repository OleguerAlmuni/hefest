#pragma once

#include "defines.h"

typedef enum memory_tag {
    // For temporary use. Should be assigned one of the below or have a new tag created.
    MEMORY_TAG_UNKNOWN,
    MEMORY_TAG_ARRAY,
    MEMORY_TAG_LINEAR_ALLOCATOR,
    MEMORY_TAG_DARRAY,
    MEMORY_TAG_DICT,
    MEMORY_TAG_RING_QUEUE,
    MEMORY_TAG_BST,
    MEMORY_TAG_STRING,
    MEMORY_TAG_APPLICATION,
    MEMORY_TAG_JOB,
    MEMORY_TAG_TEXTURE,
    MEMORY_TAG_MATERIAL_INSTANCE,
    MEMORY_TAG_RENDERER,
    MEMORY_TAG_GAME,
    MEMORY_TAG_TRANSFORM,
    MEMORY_TAG_ENTITY,
    MEMORY_TAG_ENTITY_NODE,
    MEMORY_TAG_SCENE,

    MEMORY_TAG_MAX_TAGS
} memory_tag;

HAPI void memory_system_initialize(u64* memory_requirement, void* state);

HAPI void memory_system_shutdown(void* state);

HAPI void* hallocate(u64 size, memory_tag tag);

/**
 * Registers an allocation that was made before the counter existed.
 *
 * The counter's own state lives inside the systems allocator, so the block that
 * backs that allocator -- and the application state that holds it -- must be
 * reserved before memory_system_initialize can run. Those reservations go
 * through hallocate while state_ptr is still null and are therefore invisible
 * to the statistics. This function lets the caller declare them once the
 * counter is up, so that the report accounts for every byte the process asked
 * the operating system for rather than only for what was asked afterwards.
 *
 * It performs no allocation of its own.
 */
HAPI void hmemory_account_untracked(u64 size, memory_tag tag);

HAPI void hfree(void* block, u64 size, memory_tag tag);

HAPI void* hzero_memory(void* block, u64 size);

HAPI void* hcopy_memory(void* destination, const void* source, u64 size);

HAPI void* hset_memory(void* destination, i32 value, u64 size);

HAPI char* get_memory_usage_str();

HAPI u64 get_memory_alloc_count();