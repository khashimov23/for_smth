//
//  SecondSignupVC.swift
//  konnex-ios
//
//  Created by Shavkat Khoshimov on 16/05/23.
//  Copyright © 2023 Achilov Bakhrom. All rights reserved.
//
import UIKit
import Combine


class SecondSignupVC: BaseViewController, UITextFieldDelegate, UIViewControllerTransitioningDelegate {
    
    var viewModel: SignUpViewModel
    var cancellables = Set<AnyCancellable>()
    var isToSignInVC = false
    var user: SignUpUser
    
    init(viewModel: SignUpViewModel, user: SignUpUser) {
        self.viewModel = viewModel
        self.user = user
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func bindViewModel() {
        viewModel.viewModelEvent.sink { [weak self] (value) in
            self?.handleViewModelEvent(state: value)
        }.store(in: &cancellables)
        
        viewModel.errorMessagePub.sink { [weak self] (value) in
            self?.showSnackBar(text: value)
        }.store(in: &cancellables)
        
              
        viewModel.isValidPasswordPub.receive(on: DispatchQueue.main).sink { [weak self] (value) in
            self?.newPasswordView.itemLabel.textColor = value ? UIColor.subtitleColorGrey() : .textRed()
        }.store(in: &cancellables)

        viewModel.isPasswordMatchesPub.receive(on: DispatchQueue.main).sink { [weak self] (value) in
            guard let self = self else { return }
            if self.newPasswordView.itemTextField.text.isNilOrEmpty {
                self.confirmPasswordView.itemLabel.textColor = .textRed()
            } else {
                self.confirmPasswordView.itemLabel.textColor = value ? UIColor.subtitleColorGrey() : .textRed()
            }
            self.validToSubmit = value
        }.store(in: &cancellables)
        
        viewModel.openConfirmationVC.receive(on: DispatchQueue.main).sink { [weak self] (value) in
            self?.show(ConfirmationVC(), sender: self)
        }.store(in: &cancellables)
    }
    
    
    func setupPublishers() {
        NotificationCenter.default
            .publisher(for: NSNotification.Name.UITextFieldTextDidChange, object: newPasswordView.itemTextField)
            .map { ($0.object as! UITextField).text ?? "" }
            .assign(to: \.password, on: viewModel)
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: NSNotification.Name.UITextFieldTextDidChange, object: confirmPasswordView.itemTextField)
            .map { ($0.object as! UITextField).text ?? "" }
            .assign(to: \.confirmPassword, on: viewModel)
            .store(in: &cancellables)
    }
    
    
    
    lazy var scrollView: UIScrollView = {
        let scrollV = UIScrollView()
        scrollV.backgroundColor = UIColor.lightBackgroundColor()
        return scrollV
    }()
    
    lazy var containerV: UIView = {
        let contentView = UIView(frame: .zero)
        contentView.backgroundColor = .clear
        return contentView
    }()
    
    lazy var backImageV: UIImageView = {
        let img = UIImageView(frame: UIScreen.main.bounds)
        img.image = UIImage(named: "signInBackImage")
        img.contentMode = .scaleAspectFill
        img.layer.masksToBounds = true
        return img
    }()
    
    lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.distribution = .fill
        return stack
    }()
    
    lazy var logoImageView: UIImageView = {
        let logoImageView = UIImageView(frame: .zero)
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.image = UIImage(named: "kennektNewLogo")
        return logoImageView
    }()
    
    lazy var titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.text = "Create an account"
        label.textAlignment = .center
        label.textColor = UIColor.blackDark()
        label.font = AppFont.font(type: .bold, size: 20)
        return label
    }()
    
    lazy var descrLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.text = "The most effective business management system"
        label.textAlignment = .center
        label.textColor = UIColor.subtitleColorGrey()
        label.font = AppFont.font(type: .regular, size: 14)
        return label
    }()
    
    lazy var newPasswordView: SignUpTextFieldView = {
        let password = SignUpTextFieldView(title: "Password*", placeholderText: "Create your password")
        password.itemTextField.isSecureTextEntry = true
        password.passwordViewOption.isHidden = false
        password.itemTextField.delegate = self
        return password
    }()

    lazy var confirmPasswordView: SignUpTextFieldView = {
        let confirm = SignUpTextFieldView(title: "Confirm Password*", placeholderText: "Confirm your password")
        confirm.passwordViewOption.isHidden = false
        confirm.itemTextField.isSecureTextEntry = true
        confirm.itemTextField.delegate = self
        return confirm
    }()
    
    lazy var signUpBtn: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("SIGN UP", for: .normal)
        btn.titleLabel?.font = AppFont.font(type: .bold, size: 14)
        btn.backgroundColor = UIColor.primare()
        btn.setTitleColor(UIColor.lightBackgroundColor(), for: .normal)
        btn.layer.cornerRadius = 8
        btn.layer.masksToBounds = true
        btn.addTarget(self, action: #selector(signUpButtonClicked), for: .touchUpInside)
        return btn
    }()
    
    lazy var signingLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.text = "By signing in you agree to KENNEKT's"
        label.textAlignment = .center
        label.textColor = UIColor.subtitleColorGrey()
        label.font = AppFont.font(type: .regular, size: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    lazy var signInLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.text = "Already have an account? Sign In"
        label.textAlignment = .center
        label.textColor = UIColor.subtitleColorGrey()
        label.font = AppFont.font(type: .regular, size: 14)
        let tapgesture = UITapGestureRecognizer(target: self, action: #selector(signInLabelClicked))
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(tapgesture)
        return label
    }()
        
    
    fileprivate func setSignupButtonState() {
        if validToSubmit {
            self.signUpBtn.isEnabled = true
            self.signUpBtn.backgroundColor = UIColor.primare()
        } else {
            self.signUpBtn.isEnabled = false
            self.signUpBtn.backgroundColor = UIColor.iconGray()
        }
    }
    
    var validToSubmit: Bool = false {
        didSet {
            setSignupButtonState()
        }
    }
    
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Disallow whitespace input
        let whitespaceCharacterSet = CharacterSet.whitespaces
        let range = string.rangeOfCharacter(from: whitespaceCharacterSet)
        return range == nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if isToSignInVC {
            super.viewWillDisappear(animated)
            self.navigationController?.setNavigationBarHidden(true, animated: true)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.clipsToBounds = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.bindViewModel()
        self.setupPublishers()
        labelAttribute()
        self.configureSubViews()
    }
    
    func setUpStackViewItems() {
        stackView.addArrangedSubview(newPasswordView)
        stackView.addArrangedSubview(confirmPasswordView)
    }
    
    
    func labelAttribute() {
        var textArray = [String]()
        var fontArray = [UIFont]()
        var colorArray = [UIColor]()
        textArray.append("Already have an account?")
        textArray.append(" Sign In")
        fontArray.append(AppFont.font(type: .regular, size: 14))
        fontArray.append(AppFont.font(type: .regular, size: 14))
        colorArray.append(UIColor.subtitleColorGrey())
        colorArray.append(UIColor.primare())
        signInLabel.attributedText = getAttributedString(arrayText: textArray, arrayColors: colorArray, arrayFonts: fontArray)
    }
    
    
    func getAttributedString(arrayText:[String]?, arrayColors:[UIColor]?, arrayFonts:[UIFont]?) -> NSMutableAttributedString {
        let finalAttributedString = NSMutableAttributedString()
        for i in 0 ..< (arrayText?.count)! {
            let attributes = [NSAttributedString.Key.foregroundColor: arrayColors?[i], NSAttributedString.Key.font: arrayFonts?[i]]
            let attributedStr = (NSAttributedString.init(string: arrayText?[i] ?? "", attributes: attributes as [NSAttributedString.Key : Any]))
            if i != 0 {
                finalAttributedString.append(NSAttributedString.init(string: " "))
            }
            finalAttributedString.append(attributedStr)
        }
        return finalAttributedString
    }
    
    
    @objc func signUpButtonClicked() {
        self.user.password = newPasswordView.itemTextField.text
        self.user.confirmPassword = confirmPasswordView.itemTextField.text
        closeKeyboard()
        viewModel.signup(newUser: self.user)
    }
    
        
    @objc private func signInLabelClicked() {
        closeKeyboard()
        guard let signInVC = self.navigationController?.viewControllers.first(where: {$0 is SignInVC}) as? SignInVC else { return }
        self.navigationController?.popToViewController(signInVC, animated: true)
    }
}



// MARK: Constraints
extension SecondSignupVC {
    
    fileprivate func configureSubViews(){
        setUpStackViewItems()
        
        konnex_ios.addSubviews(parentView: self.view, views: [scrollView])
        konnex_ios.addSubviews(parentView: scrollView, views: [containerV])
        konnex_ios.addSubviews(parentView: containerV, views: [
            backImageV,logoImageView,titleLabel,descrLabel,stackView,
            signUpBtn,signingLabel,signInLabel
        ])
        
        configureUI()
    }
    
    fileprivate func configureUI() {
        let padding: CGFloat = 25
        scrollView.contentSize = containerV.frame.size
        scrollView.fillSuperview()
        containerV.fillSuperview()
        backImageV.fillSuperview()

        logoImageView.top(containerV.topAnchor, 120)
        logoImageView.centerX(containerV.centerXAnchor)
        
        titleLabel.top(logoImageView.bottomAnchor, padding)
        titleLabel.centerX(containerV.centerXAnchor)
        
        descrLabel.top(titleLabel.bottomAnchor, 16)
        descrLabel.left(containerV.leftAnchor, padding)
        descrLabel.right(containerV.rightAnchor, -padding)
        descrLabel.height(20)
        
        stackView.top(descrLabel.bottomAnchor, padding+padding)
        stackView.centerX(containerV.centerXAnchor)
        stackView.widthForLayout(containerV.widthAnchor, -32)
        
        signUpBtn.bottom(signingLabel.topAnchor, -padding)
        signUpBtn.left(containerV.leftAnchor, 16)
        signUpBtn.right(containerV.rightAnchor, -16)
        signUpBtn.height(50)
        
        signingLabel.bottom(signInLabel.topAnchor, -padding)
        signingLabel.centerX(containerV.centerXAnchor)
        signingLabel.left(containerV.leftAnchor, padding)
        signingLabel.right(containerV.rightAnchor, -padding)
        
        signInLabel.bottom(containerV.bottomAnchor, -10-safeAreaBottomHeight)
        signInLabel.centerX(containerV.centerXAnchor)
        signInLabel.left(containerV.leftAnchor, padding)
        signInLabel.right(containerV.rightAnchor, -padding)
    }
}

