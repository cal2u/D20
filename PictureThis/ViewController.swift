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
    @IBOutlet weak var captureButton: UIButton!
    
    var captureSession: AVCaptureSession?
    var stillImageOutput: AVCaptureStillImageOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var takingPhoto = true
    var numPhotos = 0
    var pixelArray:UnsafeMutablePointer<UInt8>?
    
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
        previewLayer!.position = capturedImage.layer.position
    }
    
    @IBAction func didPressTakePhoto(sender: UIButton) {
        if (self.numPhotos == 3) {
            self.previewLayer!.hidden = false
            self.captureButton.setTitle("Capture Photo!",forState: UIControlState.Normal)
            self.numPhotos = 0
            return
            
        }
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
                    if (self.numPhotos % 4 == 0) {
                        print("Creating new Image");
                        self.pixelArray?.destroy();
                        self.pixelArray = UnsafeMutablePointer<UInt8>.alloc(imageSize);
                        for index in 0.stride(to: imageSize, by: 4) {
                            self.pixelArray![index] = 0
                            self.pixelArray![index+1] = 0
                            self.pixelArray![index+2] = 0
                            self.pixelArray![index+3] = 255
                        }

                    }

                    for index in 0.stride(to: imageSize, by: 4) {
                        let r = newPixelArray[index] & 1
                        let g = newPixelArray[index + 1] & 1
                        let b = newPixelArray[index + 2] & 1
                        

                        let pixel = (r ^ b ^ g) * 255
                        self.pixelArray![index] = self.pixelArray![index] ^ pixel
                        self.pixelArray![index+1] = self.pixelArray![index+1] ^ pixel
                        self.pixelArray![index+2] = self.pixelArray![index+2] ^ pixel
                        self.pixelArray![index+3] = 255
                        
                        
                    }
                    print("Destroying camera pci")
                    newPixelArray.destroy()
                    let bitmapInfo = CGImageGetBitmapInfo(imageRef)
                    let provider = CGDataProviderCreateWithData(nil, self.pixelArray!, imageSize, nil)
                    
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
                    
                    if (self.numPhotos) % 4 == 2 {
                        self.previewLayer!.hidden = true
                        self.captureButton.setTitle("Clear",forState: UIControlState.Normal)
                    }
                    self.numPhotos = (self.numPhotos+1)%4;


                }
            })
        }
    }
    
    @IBAction func didPressTakeAnother(sender: AnyObject) {
        captureSession!.startRunning()
    }
    
    
}
