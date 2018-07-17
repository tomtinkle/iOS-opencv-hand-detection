#ifndef OpenCVHelper_h
#define OpenCVHelper_h

#import <UIKit/UIKit.h>
#import <opencv2/opencv.hpp>

@interface OpenCVHelper : NSObject

+ (cv::Mat)cvMatFromUIImage:(UIImage *)image;
+ (UIImage *)UIImageFromCVMat:(cv::Mat)cvMat;
+ (IplImage *)createIplImageFromUIImage:(UIImage *)uiImage;
+ (UIImage *)UIImageFromIplImage:(IplImage *)inputImage;

@end

#endif /* OpenCVHelper_h */
