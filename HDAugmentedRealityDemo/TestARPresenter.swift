//
//  TestARPresenter.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 13/04/2017.
//  Copyright © 2017 Danijel Huis. All rights reserved.
//

import UIKit

class TestARPresenter: ARPresenter
{
    override func yPositionForAnnotationView(_ annotationView: ARAnnotationView, arStatus: ARStatus) -> CGFloat
    {
        let y  = super.yPositionForAnnotationView(annotationView, arStatus: arStatus)
        return y - 150

    }
}
