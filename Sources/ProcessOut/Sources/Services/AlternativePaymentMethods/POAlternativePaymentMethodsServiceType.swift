//
//  POAlternativePaymentMethodsServiceType.swift
//  ProcessOut
//
//  Created by Simeon Kostadinov on 27/10/2022.
//

import Foundation

public protocol POAlternativePaymentMethodsServiceType {

    /// Creates the redirection URL for APM Payments and APM token creation.
    ///
    /// - Parameter request: request containing information needed to build the URL.
    func alternativePaymentMethodUrl(request: POAlternativePaymentMethodRequest) -> URL

    /// Convert given APMs response URL into response object.
    ///
    /// - Parameter url: url response that our checkout service sends back when the customer gets redirected.
    /// - Returns: response parsed from given url.
    func alternativePaymentMethodResponse(url: URL) throws -> POAlternativePaymentMethodResponse
}
