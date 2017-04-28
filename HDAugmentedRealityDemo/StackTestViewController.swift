//
//  StackTestViewController.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 01/03/2017.
//  Copyright © 2017 Danijel Huis. All rights reserved.
//

import UIKit

class StackTestViewController: UIViewController
{
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var generationStepper: UIStepper!
    @IBOutlet weak var generationLabel: UILabel!

    
    private var annotationViews: [TestAnnotationView] = []
    private var originalAnnotationViews: [TestAnnotationView] = []
    private var step: Int = 0

    override func viewDidLoad()
    {
        super.viewDidLoad()

        self.loadUi()
        self.bindUi()
    }

    func loadUi()
    {
        self.edgesForExtendedLayout = []
        
        //===== Original annotationViews(ones from xib)
        for subview in self.scrollView.subviews
        {
            guard let annotationView = subview as? TestAnnotationView else { continue }
            guard !annotationView.isHidden else { continue }
            annotationView.titleLabel?.text = "y: \(annotationView.frame.origin.y)"
            annotationView.arFrame = annotationView.frame
            annotationViews.append(annotationView);
        }
        
        self.originalAnnotationViews = self.annotationViews
    }
    
    func bindUi()
    {
        self.generationLabel.text = "\(self.generationStepper.value)"
    }
    
    
    open func stackAnnotationViews(stepByStep: Bool)
    {
        let sortedAnnotationViews = self.annotationViews.sorted(by: { $0.frame.origin.y > $1.frame.origin.y })
        
        var i = 0
        for annotationView in sortedAnnotationViews
        {
            annotationView.titleLabel?.text = "\(i) y: \(annotationView.frame.origin.y)"
            i = i + 1
        }
        

        for annotationView1 in sortedAnnotationViews
        {
            var hasCollision = false
            
            var i = 0
            while i < sortedAnnotationViews.count
            {
                let annotationView2 = sortedAnnotationViews[i]
                if annotationView1 == annotationView2
                {
                    if hasCollision
                    {
                        hasCollision = false
                        i = 0
                        continue
                    }
                    break
                }
                
                let collision = annotationView1.frame.intersects(annotationView2.frame)
                
                if collision
                {
                    annotationView1.frame.origin.y = annotationView2.frame.origin.y - annotationView1.frame.size.height - 5
                    hasCollision = true
                }
                
                i = i + 1
            }
        }

    }
    
    func generate()
    {
        srand48(Int(self.generationStepper.value))
        
        let width: CGFloat = 1000
        let height: CGFloat = 1000
        
        let count: Int = 100
        
        self.scrollView.contentSize = CGSize(width: width, height: height)
        self.scrollView.contentOffset = CGPoint(x: width / 2 - self.scrollView.frame.size.width / 2, y: height - self.scrollView.frame.size.height)
        
        // Clear current annotation views
        self.annotationViews.forEach({ $0.removeFromSuperview() })
        self.annotationViews.removeAll()
    
        // Generate new annotation views
        for _ in stride(from: 0, to: count, by: 1)
        {
            let annotationView = TestAnnotationView()
            annotationView.frame.size.width = 120
            annotationView.frame.size.height = 40
            annotationView.frame.origin.x = CGFloat(drand48()) * (width - annotationView.frame.size.width)
            annotationView.frame.origin.y = height - annotationView.frame.size.height - CGFloat(drand48()) * 300
            annotationView.arFrame = annotationView.frame
            self.scrollView.addSubview(annotationView)
            self.annotationViews.append(annotationView)
            
            let r: Float = Float(drand48() * 200) / Float(255)
            let g: Float = Float(drand48() * 200) / Float(255)
            let b: Float = Float(drand48() * 200) / Float(255)
            let color = UIColor(colorLiteralRed: r, green: g, blue: b, alpha: 0.5)
            annotationView.backgroundColor = color
            
            annotationView.titleLabel?.textColor = UIColor.black
        }
    
    }
    
    
    @IBAction func nextButtonTapped(_ sender: Any)
    {
        self.generate()
        self.stackAnnotationViews(stepByStep: true)
    }
    
    
    @IBAction func resetButtonTapped(_ sender: Any)
    {
        //self.step = 0
        self.annotationViews.forEach({ $0.removeFromSuperview() })
        self.annotationViews = self.originalAnnotationViews
        for annotationView in self.annotationViews
        {
            self.scrollView.addSubview(annotationView)
            annotationView.frame = annotationView.arFrame
        }
    }
    
    
    @IBAction func stackButtonTapped(_ sender: Any)
    {
        self.stackAnnotationViews(stepByStep: false)
    }
    
    @IBAction func generateButtonTapped(_ sender: Any)
    {
        self.generate()
    }
    
    @IBAction func generationStepperValueChanged(_ sender: Any)
    {
        self.bindUi()
    }

}
