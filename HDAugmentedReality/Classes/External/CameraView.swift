//
//  CameraView.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 18/12/2016.
//  Copyright © 2016 Danijel Huis. All rights reserved.
//

import UIKit
import AVFoundation

/**
 UIView with video preview layer. Call startRunning/stopRunning to start/stop capture session.
 Use createCaptureSession to check if cameraView can be initialized correctly.
 */
open class CameraView: UIView
{
    /// Media type, set it before adding to superview.
    open var mediaType: AVMediaType = AVMediaType.video
    /// Capture device position, set it before adding to superview.
    open var devicePosition: AVCaptureDevice.Position = AVCaptureDevice.Position.back
    /// Video gravitry for videoPreviewLayer, set it before adding to superview.
    open var videoGravity: AVLayerVideoGravity = AVLayerVideoGravity.resizeAspectFill
    open var isSessionCreated = false
    
    fileprivate var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    fileprivate var captureSession: AVCaptureSession?

    //==========================================================================================================================================================
    //MARK:                                                        UIView overrides
    //==========================================================================================================================================================
    open override func layoutSubviews()
    {
        super.layoutSubviews()
        self.layoutUi()
    }
    
    fileprivate func layoutUi()
    {
        self.videoPreviewLayer?.frame = self.bounds
    }
    
    //==========================================================================================================================================================
    //MARK:                                                        Main logic
    //==========================================================================================================================================================
    
    /// Starts running capture session
    open func startRunning()
    {
        #if targetEnvironment(simulator)
            self.backgroundColor = UIColor.darkGray
        #endif
        //print("CameraView: Called startRunning before added to subview")
        self.captureSession?.startRunning()
    }
    
    /// Stops running capture session
    open func stopRunning()
    {
        self.captureSession?.stopRunning()
    }
    
    /// Creates capture session and video preview layer, destroySessionAndVideoPreviewLayer is called.
    @discardableResult open func createSessionAndVideoPreviewLayer() -> (session: AVCaptureSession?, error: CameraViewError?)
    {
        self.destroySessionAndVideoPreviewLayer()
        
        //===== Capture session
        let captureSessionResult = CameraView.createCaptureSession(withMediaType: self.mediaType, position: self.devicePosition)
        guard captureSessionResult.error == nil, let session = captureSessionResult.session else
        {
            print("CameraView: Cannot create capture session, use createCaptureSession method to check if device is capable for augmented reality.")
            return captureSessionResult
        }
        self.captureSession = session
        
        //===== View preview layer
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        videoPreviewLayer.videoGravity = self.videoGravity
        self.layer.insertSublayer(videoPreviewLayer, at: 0)
        self.videoPreviewLayer = videoPreviewLayer
        self.isSessionCreated = true
        return captureSessionResult
    }
    
    /// Stops running and destroys capture session, removes and destroys video preview layer.
    open func destroySessionAndVideoPreviewLayer()
    {
        self.stopRunning()
        self.videoPreviewLayer?.removeFromSuperlayer()
        self.videoPreviewLayer = nil
        self.captureSession = nil
        self.isSessionCreated = false
    }
    
    open func setVideoOrientation(_ orientation: UIInterfaceOrientation)
    {
        if self.videoPreviewLayer?.connection?.isVideoOrientationSupported != nil
        {
            if let videoOrientation = AVCaptureVideoOrientation(rawValue: Int(orientation.rawValue))
            {
                self.videoPreviewLayer?.connection?.videoOrientation = videoOrientation
            }
        }
    }
    //==========================================================================================================================================================
    //MARK:                                                        Utilities
    //==========================================================================================================================================================
    

    
    /// Tries to find video device and add video input to it.
    open class func createCaptureSession(withMediaType mediaType: AVMediaType, position: AVCaptureDevice.Position) -> (session: AVCaptureSession?, error: CameraViewError?)
    {
        var error: CameraViewError?
        var captureSession: AVCaptureSession?        
        let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: mediaType, position: position)
        
        if let captureDevice = captureDevice
        {
            // Get video input device
            var captureDeviceInput: AVCaptureDeviceInput?
            do
            {
                captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
            }
            catch let deviceError
            {
                error = CameraViewError.deviceInput(underlyingError: deviceError)
                captureDeviceInput = nil
            }
            
            if let captureDeviceInput = captureDeviceInput, error == nil
            {
                let session = AVCaptureSession()
                
                if session.canAddInput(captureDeviceInput)
                {
                    session.addInput(captureDeviceInput)
                }
                else
                {
                    error = CameraViewError.addVideoInput
                }
                
                captureSession = session
            }
            else
            {
                error = CameraViewError.createCaptureDeviceInput
            }
        }
        else
        {
            error = CameraViewError.backVideoDeviceNotFount
        }
        
        return (session: captureSession, error: error)
    }
    
    open func inputDevice() -> AVCaptureDevice?
    {
        guard let inputs = self.captureSession?.inputs else { return nil }
        
        var inputDevice: AVCaptureDevice? = nil
        for input in inputs
        {
            if let input = input as? AVCaptureDeviceInput
            {
                inputDevice = input.device
                break
            }
        }
        
        return inputDevice
    }
}

public enum CameraViewError: Error
{
    case deviceInput(underlyingError: Error)
    case addVideoInput
    case createCaptureDeviceInput
    case backVideoDeviceNotFount

}
