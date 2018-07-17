#import <UIKit/UIKit.h>

@interface OpenCV : NSObject

// funciton to get opencv version
+ (nonnull NSString * ) openCVVersionString;

// function to convert image to grayscale
+ (nonnull UIImage * ) makeGrayFromImage:(nonnull UIImage * ) image;

// function to match
+ (nonnull UIImage *)match :(UIImage *)srcImage templateImage:(nonnull UIImage *)templateImage;

// function do detect feature points
+ (nonnull UIImage *)detectKeypoints:(nonnull UIImage *)srcImage;

// function do detect hand
+ (nonnull UIImage *)handDetection:(nonnull UIImage *)srcImage;


@end
