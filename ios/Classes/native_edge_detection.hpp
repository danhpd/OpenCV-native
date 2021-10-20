#include <stdint.h>

struct Coordinate
{
    double x;
    double y;
};

struct DetectionResult
{
    Coordinate* topLeft;
    Coordinate* topRight;
    Coordinate* bottomLeft;
    Coordinate* bottomRight;
};

extern "C"
struct ProcessingInput
{
    char* path;
    DetectionResult detectionResult;
};

extern "C"
struct DetectionResult *detect_edges(char *str);

extern "C"
struct DetectionResult *detect_edges2(uint8_t *plane0, uint8_t *plane1, uint8_t *plane2,
                            int bytesPerRow, int bytesPerPixel, int width, int height);

extern "C"
bool process_image(
    char* path,
    double topLeftX,
    double topLeftY,
    double topRightX,
    double topRightY,
    double bottomLeftX,
    double bottomLeftY,
    double bottomRightX,
    double bottomRightY
);