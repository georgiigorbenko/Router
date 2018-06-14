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

public class Router<Segment:RouteSegment> {

    private let completionHandlerWaitingDelay:Double = 5

    private var rootViewController:RoutableAware

    public typealias RouteStackHandlerType = (UIViewController) -> [UIViewController]

    var routeStackHandlers = [RouteStackHandlerType]()
    var routeStackTypes = [UIViewController.Type]()

    //serial queue make sure routes dispatched in the right order
    private let waitForRoutingCompletionQueue = DispatchQueue(label: "WaitForRoutingCompletionQueue", attributes: [])

    public init(rootViewController:RoutableAware) {
        self.rootViewController = rootViewController

        registerRouteStackHandler(type: UIViewController.self) { vc in
            var stack = [UIViewController]()

            let managedStackTypes = Array(self.routeStackTypes.dropLast())

            var currentVc = Optional.some(vc)
            repeat {
                stack.append(currentVc!)

                if (managedStackTypes.index { currentVc!.isKind(of: $0) }) != nil { break }

                currentVc = currentVc!.presentedViewController
            } while (currentVc != nil)

            return stack
        }
        registerRouteStackHandler(type: UITabBarController.self) { vc in
            var stack:[UIViewController] = [vc]
            let vc = vc as! UITabBarController
            if vc.selectedViewController != nil {
                stack.append(vc.selectedViewController!)
            }
            return stack
        }
        registerRouteStackHandler(type: UINavigationController.self) { vc in
            return (vc as! UINavigationController).viewControllers
        }
    }

    public func registerRouteStackHandler(type:UIViewController.Type, handler: @escaping RouteStackHandlerType) {
        routeStackTypes.insert(type, at: 0)
        routeStackHandlers.insert(handler, at: 0)
    }

    private func findRouteStackHandler(for vc:UIViewController) -> RouteStackHandlerType {
        let index = routeStackTypes.index { vc.isKind(of: $0) }!
        return routeStackHandlers[index]
    }

    private var fullStack:[RoutableAware] {
        let viewControllers = buildStack(vc: rootViewController as! UIViewController)
        return viewControllers.filter { $0 is RoutableAware } as! [RoutableAware]
    }

    private func buildStack(vc:UIViewController) -> [UIViewController] {
        var stack = findRouteStackHandler(for: vc)(vc)

        if stack.count == 0 || stack.last! === vc {
            return stack
        }

        let lastVc = stack.popLast()!
        stack += buildStack(vc: lastVc)

        return stack
    }

    public func route(_ newSegments:[Segment], animated:Bool = true) {
        let actions = routingActions(newSegments: newSegments)
        performRoutingActionsInQueue(actions: actions)
    }

    public func push(_ newSegments:[Segment], animated:Bool = true) {
        var actions = [RoutingActions]()
        let currentStack = fullStack
        for (i, segment) in newSegments.enumerated() {
            actions.append(.push(segmentIndex: currentStack.count + i, segment: segment))
        }

        performRoutingActionsInQueue(actions: actions)
    }

    public func popLast(numberOfControllers:Int = 1) {
        let currentStack = fullStack
        guard numberOfControllers > 0 && currentStack.count > 0 else { return }

        let numberToPop = min(numberOfControllers, currentStack.count)

        let segmentIndex = currentStack.count - numberToPop
        let action:RoutingActions = .pop(segmentIndex: segmentIndex, viewController: currentStack[segmentIndex] as! UIViewController)
        performRoutingActionsInQueue(actions: [action])
    }

    public func pop(group: String) {
        let currentStack = fullStack

        for (segmentIndex, vc) in currentStack.enumerated() {
            let segmentGroups = vc.routable.segmentGroups()
            if segmentGroups.index(of: group) != nil {
                let action:RoutingActions = .pop(segmentIndex: segmentIndex, viewController: currentStack[segmentIndex] as! UIViewController)
                performRoutingActionsInQueue(actions: [action])
                return
            }
        }
    }

    private func performRoutingActionsInQueue(actions:[RoutingActions], animated:Bool = true) {
        waitForRoutingCompletionQueue.async {
            self.performRoutingActions(actions: actions, animated: animated)
        }
    }

    private func performRoutingActions(actions:[RoutingActions], animated:Bool = true) {
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
                    " completion handler in each Routable element. *******")
                break
            }
        }
    }

    private func routingActions(newSegments:[Segment]) -> [RoutingActions] {
        var actions = [RoutingActions]()

        let currentStack = fullStack

        let maxIndex = min(newSegments.count, currentStack.count) - 1
        for (i, newSegment) in newSegments[0..<maxIndex].enumerated() {
            if currentStack[i + 1].routable.shouldReuse(segment: newSegment) {
                //print("----UPDATE")
                actions.append(.update(segmentIndex: i + 1, segment: newSegment))
            } else {
                break
            }
        }

        let keepSegmentsCount = actions.count + 1

        if currentStack.count > keepSegmentsCount {
            //remove first not matched segment, it must dismiss all presented controllers
            let popIndex = keepSegmentsCount
            actions.append(.pop(segmentIndex: popIndex, viewController: currentStack[popIndex] as! UIViewController))
            //print("----POP")
        }

        for i in (keepSegmentsCount - 1)..<newSegments.count {
            actions.append(.push(segmentIndex: i + 1, segment: newSegments[i]))
            //print("----PUSH")
        }

        return actions
    }
}


private enum RoutingActions {
    case push(segmentIndex: Int, segment: RouteSegment)
    case pop(segmentIndex: Int, viewController: UIViewController)
    case update(segmentIndex: Int, segment: RouteSegment)
}

