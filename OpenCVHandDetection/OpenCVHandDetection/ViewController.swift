import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

	@IBOutlet weak var imageView: UIImageView!
	
	var session: AVCaptureSession!
	var device: AVCaptureDevice!
	var output: AVCaptureVideoDataOutput!
	
	override func viewDidLoad() {
		super.viewDidLoad()

		// Prepare a video capturing session.
		self.session = AVCaptureSession()
        // 解像度の設定
		self.session.sessionPreset = AVCaptureSession.Preset.vga640x480 // not work in iOS simulator
        for device in AVCaptureDevice.devices() {
            if ((device as AnyObject).position == AVCaptureDevice.Position.back) {
                self.device = device
            }
        }

        if (self.device == nil) {
			print("no device")
			return
        }
		do {
            // 入力データの取得. 背面カメラを設定する
			let input = try AVCaptureDeviceInput(device: self.device)
			self.session.addInput(input)
		} catch {
			print("no device input")
			return
		}
        // 出力データの取得
		self.output = AVCaptureVideoDataOutput()
        // カラーチャンネルの設定
		self.output.videoSettings = [ kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA) ]
        // デリゲート、画像をキャプチャするキューを指定
		let queue: DispatchQueue = DispatchQueue(label: "videocapturequeue", attributes: [])
		self.output.setSampleBufferDelegate(self, queue: queue)
        // キューがブロックされているときに新しいフレームが来たら削除
		self.output.alwaysDiscardsLateVideoFrames = true
		if self.session.canAddOutput(self.output) {
			self.session.addOutput(self.output)
		} else {
			print("could not add a session output")
			return
		}
		do {
			try self.device.lockForConfiguration()
			self.device.activeVideoMinFrameDuration = CMTimeMake(1, 20) // 20 fps
			self.device.unlockForConfiguration()
		} catch {
			print("could not configure a device")
			return
		}

		self.session.startRunning()
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
	}

	override var shouldAutorotate : Bool {
		return false
	}

	func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		
		// Convert a captured image buffer to UIImage.
		guard let buffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
			print("could not get a pixel buffer")
			return
		}
		let capturedImage: UIImage
        let rotateImage: UIImage
		do {
			CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags.readOnly)
			defer {
				CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags.readOnly)
			}
			let address = CVPixelBufferGetBaseAddressOfPlane(buffer, 0)
			let bytes = CVPixelBufferGetBytesPerRow(buffer)
			let width = CVPixelBufferGetWidth(buffer)
			let height = CVPixelBufferGetHeight(buffer)
			let color = CGColorSpaceCreateDeviceRGB()
			let bits = 8
			let info = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
			guard let context = CGContext(data: address, width: width, height: height, bitsPerComponent: bits, bytesPerRow: bytes, space: color, bitmapInfo: info) else {
				print("could not create an CGContext")
				return
			}
			guard let image = context.makeImage() else {
				print("could not create an CGImage")
				return
			}
            capturedImage = UIImage(cgImage: image)
//            capturedImage = UIImage(cgImage: image, scale: 1.0, orientation: UIImageOrientation.right)
            
            rotateImage = self.rotateImage(image: capturedImage)
		}
		
		// グレースケール画像で表示
		//let resultImage = OpenCV.makeGrayFromImage(capturedImage)

        // 特徴点を抽出する画像をOpenCVを使って作成
        //let resultImage = OpenCV.detectKeypoints(rotateImage)
        
        // Hand Detection
        let resultImage = OpenCV.handDetection(rotateImage)
        
		// Show the result.
		DispatchQueue.main.async(execute: {
			self.imageView.image = resultImage
		})
	}
    
    
    func rotateImage(image: UIImage) -> UIImage {
        let imgSize = CGSize.init(width: image.size.width, height: image.size.height)
        // Contextを開く
        UIGraphicsBeginImageContextWithOptions(imgSize, false, 0.0)
        let context: CGContext = UIGraphicsGetCurrentContext()!
        // 回転の中心点を移動
        context.translateBy(x: image.size.width/2, y: image.size.height/2)
        // Y軸方向を補正
        context.scaleBy(x: 1.0, y: -1.0)
        
        // ラジアンに変換(90°回転させたい場合)
        let radian: CGFloat = -90 * CGFloat(Double.pi) / 180.0
        context.rotate(by: radian)
        // 回転画像の描画
        context.draw(image.cgImage!, in: CGRect.init(x: -image.size.width/2, y: -image.size.height/2, width: image.size.width, height: image.size.height))
        
        // Contextを閉じる
        let rotatedImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return rotatedImage
    }
}

