//
//  ViewController.swift
//  PictureThis
//
//  Created by Caleb Bryant on 2/6/16.
//  Copyright © 2016 Caleb Bryant. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var capturedImage: UIImageView!
    
    var captureSession: AVCaptureSession?
    var stillImageOutput: AVCaptureStillImageOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var takingPhoto = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        captureSession = AVCaptureSession()
        captureSession!.sessionPreset = AVCaptureSessionPresetPhoto
        
        let backCamera = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        
        var error: NSError?
        var input: AVCaptureDeviceInput!
        do {
            input = try AVCaptureDeviceInput(device: backCamera)
        } catch let error1 as NSError {
            error = error1
            input = nil
        }
        
        if error == nil && captureSession!.canAddInput(input) {
            captureSession!.addInput(input)
            
            stillImageOutput = AVCaptureStillImageOutput()
            stillImageOutput!.outputSettings = [kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA)]
            if captureSession!.canAddOutput(stillImageOutput) {
                captureSession!.addOutput(stillImageOutput)
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer!.videoGravity = AVLayerVideoGravityResizeAspect
                previewLayer!.connection?.videoOrientation = AVCaptureVideoOrientation.Portrait
                previewView.layer.addSublayer(previewLayer!)
                captureSession!.startRunning()
            }
            if captureSession!.canSetSessionPreset(AVCaptureSessionPresetHigh) {
                captureSession?.sessionPreset = AVCaptureSessionPresetHigh;
            }
        }
        
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        previewLayer!.frame = capturedImage.bounds;
    }
    
    @IBAction func didPressTakePhoto(sender: UIButton) {
        
        if let videoConnection = stillImageOutput!.connectionWithMediaType(AVMediaTypeVideo) {
            videoConnection.videoOrientation = AVCaptureVideoOrientation.Portrait
            stillImageOutput?.captureStillImageAsynchronouslyFromConnection(videoConnection, completionHandler: {(sampleBuffer, error) in
                if (sampleBuffer != nil) {
                    let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)! as CVPixelBuffer
                    CVPixelBufferLockBaseAddress(imageBuffer,0)
                    let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
                    let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
                    let width = CVPixelBufferGetWidth(imageBuffer)
                    let height = CVPixelBufferGetHeight(imageBuffer)
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let context = CGBitmapContextCreate(baseAddress,width,height,8,bytesPerRow, colorSpace, CGBitmapInfo.ByteOrder32Little.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue)
                    
                    let imageRef = CGBitmapContextCreateImage(context)
                    CVPixelBufferUnlockBaseAddress(imageBuffer,0)
                    
                    let data = CGDataProviderCopyData(CGImageGetDataProvider(imageRef))
                    
                    let imageSize : Int = Int(width) * Int(height) * 4
                    let newPixelArray = UnsafeMutablePointer<UInt8>.alloc(imageSize)
                    
                    CFDataGetBytes(data, CFRangeMake(0,CFDataGetLength(data)), newPixelArray)
                    
                    //let pixels = data.bytes
                    
                    //var newPixels = UnsafeMutablePointer<UInt8>()
                    
                    for index in 0.stride(to: imageSize, by: 4) {
                        let r = newPixelArray[index] & 1
                        let g = newPixelArray[index + 1] & 1
                        let b = newPixelArray[index + 2] & 1
                        
                        if newPixelArray[index] == 255 && newPixelArray[index+1] == 255 && newPixelArray[index+2] == 255 {
                            newPixelArray[index] = 150
                            newPixelArray[index + 1] = 0
                            newPixelArray[index + 2] = 0
                            
                        }

                        let pixel = (r ^ b ^ g) * 255
                        newPixelArray[index] = pixel
                        newPixelArray[index + 1] = pixel
                        newPixelArray[index + 2] = pixel
                        newPixelArray[index + 3] = 255
                        
                    }
                    let bitmapInfo = CGImageGetBitmapInfo(imageRef)
                    let provider = CGDataProviderCreateWithData(nil, newPixelArray, imageSize, nil)
                    
                    let newImageRef = CGImageCreate(width, height, CGImageGetBitsPerComponent(imageRef), CGImageGetBitsPerPixel(imageRef), bytesPerRow, colorSpace, bitmapInfo, provider, nil, false, CGColorRenderingIntent.RenderingIntentDefault)
                    
                    let image = UIImage(CGImage: newImageRef!, scale: 1, orientation: .Right)
                    dispatch_async(dispatch_get_main_queue()) {
                        self.capturedImage.image = image
                    }
                    
                    //let provider = CGDataProviderCreateWithData(nil, newPixels, UInt(data.length), nil)

                    //CVPixelBufferUnlockBaseAddress(imageBuffer!, 0);
                    /*let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                    let dataProvider = CGDataProviderCreateWithCFData(imageData)
                    let cgImageRef = CGImageCreateWithJPEGDataProvider(dataProvider, nil, true, CGColorRenderingIntent.RenderingIntentDefault)
                    
                    let image = UIImage(CGImage: cgImageRef!, scale: 1.0, orientation: UIImageOrientation.Right)
                    self.capturedImage.image = image*/
                    self.previewLayer!.hidden = true

                }
            })
        }
    }
    
    @IBAction func didPressTakeAnother(sender: AnyObject) {
        captureSession!.startRunning()
    }
    
    
}
