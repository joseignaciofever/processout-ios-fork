//
//  POGatewayConfigurationsRepository.swift
//  ProcessOut
//
//  Created by Andrii Vysotskyi on 12.10.2022.
//

import Foundation

final class GatewayConfigurationsRepository: POGatewayConfigurationsRepositoryType {

    init(connector: HttpConnectorType, failureFactory: RepositoryFailureFactoryType) {
        self.connector = connector
        self.failureFactory = failureFactory
    }

    // MARK: - POGatewayConfigurationsRepositoryType

    func all(
        request: POAllGatewayConfigurationsRequest,
        completion: @escaping (Result<POAllGatewayConfigurationsResponse, Failure>) -> Void
    ) {
        var query = request.paginationOptions?.queryItems ?? [:]
        query["filter"] = request.filter?.rawValue
        query["with_disabled"] = request.includeDisabled
        query["expand_merchant_accounts"] = true
        let request = HttpConnectorRequest<POAllGatewayConfigurationsResponse>.get(
            path: "/gateway-configurations", query: query
        )
        connector.execute(request: request) { [failureFactory] result in
            completion(result.mapError(failureFactory.repositoryFailure))
        }
    }

    func find(
        request: POFindGatewayConfigurationRequest,
        completion: @escaping (Result<POGatewayConfiguration, Failure>) -> Void
    ) {
        struct Response: Decodable {
            let gatewayConfiguration: POGatewayConfiguration
        }
        let httpRequest = HttpConnectorRequest<Response>.get(
            path: "/gateway-configurations/" + request.id,
            query: [
                "expand": request.expands.map(\.rawValue).joined(separator: ",")
            ]
        )
        connector.execute(request: httpRequest) { [failureFactory] result in
            completion(result.map(\.gatewayConfiguration).mapError(failureFactory.repositoryFailure))
        }
    }

    // MARK: - Private Properties

    private let connector: HttpConnectorType
    private let failureFactory: RepositoryFailureFactoryType
}
