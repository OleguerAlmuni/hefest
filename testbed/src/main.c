#include <core/logger.h>
#include <core/asserts.h>

int main(void) {
    HFATAL("A test message: %f", 3.14f);
    HERROR("An error occurred: %d", 404);
    HWARN("This is a warning: %s", "be careful");
    HINFO("Some information: %d", 42);
    HDEBUG("Debugging info: %f", 2.718f);
    HTRACE("Trace message: %s", "tracing");

    HASSERT(1 == 0);

    return 0;
}
