//
//  protocols.swift
//  BluenetShared
//
//  Created by Alex de Mulder on 25/01/2017.
//  Copyright © 2017 Alex de Mulder. All rights reserved.
//

import Foundation

public protocol iBeaconPacketProtocol {
    var rssi : NSNumber { get }
    var idString: String { get }
}

public protocol LocalizationClassifier {
    func classify(_ inputVector: [iBeaconPacketProtocol], referenceId: String) -> String?
}
