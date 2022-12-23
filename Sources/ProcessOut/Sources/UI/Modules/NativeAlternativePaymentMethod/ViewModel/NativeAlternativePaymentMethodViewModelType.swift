//
//  NativeAlternativePaymentMethodViewModelType.swift
//  ProcessOut
//
//  Created by Andrii Vysotskyi on 19.10.2022.
//

import Foundation
import UIKit

protocol NativeAlternativePaymentMethodViewModelType: ViewModelType
    where State == NativeAlternativePaymentMethodViewModelState {

    /// Submits parameter values.
    func submit()
}

enum NativeAlternativePaymentMethodViewModelState {

    typealias ParameterType = PONativeAlternativePaymentMethodParameter.ParameterType

    struct Action {

        /// Action title.
        let title: String

        /// Boolean value indicating whether action is enabled.
        let isEnabled: Bool

        /// Action handler.
        let handler: () -> Void
    }

    struct Parameter {

        /// Parameter's name.
        let name: String

        /// Parameter's placeholder.
        let placeholder: String?

        /// Current parameter's value.
        let value: String

        /// Parameter type.
        let type: ParameterType

        /// Required parameter's length.
        let length: Int?

        /// Error message associated with this parameter if any.
        let errorMessage: String?

        /// Updates parameter value.
        let update: (_ value: String) -> Void
    }

    struct Started {

        /// Title.
        let title: String

        /// Available parameters.
        let parameters: [Parameter]

        /// Boolean value indicating if data is being submitted.
        let isSubmitting: Bool

        /// Action information.
        let action: Action
    }

    struct Submitted {

        /// Message.
        let message: String

        /// Gateway's logo image.
        let logoImage: UIImage?

        /// Image illustrating action.
        let image: UIImage?

        /// Boolean value that indicates whether payment is already captured.
        let isCaptured: Bool
    }

    case idle, loading, started(Started), submitted(Submitted)
}
