//
//  DefaultCardTokenizationInteractor.swift
//  ProcessOut
//
//  Created by Andrii Vysotskyi on 18.07.2023.
//

import Foundation
@_spi(PO) import ProcessOut

final class DefaultCardTokenizationInteractor:
    BaseInteractor<CardTokenizationInteractorState>, CardTokenizationInteractor {

    typealias Completion = (Result<POCard, POFailure>) -> Void

    // MARK: -

    init(
        cardsService: POCardsService,
        logger: POLogger,
        configuration: POCardTokenizationConfiguration,
        delegate: POCardTokenizationDelegate?,
        completion: @escaping Completion
    ) {
        self.cardsService = cardsService
        self.logger = logger
        self.configuration = configuration
        self.delegate = delegate
        self.completion = completion
        super.init(state: .idle)
    }

    // MARK: - CardTokenizationInteractor

    override func start() {
        guard case .idle = state else {
            return
        }
        delegate?.cardTokenizationDidEmitEvent(.willStart)
        let startedState = State.Started(
            number: .init(id: \.number, formatter: cardNumberFormatter),
            expiration: .init(id: \.expiration, formatter: cardExpirationFormatter),
            cvc: .init(id: \.cvc),
            cardholderName: .init(id: \.cardholderName)
        )
        state = .started(startedState)
        delegate?.cardTokenizationDidEmitEvent(.didStart)
        logger.debug("Did start card tokenization flow")
    }

    func update(parameterId: State.ParameterId, value: String) {
        guard case .started(var startedState) = state, startedState[keyPath: parameterId].value != value else {
            return
        }
        logger.debug("Will change parameter \(String(describing: parameterId)) value to '\(value)'")
        let oldParameterValue = startedState[keyPath: parameterId].value
        startedState[keyPath: parameterId].value = value
        startedState[keyPath: parameterId].isValid = true
        if areParametersValid(startedState: startedState) {
            logger.debug("Card information is no longer invalid, will reset error message")
            startedState.recentErrorMessage = nil
        }
        if parameterId == startedState.number.id {
            updateIssuerInformation(startedState: &startedState, oldNumber: oldParameterValue)
        }
        self.state = .started(startedState)
        delegate?.cardTokenizationDidEmitEvent(.parametersChanged)
    }

    func setPreferredScheme(_ scheme: String) {
        guard case .started(var startedState) = state else {
            return
        }
        let supportedSchemes = [startedState.issuerInformation?.scheme, startedState.issuerInformation?.coScheme]
        logger.debug("Will change card scheme to \(scheme)")
        guard supportedSchemes.contains(scheme) else {
            logger.info(
                "Aborting attempt to select unknown '\(scheme)' scheme, supported schemes are: \(supportedSchemes)"
            )
            return
        }
        startedState.preferredScheme = scheme
        state = .started(startedState)
        delegate?.cardTokenizationDidEmitEvent(.parametersChanged)
    }

    @MainActor func tokenize() {
        guard case .started(let startedState) = state else {
            return
        }
        guard areParametersValid(startedState: startedState), startedState.recentErrorMessage == nil else {
            logger.debug("Ignoring attempt to tokenize invalid parameters.")
            return
        }
        logger.debug("Will tokenize card")
        delegate?.cardTokenizationDidEmitEvent(.willTokenizeCard)
        state = .tokenizing(snapshot: startedState)
        let request = POCardTokenizationRequest(
            number: cardNumberFormatter.normalized(number: startedState.number.value),
            expMonth: cardExpirationFormatter.expirationMonth(from: startedState.expiration.value) ?? 0,
            expYear: cardExpirationFormatter.expirationYear(from: startedState.expiration.value) ?? 0,
            cvc: startedState.cvc.value,
            name: startedState.cardholderName.value,
            contact: configuration.billingAddress,
            preferredScheme: startedState.preferredScheme,
            metadata: configuration.metadata
        )
        Task {
            do {
                let card = try await cardsService.tokenize(request: request)
                logger.debug("Did tokenize card: \(String(describing: card))")
                delegate?.cardTokenizationDidEmitEvent(.didTokenize(card: card))
                try await delegate?.processTokenizedCard(card: card)
                setTokenizedState(card: card)
            } catch let error as POFailure {
                restoreStartedState(tokenizationFailure: error)
            } catch {
                let failure = POFailure(code: .generic(.mobile), underlyingError: error)
                restoreStartedState(tokenizationFailure: failure)
            }
        }
    }

    func cancel() {
        guard case .started = state else {
            return
        }
        let failure = POFailure(code: .cancelled)
        setFailureStateUnchecked(failure: failure)
    }

    // MARK: - Private Nested Types

    private enum Constants {
        static let iinLength = 6
    }

    // MARK: - Private Properties

    private let cardsService: POCardsService
    private let configuration: POCardTokenizationConfiguration
    private let logger: POLogger
    private let completion: Completion

    private lazy var cardNumberFormatter = POCardNumberFormatter()
    private lazy var cardExpirationFormatter = POCardExpirationFormatter()

    private weak var delegate: POCardTokenizationDelegate?
    private var issuerInformationCancellable: POCancellable?

    // MARK: - State Management

    private func restoreStartedState(tokenizationFailure failure: POFailure) {
        let shouldContinue = delegate?.shouldContinueTokenization(after: failure) ?? true
        guard shouldContinue, case .tokenizing(var startedState) = state else {
            setFailureStateUnchecked(failure: failure)
            return
        }
        var errorMessage: StringResource
        var invalidParameterIds: [State.ParameterId] = []
        switch failure.code {
        case .generic(.requestInvalidCard), .generic(.cardInvalid):
            invalidParameterIds.append(contentsOf: [\.number, \.expiration, \.cvc, \.cardholderName])
            errorMessage = .CardTokenization.Error.card
        case .generic(.cardInvalidNumber), .generic(.cardMissingNumber):
            invalidParameterIds.append(\.number)
            errorMessage = .CardTokenization.Error.cardNumber
        case .generic(.cardInvalidExpiryDate),
             .generic(.cardMissingExpiry),
             .generic(.cardInvalidExpiryMonth),
             .generic(.cardInvalidExpiryYear):
            invalidParameterIds.append(\.expiration)
            errorMessage = .CardTokenization.Error.cardExpiration
        case .generic(.cardBadTrackData):
            invalidParameterIds.append(contentsOf: [\.expiration, \.cvc])
            errorMessage = .CardTokenization.Error.trackData
        case .generic(.cardMissingCvc), .generic(.cardFailedCvc), .generic(.cardFailedCvcAndAvs):
            invalidParameterIds.append(\.cvc)
            errorMessage = .CardTokenization.Error.cvc
        case .generic(.cardInvalidName):
            invalidParameterIds.append(\.cardholderName)
            errorMessage = .CardTokenization.Error.cardholderName
        default:
            errorMessage = .CardTokenization.Error.generic
        }
        for keyPath in invalidParameterIds {
            startedState[keyPath: keyPath].isValid = false
        }
        // todo(andrii-vysotskyi): remove hardcoded message when backend is updated with localized values
        startedState.recentErrorMessage = String(resource: errorMessage)
        state = .started(startedState)
        logger.debug("Did recover started state after failure: \(failure)")
    }

    private func setTokenizedState<T>(result: Result<T, POFailure>, card: POCard) {
        switch result {
        case .success:
            setTokenizedState(card: card)
        case .failure(let failure):
            restoreStartedState(tokenizationFailure: failure)
        }
    }

    private func setTokenizedState(card: POCard) {
        guard case .tokenizing(let snapshot) = state else {
            return
        }
        let tokenizedState = State.Tokenized(card: card, cardNumber: snapshot.number.value)
        state = .tokenized(tokenizedState)
        logger.info("Did tokenize/process card", attributes: ["CardId": card.id])
        delegate?.cardTokenizationDidEmitEvent(.didComplete)
        completion(.success(card))
    }

    private func setFailureStateUnchecked(failure: POFailure) {
        state = .failure(failure)
        logger.info("Did fail to tokenize/process card \(failure)")
        completion(.failure(failure))
    }

    // MARK: - Card Issuer Information

    private func updateIssuerInformation(startedState: inout State.Started, oldNumber: String) {
        if let iin = issuerIdentificationNumber(number: startedState.number.value) {
            guard iin != issuerIdentificationNumber(number: oldNumber) else {
                return
            }
            startedState.issuerInformation = issuerInformation(number: startedState.number.value)
            startedState.preferredScheme = nil
            issuerInformationCancellable?.cancel()
            logger.debug("Will fetch issuer information", attributes: ["IIN": iin])
            issuerInformationCancellable = cardsService.issuerInformation(iin: iin) { [logger, weak self] result in
                guard case .started(var startedState) = self?.state else {
                    return
                }
                switch result {
                case .failure(let failure) where failure.code == .cancelled:
                    break
                case .failure(let failure):
                    // Inability to select co-scheme is considered minor issue and we still want
                    // users to be able to continue tokenization. So errors are silently ignored.
                    logger.info("Did fail to fetch issuer information: \(failure)", attributes: ["IIN": iin])
                case .success(let issuerInformation):
                    startedState.issuerInformation = issuerInformation
                    if let delegate = self?.delegate {
                        startedState.preferredScheme = delegate.preferredScheme(issuerInformation: issuerInformation)
                    } else {
                        startedState.preferredScheme = issuerInformation.scheme
                    }
                    self?.state = .started(startedState)
                }
            }
        } else {
            startedState.issuerInformation = issuerInformation(number: startedState.number.value)
            startedState.preferredScheme = nil
        }
    }

    private func issuerIdentificationNumber(number: String) -> String? {
        let normalizedNumber = cardNumberFormatter.normalized(number: number)
        guard normalizedNumber.count >= Constants.iinLength else {
            return nil
        }
        return String(normalizedNumber.prefix(Constants.iinLength))
    }

    /// Returns locally generated issuer information where only `scheme` property is set.
    private func issuerInformation(number: String) -> POCardIssuerInformation? {
        guard let scheme = CardTokenizationSchemeProvider().scheme(cardNumber: number) else {
            return nil
        }
        return .init(scheme: scheme)
    }

    // MARK: - Utils

    private func areParametersValid(startedState: State.Started) -> Bool {
        let parameters = [startedState.number, startedState.expiration, startedState.cvc, startedState.cardholderName]
        return parameters.allSatisfy(\.isValid)
    }
}
