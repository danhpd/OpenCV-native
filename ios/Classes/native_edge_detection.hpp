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
struct DetectionResult *detect_edges_by_image_path(char *str);

extern "C"
struct DetectionResult *detect_edges_by_camera_image(uint8_t *plane0, uint8_t *plane1, uint8_t *plane2,
                            int bytesPerRow, int bytesPerPixel, int width, int height);

extern "C"
bool crop_image(
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
extern "C"
bool convert_to_bw(
    char* sour_path,
    char* dest_path
);
extern "C"
bool compress_image(
    char* sour_path,
    char* dest_path,
    int maxWidth,
    int quality,
    int threshold
);
