//
//  RouteSegment.swift
//  Router
//
//  Created by dev on 07.02.2018.
//

public protocol RouteSegment {}

public protocol RouteSegmentGroup {
    func isEqual(_ other: RouteSegmentGroup) -> Bool
}
