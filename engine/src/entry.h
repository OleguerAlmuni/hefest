#pragma once

#include "core/application.h"
#include "core/logger.h"
#include "core/hmemory.h"
#include "game_types.h"

// Externally-defined function to create a game.
extern b8 create_game(game* out_game);

/**
 * Main entry point for the application.
 */
int main(void) {

    initialize_memory();

    // Request the game instance from the application.
    game game_inst;
    if (!create_game(&game_inst)) {
        HFATAL("Could not create game.");
        return -1;
    }

    // Ensure the function pointers exist.
    if (!game_inst.initialize || !game_inst.update || !game_inst.render || !game_inst.on_resize) {
        HFATAL("Game function pointers not set.");
        return -2;
    }

    // Initialize the application.
    if (!application_create(&game_inst)) {
        HINFO("Application creation failed.");
        return 1;
    }

    // Begin the game loop.
    if (!application_run()) {
        HINFO("Application did not shutdown gracefully.");
        return 2;
    }

    shutdown_memory();
    
    return 0;
}