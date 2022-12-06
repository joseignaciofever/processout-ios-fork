//
//  CodeTextFieldComponentView.swift
//  ProcessOut
//
//  Created by Andrii Vysotskyi on 24.11.2022.
//

import UIKit

final class CodeTextFieldComponentView: UIView {

    struct ViewModel {

        /// Components value.
        let value: Character?

        /// Carret position if any.
        let carretPosition: CodeTextFieldCarretPosition?

        /// Style.
        let style: POTextFieldStyle
    }

    init(didSelect: @escaping (CodeTextFieldCarretPosition) -> Void) {
        self.didSelect = didSelect
        super.init(frame: .zero)
        commonInit()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: ViewModel, animated: Bool) {
        UIView.performWithoutAnimation {
            switch viewModel.carretPosition {
            case .none:
                carretView.setHidden(true)
                removeCarretAnimation()
            case .before:
                animateCarretBlinking()
                carretView.setHidden(false)
                carretCenterConstraint.constant = -Constants.carretOffset
            case .after:
                animateCarretBlinking()
                carretView.setHidden(false)
                carretCenterConstraint.constant = Constants.carretOffset
            }
            setNeedsLayout()
            layoutIfNeeded()
        }
        UIView.animate(withDuration: Constants.animationDuration) { [self] in
            CATransaction.begin()
            CATransaction.setDisableActions(!animated)
            let previousAttributedText = valueLabel.attributedText
            valueLabel.attributedText = AttributedStringBuilder()
                .typography(viewModel.style.text.typography)
                .alignment(.center)
                .textColor(viewModel.style.text.color)
                .string(viewModel.value.map(String.init) ?? "")
                .build()
            if animated,
               valueLabel.attributedText != previousAttributedText,
               valueLabel.attributedText?.string == previousAttributedText?.string {
                animateValueLabelTransition()
            }
            apply(style: viewModel.style.border)
            apply(style: viewModel.style.shadow)
            backgroundColor = viewModel.style.backgroundColor
            carretView.backgroundColor = viewModel.style.tintColor
            CATransaction.commit()
        }
        currentViewModel = viewModel
    }

    // MARK: - Private Nested Types

    private enum Constants {
        static let size = CGSize(width: 48, height: 48)
        static let minimumWidth: CGFloat = 42
        static let carretSize = CGSize(width: 2, height: 28)
        static let carretOffset: CGFloat = 11
        static let animationDuration: TimeInterval = 0.25
        static let carretAnimationDuration: TimeInterval = 0.4
        static let carretAnimationKey = "BlinkingAnimation"
    }

    // MARK: - Private Properties

    private let didSelect: (CodeTextFieldCarretPosition) -> Void

    private lazy var valueLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = false
        label.isUserInteractionEnabled = false
        return label
    }()

    private lazy var carretView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.alpha = 1
        return view
    }()

    private lazy var carretCenterConstraint: NSLayoutConstraint = {
        carretView.centerXAnchor.constraint(equalTo: centerXAnchor)
    }()

    private var currentViewModel: ViewModel?

    // MARK: - Private Methods

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        let widthConstraint = widthAnchor.constraint(equalToConstant: Constants.size.width)
        widthConstraint.priority = .defaultHigh
        let constraints = [
            heightAnchor.constraint(equalToConstant: Constants.size.height),
            widthAnchor.constraint(greaterThanOrEqualToConstant: Constants.minimumWidth),
            widthConstraint
        ]
        NSLayoutConstraint.activate(constraints)
        clipsToBounds = true
        addValueLabelSubview()
        addCarretSubview()
        configureGestures()
    }

    private func addValueLabelSubview() {
        addSubview(valueLabel)
        let constraints = [
            valueLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor)
        ]
        NSLayoutConstraint.activate(constraints)
    }

    private func addCarretSubview() {
        addSubview(carretView)
        let constraints = [
            carretView.widthAnchor.constraint(equalToConstant: Constants.carretSize.width),
            carretView.heightAnchor.constraint(equalToConstant: Constants.carretSize.height),
            carretView.centerYAnchor.constraint(equalTo: centerYAnchor),
            carretCenterConstraint
        ]
        NSLayoutConstraint.activate(constraints)
    }

    private func configureGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didRecognizeTapGesture))
        addGestureRecognizer(tapGesture)
    }

    private func animateCarretBlinking() {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0
        animation.duration = Constants.carretAnimationDuration
        animation.autoreverses = true
        animation.repeatCount = .greatestFiniteMagnitude
        carretView.layer.add(animation, forKey: Constants.carretAnimationKey)
    }

    private func removeCarretAnimation() {
        carretView.layer.removeAnimation(forKey: Constants.carretAnimationKey)
    }

    private func animateValueLabelTransition() {
        let transition = CATransition()
        transition.type = .fade
        if let backgroundAnimation = layer.action(forKey: "backgroundColor") as? CAAnimation {
            transition.duration = backgroundAnimation.duration
            transition.timingFunction = backgroundAnimation.timingFunction
        }
        valueLabel.layer.add(transition, forKey: "transition")
    }

    // MARK: - Actions

    @objc
    private func didRecognizeTapGesture(gesture: UITapGestureRecognizer) {
        let desiredCarretPosition: CodeTextFieldCarretPosition
        if currentViewModel?.value != nil, gesture.location(in: self).x > bounds.midX {
            desiredCarretPosition = .after
        } else {
            desiredCarretPosition = .before
        }
        didSelect(desiredCarretPosition)
    }
}
