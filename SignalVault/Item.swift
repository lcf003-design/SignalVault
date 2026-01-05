//
//  Item.swift
//  SignalVault
//
//  Created by Larry Fields III on 1/5/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
