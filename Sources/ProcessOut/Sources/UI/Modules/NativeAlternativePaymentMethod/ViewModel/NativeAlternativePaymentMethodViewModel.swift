//
//  NativeAlternativePaymentMethodViewModel.swift
//  ProcessOut
//
//  Created by Andrii Vysotskyi on 19.10.2022.
//

import Foundation

final class NativeAlternativePaymentMethodViewModel:
    BaseViewModel<NativeAlternativePaymentMethodViewModelState>, NativeAlternativePaymentMethodViewModelType {

    init(
        interactor: any NativeAlternativePaymentMethodInteractorType,
        router: any RouterType<NativeAlternativePaymentMethodRoute>,
        uiConfiguration: PONativeAlternativePaymentMethodUiConfiguration?,
        completion: ((Result<Void, POFailure>) -> Void)?
    ) {
        self.interactor = interactor
        self.router = router
        self.uiConfiguration = uiConfiguration
        self.completion = completion
        super.init(state: .idle)
        observeInteractorStateChanges()
    }

    override func start() {
        interactor.start()
    }

    func submit() {
        interactor.submit()
    }

    // MARK: - Private Nested Types

    private typealias InteractorState = NativeAlternativePaymentMethodInteractorState
    private typealias Strings = ProcessOut.Strings.NativeAlternativePayment

    private enum Constants {
        static let captureSuccessCompletionDelay: TimeInterval = 3
    }

    // MARK: - NativeAlternativePaymentMethodInteractorType

    private let interactor: any NativeAlternativePaymentMethodInteractorType
    private let router: any RouterType<NativeAlternativePaymentMethodRoute>
    private let uiConfiguration: PONativeAlternativePaymentMethodUiConfiguration?
    private let completion: ((Result<Void, POFailure>) -> Void)?

    // MARK: - Private Methods

    private func observeInteractorStateChanges() {
        interactor.didChange = { [weak self] in self?.configureWithInteractorState() }
    }

    private func configureWithInteractorState() {
        switch interactor.state {
        case .idle:
            state = .idle
        case .starting:
            state = .loading
        case .started(let startedState):
            state = convertToState(startedState: startedState)
        case .failure(let failure):
            completion?(.failure(failure))
        case .submitting(let startedStateSnapshot):
            state = convertToState(startedState: startedStateSnapshot, isSubmitting: true)
        case .submitted:
            completion?(.success(()))
        case .awaitingCapture(let awaitingCaptureState):
            state = convertToState(awaitingCaptureState: awaitingCaptureState)
        case .captured(let capturedState):
            configure(with: capturedState)
        case .captureTimeout:
            let failure = POFailure(code: .timeout)
            completion?(.failure(failure))
        }
    }

    private func convertToState(
        startedState: InteractorState.Started, isSubmitting: Bool = false
    ) -> State {
        let parameters = startedState.parameters.map { parameter -> State.Parameter in
            let value = startedState.values[parameter.key]
            let viewModel = State.Parameter(
                name: parameter.displayName,
                placeholder: placeholder(for: parameter),
                value: value?.value ?? "",
                type: parameter.type,
                length: parameter.length,
                errorMessage: value?.recentErrorMessage,
                update: { [weak self] newValue in
                    _ = self?.interactor.updateValue(newValue, for: parameter.key)
                }
            )
            return viewModel
        }
        let actionTitle = submitActionTitle(amount: startedState.amount, currencyCode: startedState.currencyCode)
        let state = State.Started(
            title: uiConfiguration?.title ?? Strings.title(startedState.gatewayDisplayName),
            parameters: parameters,
            failureMessage: nil,
            isSubmitting: isSubmitting,
            action: .init(title: actionTitle, isEnabled: startedState.isSubmitAllowed) { [weak self] in
                self?.interactor.submit()
            }
        )
        return .started(state)
    }

    private func convertToState(awaitingCaptureState: InteractorState.AwaitingCapture) -> State {
        guard let expectedActionMessage = awaitingCaptureState.expectedActionMessage else {
            return .loading
        }
        let pendingActionState = State.PendingAction(
            gatewayLogo: awaitingCaptureState.gatewayLogo,
            message: expectedActionMessage,
            image: nil
        )
        return .pendingAction(pendingActionState)
    }

    private func configure(with capturedState: InteractorState.Captured) {
        Timer.scheduledTimer(
            withTimeInterval: Constants.captureSuccessCompletionDelay,
            repeats: false,
            block: { [weak self] _ in
                self?.completion?(.success(()))
            }
        )
        let successState = State.Success(
            gatewayLogo: capturedState.gatewayLogo, message: Strings.Success.message
        )
        state = .success(successState)
    }

    // MARK: - Utils

    private func placeholder(for parameter: PONativeAlternativePaymentMethodParameter) -> String? {
        switch parameter.type {
        case .numeric:
            return nil
        case .text:
            return Strings.Text.placeholder
        case .email:
            return Strings.Email.placeholder
        case .phone:
            return Strings.Phone.placeholder
        }
    }

    private func submitActionTitle(amount: Decimal, currencyCode: String) -> String {
        if let title = uiConfiguration?.primaryActionTitle {
            return title
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = 0
        // swiftlint:disable:next legacy_objc_type
        if let formattedAmount = formatter.string(from: amount as NSDecimalNumber) {
            return Strings.SubmitButton.title(formattedAmount)
        }
        return Strings.SubmitButton.defaultTitle
    }
}
