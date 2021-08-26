//
//  AuthorizationRequest.swift
//  ProcessOut
//
//  Created by Jeremy Lejoux on 17/06/2019.
//

class AuthorizationRequest: Codable {
    var source: String = ""
    var incremental: Bool = false
    var threeDS2Enabled: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case source = "source"
        case incremental = "incremental"
        case threeDS2Enabled = "enable_three_d_s_2"
    }
    
    init(source: String, incremental: Bool) {
        self.source = source
        self.incremental = incremental
    }
}
