//
//  Routable.swift
//  Router
//
//  Created by dev on 07.02.2018.
//

import UIKit

public protocol Routable {

    //associatedtype Segment

    func segmentGroups() -> [String]
    func push(segment:RouteSegment, animated:Bool, completion: @escaping () -> ())
    func pop(viewController:UIViewController, animated:Bool, completion: @escaping () -> ())
    func update(segment:RouteSegment, animated:Bool, completion: @escaping () -> ())
    func shouldReuse(segment:RouteSegment) -> Bool
}

public extension Routable {

    func segmentGroups() -> [String] {
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

//public class AnyRoutable<T>:Routable {
//    public typealias Segment = T
//
//    private let _push:(_ segment:Segment, _ animated:Bool, _ completion: @escaping () -> ()) -> ()
//    private let _pop:(_ viewController:UIViewController, _ animated:Bool, _ completion: @escaping () -> ()) -> ()
//    private let _update:(_ segment:Segment, _ animated:Bool, _ completion: @escaping () -> ()) -> ()
//    private let _shouldReuse:(_ segment:Segment) -> Bool
//
//    init<U:Routable>(_ routable:U) where U.Segment == T {
//        _push = routable.push
//        _pop = routable.pop
//        _update = routable.update
//        _shouldReuse = routable.shouldReuse
//    }
//
//    public func push(segment:Segment, animated:Bool, completion: @escaping () -> ()) {
//        self._push(segment, animated, completion)
//    }
//
//    public func pop(viewController:UIViewController, animated:Bool, completion: @escaping () -> ()) {
//        self._pop(viewController, animated, completion)
//    }
//
//    public func update(segment:Segment, animated:Bool, completion: @escaping () -> ()) {
//        self._update(segment, animated, completion)
//    }
//
//    public func shouldReuse(segment:Segment) -> Bool {
//        return self._shouldReuse(segment)
//    }
//}

