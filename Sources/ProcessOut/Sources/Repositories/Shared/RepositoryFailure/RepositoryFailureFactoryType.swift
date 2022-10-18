//
//  RepositoryFailureFactoryType.swift
//  ProcessOut
//
//  Created by Andrii Vysotskyi on 16.10.2022.
//

protocol RepositoryFailureFactoryType {

    /// Creates repository failure with given ``HttpConnectorFailure`` instance.
    func repositoryFailure(from failure: HttpConnectorFailure) -> PORepositoryFailure
}
