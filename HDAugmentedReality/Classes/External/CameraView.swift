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
    open var mediaType: String = AVMediaTypeVideo
    /// Capture device position, set it before adding to superview.
    open var devicePosition: AVCaptureDevicePosition = AVCaptureDevicePosition.back
    /// Video gravitry for videoPreviewLayer, set it before adding to superview.
    open var videoGravity: String = AVLayerVideoGravityResizeAspectFill

    fileprivate var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    fileprivate var captureSession: AVCaptureSession?

    //==========================================================================================================================================================
    //MARK:                                                        UIView overrides
    //==========================================================================================================================================================
    open override func didMoveToSuperview()
    {
        super.didMoveToSuperview()
        
        if self.superview != nil
        {
            self.createSessionAndVideoPreviewLayer()
            self.setNeedsLayout()
        }
        else
        {
            self.destroySessionAndVideoPreviewLayer()
        }
    }
    
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
        //print("CameraView: Called startRunning before added to subview")
        self.captureSession?.startRunning()
    }
    
    /// Stops running capture session
    open func stopRunning()
    {
        self.captureSession?.stopRunning()
    }
    
    /// Creates capture session and video preview layer, destroySessionAndVideoPreviewLayer is called.
    fileprivate func createSessionAndVideoPreviewLayer()
    {
        self.destroySessionAndVideoPreviewLayer()
        
        //===== Capture session
        let captureSessionResult = CameraView.createCaptureSession(withMediaType: self.mediaType, position: self.devicePosition)
        guard captureSessionResult.error == nil, let session = captureSessionResult.session else
        {
            print("CameraView: Cannot create capture session, use createCaptureSession method to check if device is capable for augmented reality.")
            return
        }
        self.captureSession = session
        
        //===== View preview layer
        if let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        {
            videoPreviewLayer.videoGravity = self.videoGravity
            self.layer.insertSublayer(videoPreviewLayer, at: 0)
            self.videoPreviewLayer = videoPreviewLayer
        }
    }
    
    /// Stops running and destroys capture session, removes and destroys video preview layer.
    fileprivate func destroySessionAndVideoPreviewLayer()
    {
        self.stopRunning()
        self.videoPreviewLayer?.removeFromSuperlayer()
        self.videoPreviewLayer = nil
        self.captureSession = nil
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
    open class func createCaptureSession(withMediaType mediaType: String, position: AVCaptureDevicePosition) -> (session: AVCaptureSession?, error: NSError?)
    {
        var error: NSError?
        var captureSession: AVCaptureSession?
        var captureDevice: AVCaptureDevice?
        
        // Get all capture devices with given media type(video/photo)
        let captureDevices = AVCaptureDevice.devices(withMediaType: mediaType)
        
        // Get capture device for specified position
        if let captureDevices = captureDevices
        {
            for captureDeviceLoop in captureDevices
            {
                if (captureDeviceLoop as AnyObject).position == position, captureDeviceLoop is AVCaptureDevice
                {
                    captureDevice = captureDeviceLoop as? AVCaptureDevice
                    break
                }
            }
        }
        
        if let captureDevice = captureDevice
        {
            // Get video input device
            var captureDeviceInput: AVCaptureDeviceInput?
            do
            {
                captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
            }
            catch let deviceError as NSError
            {
                error = deviceError
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
                    error = NSError(domain: "CameraView", code: 10002, userInfo: ["description": "Error adding video input."])
                }
                
                captureSession = session
            }
            else
            {
                error = NSError(domain: "CameraView", code: 10001, userInfo: ["description": "Error creating capture device input."])
            }
        }
        else
        {
            error = NSError(domain: "CameraView", code: 10000, userInfo: ["description": "Back video device not found."])
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

