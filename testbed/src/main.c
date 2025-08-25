#include <core/logger.h>
#include <core/asserts.h>

// TODO: test
#include <platform/platform.h>

int main(void) {
    HFATAL("A test message: %f", 3.14f);
    HERROR("An error occurred: %d", 404);
    HWARN("This is a warning: %s", "be careful");
    HINFO("Some information: %d", 42);
    HDEBUG("Debugging info: %f", 2.718f);
    HTRACE("Trace message: %s", "tracing");

    platform_state state;
    if (platform_startup(&state, "Hefest Testbed", 100, 100, 1280, 720)) {
        while(TRUE) {
            platform_pump_messages(&state);
        }
    }

    platform_shutdown(&state);

    return 0;
}
