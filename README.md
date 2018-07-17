# iOS OpenCV Hand Detection

## OpenCV

Those projects uses OpenCV version 3.3.0.
However, OpenCV binary isn't include in thorse projects.
You can get OpenCV binary by following steps.

### OpenCV for iOS

1. Download `opencv-3.3.0-ios-framework.zip` from [https://github.com/opencv/opencv/releases/download/3.3.0/opencv-3.3.0-ios-framework.zip](https://github.com/opencv/opencv/releases/download/3.3.0/opencv-3.3.0-ios-framework.zip).
2. Unpack the file.
3. Copy `opencv2.framework` into `OpenCVSample_iOS` directory.

> If using above the binary, the linker may report many warnings such 'direct access in function '`___cxx_global_var_init' from file...`' on build. :-(

## Requirements

* macOS 10.12.6 (Recommended)
* iOS 11.0 (Recommended)
* Xcode 9.0
* Swift 4.0


## License

Please read [this file](LICENSE).
