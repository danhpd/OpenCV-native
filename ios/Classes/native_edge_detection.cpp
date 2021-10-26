#include "native_edge_detection.hpp"
#include "edge_detector.hpp"
#include "image_processor.hpp"
#include <stdlib.h>
#include <opencv2/opencv.hpp>
#include <stdio.h>
#include <math.h>
#include <stdint.h>

extern "C" __attribute__((visibility("default"))) __attribute__((used))
struct Coordinate *create_coordinate(double x, double y)
{
    struct Coordinate *coordinate = (struct Coordinate *)malloc(sizeof(struct Coordinate));
    coordinate->x = x;
    coordinate->y = y;
    return coordinate;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
struct DetectionResult *create_detection_result(Coordinate *topLeft, Coordinate *topRight, Coordinate *bottomLeft, Coordinate *bottomRight)
{
    struct DetectionResult *detectionResult = (struct DetectionResult *)malloc(sizeof(struct DetectionResult));
    detectionResult->topLeft = topLeft;
    detectionResult->topRight = topRight;
    detectionResult->bottomLeft = bottomLeft;
    detectionResult->bottomRight = bottomRight;
    return detectionResult;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
struct DetectionResult *detect_edges_by_image_path(char *str) {
    struct DetectionResult *coordinate = (struct DetectionResult *)malloc(sizeof(struct DetectionResult));
    cv::Mat mat = cv::imread(str);

    if (mat.size().width == 0 || mat.size().height == 0) {
        return create_detection_result(
            create_coordinate(0, 0),
            create_coordinate(1, 0),
            create_coordinate(0, 1),
            create_coordinate(1, 1)
        );
    }

    vector<cv::Point> points = EdgeDetector::detect_edges(mat);

    return create_detection_result(
        create_coordinate((double)points[0].x / mat.size().width, (double)points[0].y / mat.size().height),
        create_coordinate((double)points[1].x / mat.size().width, (double)points[1].y / mat.size().height),
        create_coordinate((double)points[2].x / mat.size().width, (double)points[2].y / mat.size().height),
        create_coordinate((double)points[3].x / mat.size().width, (double)points[3].y / mat.size().height)
    );
}

int clamp(int lower, int higher, int val){
    if(val < lower)
        return 0;
    else if(val > higher)
        return 255;
    else
        return val;
}

int getRotatedImageByteIndex(int x, int y, int rotatedImageWidth){
    return rotatedImageWidth*(y+1)-(x+1);
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
struct DetectionResult *detect_edges_by_camera_image(uint8_t *plane0, uint8_t *plane1, uint8_t *plane2,
                int bytesPerRow, int bytesPerPixel, int width, int height) {

    int hexFF = 255;
    int x, y, uvIndex, index;
    int yp, up, vp;
    int r, g, b;
    int rt, gt, bt;
    uint32_t *image = (uint32_t *) malloc(sizeof(uint32_t) * (width * height));
    for(x = 0; x < width; x++){
        for(y = 0; y < height; y++){
            uvIndex = bytesPerPixel * ((int) floor(x/2)) + bytesPerRow * ((int) floor(y/2));
            index = y*width+x;
            yp = plane0[index];
            up = plane1[uvIndex];
            vp = plane2[uvIndex];
            rt = round(yp + vp * 1436 / 1024 - 179);
            gt = round(yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91);
            bt = round(yp + up * 1814 / 1024 - 227);
            r = clamp(0, 255, rt);
            g = clamp(0, 255, gt);
            b = clamp(0, 255, bt);
            image[getRotatedImageByteIndex(y, x, height)] = (hexFF << 24) | (b << 16) | (g << 8) | r;
            //image[getRotatedImageByteIndex(y, x, height)] = (hexFF << 24) | (r << 16) | (g << 8) | b;
        }
    }

    cv::Mat mat = cv::Mat(width, height, CV_8UC4, image);

    if (mat.size().width == 0 || mat.size().height == 0) {
        return create_detection_result(
            create_coordinate(0, 0),
            create_coordinate(1, 0),
            create_coordinate(0, 1),
            create_coordinate(1, 1)
        );
    }

    vector<cv::Point> points = EdgeDetector::detect_edges(mat);

    free(image);

    return create_detection_result(
        create_coordinate((double)points[0].x / mat.size().width, (double)points[0].y / mat.size().height),
        create_coordinate((double)points[1].x / mat.size().width, (double)points[1].y / mat.size().height),
        create_coordinate((double)points[2].x / mat.size().width, (double)points[2].y / mat.size().height),
        create_coordinate((double)points[3].x / mat.size().width, (double)points[3].y / mat.size().height)
    );
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
bool crop_image(
    char *path,
    double topLeftX,
    double topLeftY,
    double topRightX,
    double topRightY,
    double bottomLeftX,
    double bottomLeftY,
    double bottomRightX,
    double bottomRightY) {
    cv::Mat mat = cv::imread(path);
    cv::Mat resizedMat = ImageProcessor::crop_image(
        mat,
        topLeftX * mat.size().width,
        topLeftY * mat.size().height,
        topRightX * mat.size().width,
        topRightY * mat.size().height,
        bottomLeftX * mat.size().width,
        bottomLeftY * mat.size().height,
        bottomRightX * mat.size().width,
        bottomRightY * mat.size().height
    );
    return cv::imwrite(path, resizedMat);
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
bool convert_to_bw(char* sour_path, char* dest_path) {
    cv::Mat mat = cv::imread(sour_path);
    cv::Mat resizedMat = ImageProcessor::convert_to_bw(mat);
    return cv::imwrite(dest_path, resizedMat);
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
bool compress_image(char* sour_path, char* dest_path, int maxWidth, int quality, int threshold) {
    cv::Mat mat = cv::imread(sour_path);
    //std::cout << "jniInit" <<mat.size().width ;

    if(threshold != 0){
        for(int x = 0; x < mat.size().height; x++){
            for(int y = 0; y < mat.size().width; y++){
                uchar *ptr = mat.ptr(x, y);
                int a = *ptr + *(ptr+1) + *(ptr+2);
                if(a/3 > threshold){
                    *ptr = 255;
                    *(ptr+1) = 255;
                    *(ptr+2) = 255;
                }
            }
        }
    }

    vector<int> p(2);
    p[0] = IMWRITE_JPEG_QUALITY;
    p[1] = quality;

    if(mat.size().width<maxWidth) return cv::imwrite(dest_path, mat, p);

    int height = mat.size().height*maxWidth/mat.size().width;
    Mat resized_down;
    resize(mat, resized_down, Size(maxWidth, height), INTER_LINEAR);
    return cv::imwrite(dest_path, resized_down, p);
}
