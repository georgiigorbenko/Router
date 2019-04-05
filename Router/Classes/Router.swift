//
//  Router.swift
//  Router
//
//  Created by dev on 07.02.2018.
//

import UIKit

public protocol RoutableAware: class where Self: UIViewController {
    var routable:Routable { get }
}

public extension RoutableAware {
    var routable:Routable {
        return EmptyRoutable()
    }
}

public class Router<Segment:RouteSegment, SegmentGroup:RouteSegmentGroup> {

    private let completionHandlerWaitingDelay:Double = 5

    private var rootViewController:RoutableAware

    public typealias RouteStackHandlerType = (UIViewController) -> [UIViewController]
    public typealias UserCompletion = (() -> ())

    var routeStackHandlers = [RouteStackHandlerType]()
    var routeStackTypes = [UIViewController.Type]()
    
    //serial queue make sure routes dispatched in the right order
    private let waitForRoutingCompletionQueue = DispatchQueue(label: "WaitForRoutingCompletionQueue", attributes: [])

    public init(rootViewController:RoutableAware) {
        self.rootViewController = rootViewController

        registerRouteStackHandler(type: UITabBarController.self) { vc in
            var stack:[UIViewController] = [vc]
            let vc = vc as! UITabBarController
            if vc.selectedViewController != nil {
                stack.append(vc.selectedViewController!)
            }
            return stack
        }
        registerRouteStackHandler(type: UINavigationController.self) { vc in
            return [vc] + (vc as! UINavigationController).viewControllers
        }
    }

    private func defaultViewControllerHandler(vc:UIViewController) -> UIViewController? {
        return vc.presentedViewController
    }

    public func registerRouteStackHandler(type:UIViewController.Type, handler: @escaping RouteStackHandlerType) {
        routeStackTypes.insert(type, at: 0)
        routeStackHandlers.insert(handler, at: 0)
    }

    private func findRouteStackHandler(for vc:UIViewController) -> RouteStackHandlerType? {
        guard let index = routeStackTypes.index(where:{ vc.isKind(of: $0) }) else { return nil }
        return routeStackHandlers[index]
    }

    private var fullStack:[RoutableAware] {
        let viewControllers = buildStack(vc: rootViewController)
        let stack = viewControllers.filter { $0 is RoutableAware } as! [RoutableAware]
        return stack
    }

    private func buildStack(vc:UIViewController) -> [UIViewController] {
        var stack = [UIViewController]()

        var currentVc = Optional.some(vc)
        repeat {
            if let handler = findRouteStackHandler(for: currentVc!) {
                stack += handler(currentVc!)
                currentVc = stack.last
            } else {
                currentVc = nil
            }
        } while currentVc != nil

        if stack.count == 0 {
            stack = [vc]
        }

        for item in stack {
            if let vc = defaultViewControllerHandler(vc: item) {
                stack.append(vc)
                break
            }
        }

        if stack.count == 0 || stack.last! === vc {
            return stack
        }

        let lastVc = stack.popLast()!
        stack += buildStack(vc: lastVc)

        return stack
    }

    public func route(_ newSegments:[Segment], animated:Bool = true, completion: UserCompletion? = nil) {
        let actions = routingActions(newSegments: newSegments)
        performRoutingActionsInQueue(actions: actions, animated: animated, completion: completion)
    }

    public func push(_ newSegments:[Segment], animated:Bool = true, completion: UserCompletion? = nil) {
        var actions = [RoutingActions]()
        let currentStack = fullStack
        for (i, segment) in newSegments.enumerated() {
            actions.append(.push(segmentIndex: currentStack.count + i, segment: segment))
        }

        performRoutingActionsInQueue(actions: actions, animated: animated, completion: completion)
    }

    public func popLast(numberOfControllers:Int = 1, animated: Bool = true, completion: UserCompletion? = nil) {
        let currentStack = fullStack
        guard numberOfControllers > 0 && currentStack.count > 0 else { return }

        let numberToPop = min(numberOfControllers, currentStack.count)

        let segmentIndex = currentStack.count - numberToPop
        let action:RoutingActions = .pop(segmentIndex: segmentIndex, viewController: currentStack[segmentIndex])
        performRoutingActionsInQueue(actions: [action], animated: animated, completion: completion)
    }

    public func pop(group: SegmentGroup, animated: Bool = true, completion: UserCompletion? = nil) {
        let currentStack = fullStack
        
        for (segmentIndex, vc) in currentStack.enumerated() {
            if vc.routable.memberOf(group: group) {
                let action:RoutingActions = .pop(segmentIndex: segmentIndex, viewController: currentStack[segmentIndex])
                performRoutingActionsInQueue(actions: [action], animated: animated, completion: completion)
                return
            }
        }
    }

    private func performRoutingActionsInQueue(actions:[RoutingActions], animated:Bool = true, completion: UserCompletion? = nil) {
        waitForRoutingCompletionQueue.async {
            self.performRoutingActions(actions: actions, animated: animated, completion: completion)
        }
    }

    private func performRoutingActions(actions:[RoutingActions], animated:Bool = true, completion: UserCompletion? = nil) {
        for action in actions {
            let semaphore = DispatchSemaphore(value: 0)

            let currentStack = self.fullStack

            DispatchQueue.main.async {
                switch action {
                case let .update(i, segment):
                    currentStack[i].routable.update(segment: segment, animated: animated) {
                        semaphore.signal()
                    }
                case let .push(i, segment):
                    currentStack[i - 1].routable.push(segment: segment, animated: animated) {
                        semaphore.signal()
                    }
                case let .pop(i, viewController):
                    currentStack[i - 1].routable.pop(viewController: viewController, animated: animated) {
                        semaphore.signal()
                    }
                }
            }

            let waitUntil = DispatchTime.now() + Double(Int64(self.completionHandlerWaitingDelay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            let result = semaphore.wait(timeout: waitUntil)

            if case .timedOut = result {
                print("******* Router is stuck waiting for a" +
                    " completion handler to be called. Ensure that you have called the" +
                    " completion handler in each Routable element. \(action) *******")
                break
            }
        }
        
        DispatchQueue.main.async {
            completion?()
        }
    }

    private func routingActions(newSegments:[Segment]) -> [RoutingActions] {
        var actions = [RoutingActions]()

        let currentStack = fullStack

        let maxIndex = min(newSegments.count, currentStack.count - 1)
        for (i, newSegment) in newSegments[0..<maxIndex].enumerated() {
            if currentStack[i + 1].routable.shouldReuse(segment: newSegment) {
                actions.append(.update(segmentIndex: i + 1, segment: newSegment))
            } else {
                break
            }
        }

        let keepSegmentsCount = actions.count + 1

        if currentStack.count > keepSegmentsCount {
            //remove first not matched segment, it must dismiss all presented controllers
            let popIndex = keepSegmentsCount
            actions.append(.pop(segmentIndex: popIndex, viewController: currentStack[popIndex]))
        }

        for i in (keepSegmentsCount - 1)..<newSegments.count {
            actions.append(.push(segmentIndex: i + 1, segment: newSegments[i]))
        }

        return actions
    }
}


private enum RoutingActions {
    case push(segmentIndex: Int, segment: RouteSegment)
    case pop(segmentIndex: Int, viewController: UIViewController)
    case update(segmentIndex: Int, segment: RouteSegment)
}

