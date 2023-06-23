//
//  FirstSignupVC.swift
//  konnex-ios
//
//  Created by Shavkat Khoshimov on 16/05/23.
//  Copyright © 2023 Achilov Bakhrom. All rights reserved.
//

import UIKit
import Combine

class FirstSignupVC: BaseViewController, UITextFieldDelegate, UIViewControllerTransitioningDelegate {
    
    var viewModel: SignUpViewModel
    var cancellables = Set<AnyCancellable>()
    var isToSignInVC = false
    
    init(viewModel: SignUpViewModel) {
        self.viewModel = viewModel
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
        
        viewModel.isValidFirstNamePub.receive(on: DispatchQueue.main).sink { [weak self] (value) in
            self?.firstNameView.itemLabel.textColor = value ? UIColor.subtitleColorGrey() : .textRed()
        }.store(in: &cancellables)
        
        viewModel.isValidLastNamePub.receive(on: DispatchQueue.main).sink { [weak self] (value) in
            self?.lastNameView.itemLabel.textColor = value ? UIColor.subtitleColorGrey() : .textRed()
        }.store(in: &cancellables)
        
        viewModel.isValidEmailPub.receive(on: DispatchQueue.main).sink { [weak self] (value) in
            self?.emailView.itemLabel.textColor = value ? UIColor.subtitleColorGrey() : .textRed()
        }.store(in: &cancellables)
        
        viewModel.isValidPhonePub.receive(on: DispatchQueue.main).sink { [weak self] (value) in
            self?.phoneView.itemLabel.textColor = value ? UIColor.subtitleColorGrey() : .textRed()
        }.store(in: &cancellables)
                
        viewModel.isSubmitEnabled.receive(on: DispatchQueue.main).sink { [weak self] (value) in
            self?.validToSubmit = value
        }.store(in: &cancellables)
        
        viewModel.openConfirmationVC.receive(on: DispatchQueue.main).sink { [weak self] (value) in
            self?.show(ConfirmationVC(), sender: self)
        }.store(in: &cancellables)
    }
    
    
    func setupPublishers() {
        NotificationCenter.default
            .publisher(for: NSNotification.Name.UITextFieldTextDidChange, object: firstNameView.itemTextField)
            .map { ($0.object as! UITextField).text ?? "" }
            .assign(to: \.firstName, on: viewModel)
            .store(in: &cancellables)
        
        NotificationCenter.default
            .publisher(for: NSNotification.Name.UITextFieldTextDidChange, object: lastNameView.itemTextField)
            .map { ($0.object as! UITextField).text ?? "" }
            .assign(to: \.lastName, on: viewModel)
            .store(in: &cancellables)
        
        NotificationCenter.default
            .publisher(for: NSNotification.Name.UITextFieldTextDidChange, object: emailView.itemTextField)
            .map { ($0.object as! UITextField).text ?? "" }
            .assign(to: \.email, on: viewModel)
            .store(in: &cancellables)
        
        NotificationCenter.default
            .publisher(for: NSNotification.Name.UITextFieldTextDidChange, object: phoneView.itemTextField)
            .map { ($0.object as! UITextField).text ?? "" }
            .assign(to: \.phone, on: viewModel)
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

    
    lazy var emailView: SignUpTextFieldView = {
        let email = SignUpTextFieldView(title: "Email address*", placeholderText: "Enter your email address")
        email.itemTextField.keyboardType = .emailAddress
        email.itemTextField.delegate = self
        return email
    }()
    
    lazy var firstNameView: SignUpTextFieldView = {
        let firstName = SignUpTextFieldView(title: "First name*", placeholderText: "Enter your first name")
        firstName.itemTextField.keyboardType = .default
        firstName.itemTextField.delegate = self
        return firstName
    }()
    
    lazy var lastNameView: SignUpTextFieldView = {
        let lastName = SignUpTextFieldView(title: "Last name*", placeholderText: "Enter your last name")
        lastName.itemTextField.keyboardType = .default
        lastName.itemTextField.delegate = self
        return lastName
    }()
    
    lazy var phoneView: SignUpTextFieldView = {
        let phone = SignUpTextFieldView(title: "Phone number*", placeholderText: "Enter your mobile phone number")
        phone.itemTextField.keyboardType = .numberPad
        phone.itemTextField.tag = 100
        phone.itemTextField.leftView = phone.countryFlagBtn
        phone.itemTextField.leftViewMode = .always
        phone.itemTextField.delegate = self
        phone.countryFlagBtn.addTarget(self, action: #selector(presentCountryFlagVC), for: .touchUpInside)
        return phone
    }()
    
    lazy var continueBtn: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("CONTINUE", for: .normal)
        btn.titleLabel?.font = AppFont.font(type: .bold, size: 14)
        btn.backgroundColor = UIColor.primare()
        btn.setTitleColor(UIColor.lightBackgroundColor(), for: .normal)
        btn.layer.cornerRadius = 8
        btn.layer.masksToBounds = true
        btn.addTarget(self, action: #selector(continueBtnClicked), for: .touchUpInside)
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
    
    var defaultPhoneCode: String?
    var defaultCountry: String?
    
    fileprivate func setSignupButtonState() {
        if validToSubmit {
            self.continueBtn.isEnabled = true
            self.continueBtn.backgroundColor = UIColor.primare()
        } else {
            self.continueBtn.isEnabled = false
            self.continueBtn.backgroundColor = UIColor.iconGray()
        }
    }
    
    var checkBoxClicked = false {
        didSet {
            setSignupButtonState()
        }
    }
    
    var validToSubmit: Bool = false {
        didSet {
            setSignupButtonState()
        }
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
        getUserRegionCodeAndSet()
        NotificationCenter.Publisher(center: .default, name: .update_country_flag).sink { notif in
            if let notifDict = notif.userInfo as? [String: Any], let countryInfo = notifDict["countryInfo"] as? CountryInfo {
                self.defaultCountry = countryInfo.countryCode
                self.phoneView.countryFlagBtn.setTitle(countryInfo.flag, for: .normal)
                self.defaultPhoneCode = countryInfo.extensionCode
                self.phoneView.itemTextField.text = self.defaultPhoneCode
            }
        }.store(in: &cancellables)
    }
    
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField.keyboardType == .numberPad {
            // Check if the change would remove the first character
            if range.location == 0 && string.isEmpty {
                return false // Prevent deletion of the first character
            }

            return true
        } else {
            guard range.location == 0 else {
                return true
            }
            // Disallow whitespace input
            let whitespaceCharacterSet = CharacterSet.whitespaces
            let range = string.rangeOfCharacter(from: whitespaceCharacterSet)
            return range == nil
        }
    }
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        guard textField.tag == 1 else { return }
        guard let phoneCode = defaultPhoneCode, let text = textField.text else { return }
        if phoneCode.count >= text.count {
            if defaultPhoneCode == textField.text {
                self.phoneView.countryFlagBtn.setTitle(String.flag(for: defaultCountry ?? ""), for: .normal)
                return
            } else {
                self.phoneView.countryFlagBtn.setTitle("👆", for: .normal)
            }
        }
    }
    
    
    func setUpStackViewItems(){
        stackView.addArrangedSubview(emailView)
        stackView.addArrangedSubview(firstNameView)
        stackView.addArrangedSubview(lastNameView)
        stackView.addArrangedSubview(phoneView)
    }
    
    fileprivate func getUserRegionCodeAndSet() {
        let locale = Locale.current
        self.defaultCountry = locale.regionCode
        if let country = self.defaultCountry {
            self.phoneView.countryFlagBtn.setTitle(String.flag(for: country), for: .normal)
            self.defaultPhoneCode = NSLocale().getExtensionCodeWith(countryCode: country)
            self.phoneView.itemTextField.text = self.defaultPhoneCode
        }
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
    
    @objc func openSignInVC() {
        isToSignInVC = true
        self.navigationController?.popViewController(animated: true)
    }
    
    
    @objc func continueBtnClicked() {
        closeKeyboard()
        let user = SignUpUser()
        user.firstName = firstNameView.itemTextField.text
        user.lastName = lastNameView.itemTextField.text
        user.username = emailView.itemTextField.text?.lowercased()
        user.mobile = phoneView.itemTextField.text
        let vc = SecondSignupVC(viewModel: SignUpViewModel(), user: user)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    
    @objc func presentCountryFlagVC() {
        DispatchQueue.main.async {
            let countryVC = CountryFlagVC()
            countryVC.modalPresentationStyle = .formSheet
            self.present(countryVC, animated: true)
        }
    }
    
    
    @objc func checkBoxClicked(btn: UIButton) {
        btn.isSelected.toggle()
        self.checkBoxClicked = btn.isSelected
    }
    
    let signInVC = SignInVC(viewModel: SigninViewModel())
                            
    @objc private func signInLabelClicked() {
        navigationController?.pushViewController(signInVC, animated: true)
    }
}



// MARK: Constraints
extension FirstSignupVC {
    
    fileprivate func configureSubViews(){
        setUpStackViewItems()
        
        konnex_ios.addSubviews(parentView: self.view, views: [scrollView])
        konnex_ios.addSubviews(parentView: scrollView, views: [containerV])
        konnex_ios.addSubviews(parentView: containerV, views: [
            backImageV,logoImageView,titleLabel,descrLabel, continueBtn,signingLabel,signInLabel,stackView
        ])
        
        configureUI()
    }
    
    fileprivate func configureUI() {
        let padding: CGFloat = 25
        scrollView.contentSize = containerV.frame.size
        scrollView.fillSuperview()
        containerV.fillSuperview()
        backImageV.fillSuperview()
        
        logoImageView.top(containerV.topAnchor, 80)
        logoImageView.centerX(containerV.centerXAnchor)
        
        titleLabel.top(logoImageView.bottomAnchor, padding)
        titleLabel.centerX(containerV.centerXAnchor)
        
        descrLabel.top(titleLabel.bottomAnchor, 10)
        descrLabel.left(containerV.leftAnchor, padding)
        descrLabel.right(containerV.rightAnchor, -padding)
        descrLabel.height(20)
        
        stackView.top(descrLabel.bottomAnchor, padding)
        stackView.centerX(containerV.centerXAnchor)
        stackView.widthForLayout(containerV.widthAnchor, -32)
        stackView.bottom(continueBtn.topAnchor, -padding)
        
        continueBtn.bottom(signingLabel.topAnchor, -padding)
        continueBtn.left(containerV.leftAnchor, 16)
        continueBtn.right(containerV.rightAnchor, -16)
        continueBtn.height(50)
        
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

