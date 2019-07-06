//
//  UIView+constraints.swift
//  HDAugmentedReality
//
//  Created by Danijel Huis on 30/05/2019.
//

import UIKit

extension UIView
{
    internal func pinToSuperview(leading: CGFloat?, trailing: CGFloat?, top: CGFloat?, bottom: CGFloat?, width: CGFloat?, height: CGFloat? )
    {
        let view = self
        guard let superview = view.superview else { return }
        
        if let leading = leading { view.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: leading).isActive = true }
        if let trailing = trailing { superview.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: trailing).isActive = true }
        if let top = top { view.topAnchor.constraint(equalTo: superview.topAnchor, constant: top).isActive = true }
        if let bottom = bottom { superview.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: bottom).isActive = true }
        if let width = width { view.widthAnchor.constraint(equalToConstant: width).isActive = true }
        if let height = height { view.heightAnchor.constraint(equalToConstant: height).isActive = true}
    }
    
    internal func pinToLayoutGuide(_ layoutGuide: UILayoutGuide, leading: CGFloat?, trailing: CGFloat?, top: CGFloat?, bottom: CGFloat?, width: CGFloat?, height: CGFloat? )
    {
        let view = self
        
        if let leading = leading { view.leadingAnchor.constraint(equalTo: layoutGuide.leadingAnchor, constant: leading).isActive = true }
        if let trailing = trailing { layoutGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: trailing).isActive = true }
        if let top = top { view.topAnchor.constraint(equalTo: layoutGuide.topAnchor, constant: top).isActive = true }
        if let bottom = bottom { layoutGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: bottom).isActive = true }
        if let width = width { view.widthAnchor.constraint(equalToConstant: width).isActive = true }
        if let height = height { view.heightAnchor.constraint(equalToConstant: height).isActive = true}
    }
}
