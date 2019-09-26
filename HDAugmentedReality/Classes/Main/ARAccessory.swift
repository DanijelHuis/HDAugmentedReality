//
//  ARAccessoryView.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 15/07/2019.
//  Copyright © 2019 Danijel Huis. All rights reserved.
//

import UIKit
import HDAugmentedReality

public protocol ARAccessory
{
    func reload(reloadType: ARViewController.ReloadType, status: ARStatus, presenter: ARPresenter)
}
