//
//  SignUpViewModel.swift
//  konnex-ios
//
//  Created by Shavkat Khoshimov on 11/07/22.
//  Copyright © 2022 Achilov Bakhrom. All rights reserved.
//

import Combine
import UIKit

class SignUpViewModel: BaseViewModelProtocol {
    
    var viewModelEvent = CurrentValueSubject<ViewModelStatus, Never>(.hideLoading)
    var cancellables = Set<AnyCancellable>()
    
    private(set) var errorMessagePub = PassthroughSubject<String, Never>()
    private(set) var openConfirmationVC = PassthroughSubject<Void, Never>()
    
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var phone = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    
    
    var isValidFirstNamePub: AnyPublisher<Bool, Never> {
        $firstName
            .map { !$0.isBlank }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    var isValidLastNamePub: AnyPublisher<Bool, Never> {
        $lastName
            .map { !$0.isBlank }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    var isValidEmailPub: AnyPublisher<Bool, Never> {
        $email
            .map { $0.isValidEmail() }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    var isValidPhonePub: AnyPublisher<Bool, Never> {
        $phone
            .map { !$0.isBlank && $0.count > 5 }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    var isValidPasswordPub: AnyPublisher<Bool, Never> {
        $password
            .map { $0.count > 5 }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    var isValidConfirmPasswordPub: AnyPublisher<Bool, Never> {
        $confirmPassword
            .map { $0.count > 5 }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    var isPasswordMatchesPub: AnyPublisher<Bool, Never> {
        return Publishers.CombineLatest($password, $confirmPassword)
            .map { (!$0.0.description.isBlank == !$0.1.description.isBlank && $0.0 == $0.1) }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
        
    
    var isSubmitEnabled: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest4(isValidFirstNamePub, isValidLastNamePub, isValidEmailPub, isValidPhonePub)
        .receive(on: DispatchQueue.main)
        .map { ($0.0 && $0.1 && $0.2 && $0.3) }
        .eraseToAnyPublisher()
    }
    
    
    func signup(newUser: SignUpUser) {
        self.viewModelEvent.send(.showLoading)
        ApiManager.shared.signUp(signUp: newUser)
            .compactMap({$0})
            .sink { completion in
                switch completion {
                    case .finished: break
                    case .failure(let error):
                        self.viewModelEvent.send(.hideLoading)
                        self.errorMessagePub.send(error.desc)
                        break
                }
            } receiveValue: { [weak self] (user) in
                guard let self = self else { return }
                self.viewModelEvent.send(.hideLoading)
                // errorMsg "username_exist" kelganida, bu user allaqachon systemada bor hisoblanadi
                if user.errorMsg == "username_exist" {
                    self.errorMessagePub.send("User already exists.")
                }
                // errorMsg "username_exist_not_register" kelganida, bu user allaqachon systemada bor lekin
                // confirmation qilmagan shuning uchun hozirda yozgan yangi datalari bilan confirmationga yuboriladi
                else if user.errorMsg == "username_exist_not_register" {
                    ApiManager.shared.reRegisterIndividual(signUp: newUser)
                        .sink { completion in
                            switch completion {
                                case .finished: break
                                case .failure(let error):
                                    self.viewModelEvent.send(.hideLoading)
                                    self.errorMessagePub.send(error.desc)
                                    break
                            }
                        } receiveValue: { [weak self] user in
                            self?.viewModelEvent.send(.hideLoading)
                            self?.openConfirmationVC.send()
                        }.store(in: &self.cancellables)
                } else {
                    self.viewModelEvent.send(.hideLoading)
                    self.openConfirmationVC.send()
                }
            }.store(in: &cancellables)
    }
}
