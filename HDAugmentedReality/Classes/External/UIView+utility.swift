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
    
    /**
     Returns constraint with given attribute. Supported attributes:
     - .width
     - .height
     */
    internal func findConstraint(attribute: NSLayoutConstraint.Attribute) -> NSLayoutConstraint?
    {
        if attribute == .height || attribute == .width
        {
            for constraint in self.constraints
            {
                let typeString = String(describing: type(of: constraint))
                if typeString == "NSContentSizeLayoutConstraint" { continue }
                
                if constraint.firstItem === self, constraint.firstAttribute == attribute, constraint.secondAttribute == .notAnAttribute
                {
                    return constraint
                }
            }
        }
        else
        {
            print("findConstraint called with unsupported attribute. Only .width and .height attributes are supported.")
        }
        
        return nil
    }
    
}

internal extension UIView
{
    /**
     Loads view from nib. Type is inferred by return type.
     
     XIB: View must be instance of this class. Owner is not used. (e.g. like UITableViewCell)
     
     - Parameter nibName:           Name of nib file, if nil it will be assumed same as type name.
     - Parameter tag:               Tag of the view to load, if nil it is not used.
     - Parameter owner:             Owner of xib.
     */
    class func loadFromNib<T: UIView>(_ nibName: String?, tag: Int?, owner: Any?) -> T?
    {
        guard let nib = self.loadNibFromContainingBundle(nibName: nibName) else { return nil }
        let views = nib.instantiate(withOwner: owner, options: nil).compactMap { $0 as? UIView }
        let matchView = views.first(where: { ($0 is T) && (tag == nil || $0.tag == tag)  }) as? T
        
        return matchView
    }
    
    /**
     Loads view from nib and adds it to self as subview. Also sets owner to self.
     
     XIB: View must be UIView (or subclass). Owner must be instance of this class.
     
     - Parameter nibName:           Name of nib file, if nil it will be assumed same as type name.
     */
    @objc func addSubviewFromNib(nibName: String? = nil)
    {
        let baseView = self
        
        if baseView.subviews.count == 0
        {
            let view: UIView? = type(of: self).loadFromNib(nibName, tag: nil, owner: self)
            if let view = view
            {
                view.translatesAutoresizingMaskIntoConstraints = false
                baseView.addSubview(view)
                
                let leadingTrailing = NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[view]-0-|", options: .directionLeadingToTrailing, metrics: nil, views: ["view":view])
                let topBottom = NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[view]-0-|", options: .directionLeadingToTrailing, metrics: nil, views: ["view":view])
                baseView.addConstraints(leadingTrailing)
                baseView.addConstraints(topBottom)
            }
        }
        else
        {
            print("setupFromNib: Base view has subviews, aborting.")
        }
    }
    
    
    //==========================================================================================================================================================
    // MARK:                                                    Utility
    //==========================================================================================================================================================
    
    /**
     Assumed nibName as type name.
     */
    @objc class var typeName: String
    {
        let name = "\(self)".components(separatedBy: ".").last ?? ""
        return name
    }
    
    /**
     Searches for bundle that contains this class and loads nib from it.
     */
    @objc class func loadNibFromContainingBundle(nibName: String?) -> UINib?
    {
        let nibName = nibName ?? self.typeName
        let bundle = Bundle(for: self as AnyClass)
        guard let _ = bundle.path(forResource: nibName, ofType: "nib") else { return nil }
        
        let nib = UINib(nibName: nibName, bundle: bundle)
        return nib
    }
}
