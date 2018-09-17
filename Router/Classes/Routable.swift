//
//  Routable.swift
//  Router
//
//  Created by dev on 07.02.2018.
//

import UIKit

public protocol Routable {
    func segmentGroups() -> [RouteSegmentGroup]
    func push(segment:RouteSegment, animated:Bool, completion: @escaping () -> ())
    func pop(viewController:UIViewController, animated:Bool, completion: @escaping () -> ())
    func update(segment:RouteSegment, animated:Bool, completion: @escaping () -> ())
    func shouldReuse(segment:RouteSegment) -> Bool
}

public extension Routable {
    func segmentGroups() -> [RouteSegmentGroup] {
        return []
    }
    func push(segment:RouteSegment, animated:Bool, completion: @escaping () -> ()) {
        completion()
    }
    func pop(viewController:UIViewController, animated:Bool, completion: @escaping () -> ()) {
        completion()
    }
    func update(segment:RouteSegment, animated:Bool, completion: @escaping () -> ()) {
        completion()
    }
    func shouldReuse(segment:RouteSegment) -> Bool {
        return false
    }
}

public class EmptyRoutable: Routable {}
