//
//  TestAnnotation.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 11/12/2019.
//  Copyright © 2019 Danijel Huis. All rights reserved.
//

import UIKit
import CoreLocation
import HDAugmentedReality

/// You don't have to subclass ARAnnotation, you can use ARAnnotation if it has all you need. I subclassed it
/// here so I can implement RadarAnnotation protocol and because I wanted to add "type" property.
class TestAnnotation: ARAnnotation, RadarAnnotation
{
    /// Dummy entity.
    var type: TestAnnotationType
    
    public init?(identifier: String?, title: String?, location: CLLocation, type: TestAnnotationType)
    {
        self.type = type
        super.init(identifier: identifier, title: title, location: location)
    }
    
    public var radarAnnotationTintColor: UIColor?
    {
        return self.type.tintColor
    }

}

/// This is just test data, in a normal project you would probably get annotation data in json format from some external service.
enum TestAnnotationType: CaseIterable
{
    case postOffice
    case library
    case casino
    case supermarket
    case hifi
    case paintShop
    case pharmacy
    case repairShop
    case home
    case mechanic
    case gameRoom
    case giftShop

    var icon: UIImage?
    {
        let imageName: String
        
        switch self
        {
        case .postOffice:
            imageName = "paperplane.fill"
        case .library:
            imageName = "book.fill"
        case .casino:
            imageName = "suit.club.fill"
        case .supermarket:
            imageName = "cart.fill"
        case .hifi:
            imageName = "hifispeaker.fill"
        case .paintShop:
            imageName = "paintbrush.fill"
        case .pharmacy:
            imageName = "bandage.fill"
        case .repairShop:
            imageName = "hammer.fill"
        case .home:
            imageName = "house.fill"
        case .mechanic:
            imageName = "car.fill"
        case .gameRoom:
            imageName = "gamecontroller.fill"
        case .giftShop:
            imageName = "gift.fill"
        }
        
        if #available(iOS 13.0, *) { return UIImage(systemName: imageName) }
        else { return UIImage(named: "small_pin")?.withRenderingMode(.alwaysTemplate) }
    }
    
    var title: String?
    {
        let title: String
        
        switch self
        {
        case .postOffice:
            title = "Post office"
        case .library:
            title = "Library"
        case .casino:
            title = "Casino"
        case .supermarket:
            title = "Supermarket"
        case .hifi:
            title = "Music"
        case .paintShop:
            title = "Paint shop"
        case .pharmacy:
            title = "Pharmacy"
        case .repairShop:
            title = "Repair shop"
        case .home:
            title = "My Home"
        case .mechanic:
            title = "Mechanic"
        case .gameRoom:
            title = "Game room"
        case .giftShop:
            title = "Gift shop"
        }
        
        return title
    }
    
    var tintColor: UIColor
    {
        let color: UIColor
        
        switch self
        {
        case .postOffice, .library, .pharmacy:
            color = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1)
        case .casino, .gameRoom, .home:
            color = UIColor(red: 0/255, green: 220/255, blue: 115/255, alpha: 1)
        default:
            color = UIColor(red: 255/255, green: 0/255, blue: 136/255, alpha: 1)
        }
        
        return color
    }
}
