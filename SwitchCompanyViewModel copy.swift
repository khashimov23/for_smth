//
//  SwitchCompanyViewModel.swift
//  konnex-ios
//
//  Created by Shavkat Khoshimov on 25/10/22.
//  Copyright © 2022 Achilov Bakhrom. All rights reserved.
//

import Foundation
import Combine

class SwitchCompanyViewModel: BaseViewModelProtocol {
    
    var viewModelEvent = CurrentValueSubject<ViewModelStatus, Never>(.hideLoading)
    var cancellables = Set<AnyCancellable>()
    
    private(set) var errorMessagePub = PassthroughSubject<String, Never>()
    private(set) var showSpinnerPub = PassthroughSubject<Bool, Never>()
    private(set) var openMainVCPub = PassthroughSubject<Void, Never>()
    private(set) var showEmptyViewPub = PassthroughSubject<Bool, Never>()
    
    
    func viewDidLoad() {
        let businesses = DBManagement.shared.queryAllFromBusiness()
        self.totalBusinessList = businesses.filter({$0.company.is_individual == false})
        self.updateUI(list: &totalBusinessList)
        if !isOffLineMode {
            self.getBusinessList()
        }
    }
    
    
    @Published var userBusinessList = [UserBusiness]()
    
    func getBusinessList() {
        if userBusinessList.isEmpty {
            self.viewModelEvent.send(.showLoading)
        }
        ApiManager.shared.getCurrentUserCompanies()
            .receive(on: DispatchQueue.main)
            .compactMap({$0})
            .sink { completion in
                switch completion {
                    case .finished: break
                    case .failure(let error):
                        self.errorMessagePub.send(error.desc)
                        self.viewModelEvent.send(.hideLoading)
                }
            } receiveValue: { [weak self] resp in
                self?.viewModelEvent.send(.hideLoading)
                guard let self = self else { return }
                if let result = resp.results {
                    self.addBusinessList(userCompanies: result)
                    self.totalBusinessList = result.filter({$0.company.is_individual == false})
                    self.updateUI(list: &self.totalBusinessList)
                }
            }
            .store(in: &cancellables)
    }
    
    
    private func updateUI(list: inout [UserBusiness]) {
        self.showEmptyViewPub.send(list.isEmpty ? true : false)
        userBusinessList = list
    }
    
    
    func selectCompany(with selectedCompany: Company) {
        determineAndSetActiveBusinessCompany(selectedCompanyId: selectedCompany.id, userCompanyList: userBusinessList)
        NotificationCenter.default.post(name: .business_changed, object: nil)
        
        if let isAvailable = selectedCompany.compSubscription?.isAvailable, !isAvailable {
            selectBusiness(with: selectedCompany.id) { [weak self] in
                guard let self = self else { return }
                getProfile { [weak self] currentUser in
                    guard let _ = self else { return }
                    goToPaymentExpiredVC(currentUser: currentUser)
                }
            }
        } else {
            selectBusiness(with: selectedCompany.id, completion: {})
            self.openMainVCPub.send()
        }
    }
    
    
    var searchedBusinessList = [UserBusiness]()
    var totalBusinessList = [UserBusiness]()
    
    func searchByKeyword(keyword: String) {
        if keyword.isEmpty || keyword == "" {
            searchedBusinessList = totalBusinessList
        } else {
            searchedBusinessList = totalBusinessList.filter ({
                ($0.company.name ?? "").lowercased().contains(keyword.lowercased())
            })
        }
        self.updateUI(list: &searchedBusinessList)
    }
    
    
    func disconnect(fromBusiness userBusiness: UserBusiness) {
        self.viewModelEvent.send(.showLoading)
        ApiManager.shared.disconnectFromBusiness(userBusinessId: userBusiness.id, businessId: userBusiness.company.id)
            .receive(on: DispatchQueue.main)
            .compactMap({$0})
            .sink { [weak self] (completion) in
                switch completion {
                    case .finished: break
                    case .failure(let error):
                        self?.errorMessagePub.send(error.desc)
                        self?.viewModelEvent.send(.hideLoading)
                }
            } receiveValue: { [weak self] _ in
                self?.viewModelEvent.send(.hideLoading)
                guard let self = self else { return }
                for (index, business) in (self.totalBusinessList.enumerated()) {
                    if business.id == userBusiness.id {
                        self.totalBusinessList.remove(at: index)
                        self.updateUI(list: &self.totalBusinessList)
                        break
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    
    func pinUnpinBy(businessID: Int, forDelete: Bool = false) {
        for (cindex, userBusinessItem) in userBusinessList.enumerated() {
            if userBusinessItem.company.id == businessID {
                self.viewModelEvent.send(.showLoading)
                ApiManager.shared.pinUnpinCompaniesBy(userBusinessID: userBusinessItem.id, businessID: businessID, forDelete: forDelete)
                    .receive(on: DispatchQueue.main)
                    .compactMap({$0})
                    .sink { [weak self] (completion) in
                        switch completion {
                            case .finished: break
                            case .failure(let error):
                                self?.errorMessagePub.send(error.desc)
                                self?.viewModelEvent.send(.hideLoading)
                        }
                    } receiveValue: { [weak self] (status) in
                        self?.viewModelEvent.send(.hideLoading)
                        guard let self = self else { return }
                        if status.uppercased() == "OK" {
                            self.userBusinessList.remove(at: cindex)
                            userBusinessItem.company.isPinned = forDelete ? false : true
                            self.userBusinessList.insert(userBusinessItem, at: cindex)
                            self.updateUI(list: &self.userBusinessList)
                        }
                    }
                    .store(in: &cancellables)
                break
            }
        }
    }
}
 

extension SwitchCompanyViewModel {
    fileprivate func addBusinessList(userCompanies: [UserBusiness]) {
        if DBManagement.shared.deleteAllBusiness() {
            userCompanies.forEach { userBusiness in
                _ = DBManagement.shared.addBusiness(givenId: userBusiness.company.id, givenFullObj: userBusiness.toJSONString() ?? "")
            }
        }
    }
    
    
    func selectBusiness(with id: Int, completion: @escaping () -> Void) {
        ApiManager.shared.selectBusiness(with: id)
        .sink { resp in
            if resp.status?.uppercased() == "OK" {
                completion()
            }
        }.store(in: &cancellables)
    }
                   
    func getProfile(completion: @escaping (KNXUser) -> Void) {
        ApiManager.shared.getProfile()
            .compactMap({$0})
            .sink { [weak self] competion in
                switch competion {
                    case .finished: break
                    case .failure(let error):
                        self?.errorMessagePub.send(error.desc)
                        break
                }
            } receiveValue: { (userFullData) in
                completion(userFullData)
            }.store(in: &cancellables)
    }
}
