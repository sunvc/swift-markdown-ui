//
//  Environment+Menu.swift
//  swift-markdown-ui
//
//  Created by Neo on 2026/1/23.
//

import Foundation
import SwiftUI


public final class MarkdownConfig {
    public static let shared = MarkdownConfig()

    public var menus: [MenuItem] = []
    
    

    private init() {}

    public struct MenuItem {
        public var title: String
        public var image: UIImage?
        public var action: (String) -> Bool

        public init(title: String, image: UIImage? = nil, action: @escaping (String) -> Bool) {
            self.title = title
            self.action = action
            self.image = image
        }
    }
}
