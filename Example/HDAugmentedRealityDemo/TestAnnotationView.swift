//
//  TestAnnotationView.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 30/04/15.
//  Copyright (c) 2015 Danijel Huis. All rights reserved.
//

import UIKit
import HDAugmentedReality
import CoreLocation

open class TestAnnotationView: ARAnnotationView, UIGestureRecognizerDelegate
{
    open var backgroundImageView: UIImageView?
    open var gradientImageView: UIImageView?
    open var iconImageView: UIImageView?
    open var titleLabel: UILabel?
    open var arFrame: CGRect = CGRect.zero  // Just for test stacking
    override open weak var annotation: ARAnnotation? { didSet { self.bindAnnotation() } }

    override open func initialize()
    {
        super.initialize()
        self.loadUi()
    }

    override open func didMoveToSuperview()
    {
        super.didMoveToSuperview()
        if self.superview != nil { self.startRotating() }
        else { self.stopRotating() }
    }
    
    /// We are creating all UI programatically because XIBs are heavyweight.
    func loadUi()
    {
        let image = UIImage(named: "annotationViewBackground")?.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 50, bottom: 0, right: 30), resizingMode: .stretch)
        let gradientImage = UIImage(named: "annotationViewGradient")?.withRenderingMode(.alwaysTemplate)
        
        // Gradient
        let gradientImageView = UIImageView()
        gradientImageView.contentMode = .scaleAspectFit
        gradientImageView.image = gradientImage
        self.addSubview(gradientImageView)
        self.gradientImageView = gradientImageView
        
        // Background
        let backgroundImageView = UIImageView()
        backgroundImageView.image = image
        self.addSubview(backgroundImageView)
        self.backgroundImageView = backgroundImageView
        
        // Icon
        let iconImageView = UIImageView()
        iconImageView.contentMode = .scaleAspectFit
        self.addSubview(iconImageView)
        self.iconImageView = iconImageView
        
        // Title label
        self.titleLabel?.removeFromSuperview()
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10)
        label.numberOfLines = 0
        label.backgroundColor = UIColor.clear
        label.textColor = UIColor.white
        self.addSubview(label)
        self.titleLabel = label
        
        // Gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(TestAnnotationView.tapGesture))
        self.addGestureRecognizer(tapGesture)
        
        // Other
        self.backgroundColor = UIColor.clear
        
        if self.annotation != nil { self.bindUi() }
    }
    
    func bindAnnotation()
    {
        guard let annotation = self.annotation as? TestAnnotation else { return }
        let type = annotation.type
        
        let icon = type.icon
        let tintColor = type.tintColor
        
        self.gradientImageView?.tintColor = tintColor
        self.iconImageView?.tintColor = tintColor
        self.iconImageView?.image = icon
    }
    
    func layoutUi()
    {
        let height = self.frame.size.height
        
        self.backgroundImageView?.frame = self.bounds

        self.iconImageView?.frame.size = CGSize(width: 20, height: 20)
        self.iconImageView?.center = CGPoint(x: height/2, y: height/2)
        
        self.gradientImageView?.frame.size = CGSize(width: 40, height: 40)
        self.gradientImageView?.center = CGPoint(x: height/2, y: height/2)
        self.gradientImageView?.layer.cornerRadius = (self.gradientImageView?.frame.size.width ?? 0) / 2
        self.gradientImageView?.layer.masksToBounds = true
        
        self.titleLabel?.frame = CGRect(x: 58, y: 0, width: self.frame.size.width - 20, height: self.frame.size.height);
    }
    
    // This method is called whenever distance/azimuth is set
    override open func bindUi()
    {
        let annotationTitle = (self.annotation as? TestAnnotation)?.type.title ?? self.annotation?.title ?? ""
        var distance: String = ""
        if let annotation = self.annotation { distance = annotation.distanceFromUser > 1000 ? String(format: "%.1fkm", annotation.distanceFromUser / 1000) : String(format:"%.0fm", annotation.distanceFromUser) }
        
        self.titleLabel?.text = "\(annotationTitle)\n\(distance)"
        
        /*
        if let annotation = self.annotation, let title = annotation.title
        {
            let distance = annotation.distanceFromUser > 1000 ? String(format: "%.1fkm", annotation.distanceFromUser / 1000) : String(format:"%.0fm", annotation.distanceFromUser)
            
            let text = String(format: "%@\nAZ: %.0f°\nDST: %@", title, annotation.azimuth, distance)
            self.titleLabel?.text = text
        }*/
    }
    
    open override func layoutSubviews()
    {
        super.layoutSubviews()
        self.layoutUi()
    }
    
    @objc open func tapGesture()
    {
        guard let annotation = self.annotation, let rootViewController = UIApplication.shared.delegate?.window??.rootViewController else { return }

        let alertController = UIAlertController(title: annotation.title, message: "Tapped", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(action)
        rootViewController.presentedViewController?.present(alertController, animated: true, completion: nil)
    }

    
    //==========================================================================================================================================================
    // MARK:                                                    Annotations
    //==========================================================================================================================================================
    private func startRotating()
    {
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.fromValue = 0
        rotateAnimation.toValue = CGFloat(Double.pi * 2)
        rotateAnimation.isRemovedOnCompletion = false
        rotateAnimation.duration = Double.random(in: 1..<3)
        rotateAnimation.repeatCount=Float.infinity
        self.gradientImageView?.layer.add(rotateAnimation, forKey: nil)
    }
    
    private func stopRotating()
    {
        self.gradientImageView?.layer.removeAllAnimations()
    }
}
