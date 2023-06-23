import UIKit
import AudioToolbox
import StoreKit
import Combine


class SwitchCompanyVC: BaseViewController {
    
    var cancellables = Set<AnyCancellable>()
    var viewModel: SwitchCompanyViewModel!
    
    init(viewModel: SwitchCompanyViewModel, isFromSignIn: Bool = false) {
        super.init(nibName: nil, bundle: nil)
        self.isFromSignIn = isFromSignIn
        self.viewModel = viewModel
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func bindViewModel() {
        viewModel.viewModelEvent
            .sink { [weak self] (value) in
                self?.handleViewModelEvent(state: value)
            }
            .store(in: &cancellables)
        
        viewModel.errorMessagePub
            .sink { [weak self] (value) in
                self?.showSnackBar(text: value)
            }
            .store(in: &cancellables)
        
        viewModel.openMainVCPub
            .sink { [weak self] (_) in
                self?.openMainVC()
            }
            .store(in: &cancellables)
        
        viewModel.showEmptyViewPub
            .sink { [weak self] (value) in
                guard let self = self else { return }
                switch self.pageType {
                    case .normal:
                        self.emptyView.itemTitle.text = "You don't have any connected businesses"
                    case .search:
                        self.emptyView.itemTitle.text = "No Result"
                }
                self.emptyMode(isEmpty: value)
            }
            .store(in: &cancellables)
        
        viewModel.$userBusinessList.assign(to: \.currentDataSource, on: self)
            .store(in: &cancellables)
    }
    
    
    var currentDataSource = [UserBusiness]() {
        didSet {
            // selected business buyicha sort qilinadi
            for (index, business) in currentDataSource.enumerated() {
                if business.company.id == SELECTED_BUSINESS_ID {
                    let element = currentDataSource.remove(at: index)
                    currentDataSource.insert(element, at: 0)
                    break
                }
            }
            // pinned higher priority
            // pinned business buyicha sort qilinadi
            currentDataSource.sort { $0.company.isPinned && !$1.company.isPinned }
            
            tableView.reloadData()
        }
    }
        
    let containerV = UIView()
    var isFromSignIn = false
    var isEmployee = false
    
    
    lazy var searchBar: UISearchBar = {
       let bar = UISearchBar()
        bar.delegate = self
        bar.placeholder = "Search business by name.."
        bar.backgroundColor = UIColor.white
        bar.returnKeyType = .done
        bar.sizeToFit()
        return bar
    }()
    
    lazy var tableView: UITableView = {
        var tblV = UITableView()
        tblV.register(CompanyCell.self, forCellReuseIdentifier: "CompanyCell")
        tblV.rowHeight = 65
        tblV.delegate = self
        tblV.dataSource = self
        tblV.backgroundColor = .clear
        tblV.separatorStyle = .singleLine
        tblV.separatorInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        tblV.refreshControl = UIRefreshControl()
        tblV.keyboardDismissMode = .onDrag
        tblV.refreshControl?.addTarget(self, action: #selector(refreshList), for: .valueChanged)
        return tblV
    }()
    
    
    lazy var emptyView: EmptyView = {
        let view = EmptyView(with: "You don't have any connected businesses")
        view.isHidden = true
        return view
    }()


    lazy var supportButton: UIButton = {
        var button = UIButton()
        button.setImage(UIImage(named: "businessSupport"), for: .normal)
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.layer.borderWidth = 0.1
        button.layer.cornerRadius = 55/2
        button.backgroundColor = UIColor.color_1()
        button.layer.masksToBounds = true
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(supportBtnTapped), for: .touchUpInside)
        return button
    }()
    
    
    lazy var createVCButton: UIButton = {
        var button = UIButton()
        button.addTarget(self, action: #selector(createBusinessBtnAction), for: .touchUpInside)
        button.setImage(UIImage(named: "add")?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        button.backgroundColor = UIColor.color_1()
        button.tintColor = UIColor.cardColor()
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.layer.borderWidth = 0.5
        button.layer.cornerRadius = 28
        button.layer.masksToBounds = true
        button.clipsToBounds = true
        return button
    }()
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isFromSignIn {
            navigationController?.setNavigationBarHidden(false, animated: true)
            navigationItem.leftBarButtonItem = self.backBarBtn
        }
        self.tabBarController?.tabBar.isHidden = true
        self.viewModel.getBusinessList()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupConstrinsts()
        self.bindViewModel()
        self.setupLongPress()
        self.viewModel.viewDidLoad()
        self.hideKeyboardWhenTappedAround()
        NotificationCenter.Publisher(center: .default, name: .refresh_business_list).sink { [weak self] _ in
            self?.viewModel.getBusinessList()
        }.store(in: &cancellables)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        checkUnreadMessage(businessList: currentDataSource.map({$0.company}))
    }
    
    override func backBarBtnAction() {
        self.openMainVC()
    }
    
    
    @objc func refreshList() {
        self.viewModel.getBusinessList()
        
        DispatchQueue.main.async {
            self.tableView.refreshControl?.endRefreshing()
        }
    }
    
    
    func openMainVC() {
        if isFromSignIn {
            if let window = UIApplication.shared.delegate?.window {
                if globalMainVC == nil {
                    globalMainVC = MainVC()
                }
                globalMainVC?.openingMode = .cases
                window?.rootViewController = globalMainVC
                window?.makeKeyAndVisible()
            }
            isFromSignIn = false
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    
    func emptyMode(isEmpty: Bool) {
        emptyView.isHidden = !isEmpty
        tableView.isHidden = isEmpty
    }
    
        
    @objc func createBusinessBtnAction() {
        let vc = CreateBusinessViewController(viewModel: CreateBusinessViewModel())
        vc.isFromSwitchBusiness = true
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func shareBusiness(company: Company, bindedView: UIView) {
        guard let cName = company.name, let companyID = company.id else{
            self.showSnackBar(text: "The business name is not correct. Please contact to support center.")
            return
        }
        let txtToShare = "Using KENNEKT will make your life easier. \n\nCheck out this Business! I highly recommend KENNEKT'ING to them. \(cName.uppercased()) \n\nFirst: Download KENNEKT https://itunes.apple.com/us/app/kennekt-client-messenger/id1397313589?mt=8 \n\nSecond: KENNKET to \(cName.uppercased()) http://www.kennekt.com/business?\(cName.replacingOccurrences(of:" ", with: "_"))/\(companyID)"
        //, \(company.address ?? company.address2) , \(company.phone)"
        let vc = UIActivityViewController.init(activityItems: [txtToShare], applicationActivities: nil)
        vc.excludedActivityTypes = [.addToReadingList, .airDrop, .copyToPasteboard, .mail, .message, .postToFlickr, .postToFacebook, .postToVimeo, .postToTwitter, .postToWeibo, .postToTencentWeibo]
        vc.popoverPresentationController?.sourceView = bindedView
        vc.popoverPresentationController?.sourceRect = bindedView.frame
        self.present(vc, animated: true, completion: nil)
    }
       
    
    @objc func supportBtnTapped() {
        let appURLScheme = "client://"
        guard let appURL = URL(string: appURLScheme) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(appURL) {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(appURL)
            } else {
                UIApplication.shared.openURL(appURL)
            }
        } else {
            let appId = "1397313589"
            let vc = SKStoreProductViewController()
            vc.loadProduct(withParameters: [SKStoreProductParameterITunesItemIdentifier: appId], completionBlock: nil)
            present(vc, animated: true, completion: nil)
        }
    }
    
    
    func setupLongPress() {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPress))
        longPressGesture.minimumPressDuration = 1.0 // 1 second press
        longPressGesture.delegate = self
        longPressGesture.cancelsTouchesInView = true
        self.tableView.addGestureRecognizer(longPressGesture)
    }
    
    
    @objc func longPress(longPressGestureRecognizer: UILongPressGestureRecognizer) {
        if longPressGestureRecognizer.state == UIGestureRecognizerState.began {
            let touchPoint = longPressGestureRecognizer.location(in: self.tableView)
            if let indexPath = tableView.indexPathForRow(at: touchPoint) {
                self.tableView.reloadRows(at: [indexPath], with: .none)
                let userBusiness = currentDataSource[indexPath.row]
                guard let businessTitle = userBusiness.company.name, userBusiness.company.id != SELECTED_BUSINESS_ID else { return }
                let alertController = UIAlertController(title: "Are you sure to disconnect from \(businessTitle) ?", message: "", preferredStyle: .alert)
                let disconnect = UIAlertAction(title: "Disconnect", style: .default) { [weak self] action in
                    guard let self = self else { return }
                    self.viewModel.disconnect(fromBusiness: self.currentDataSource[indexPath.row])
                }
                alertController.addAction(disconnect)
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                alertController.addAction(cancelAction)
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
        
    enum PageType {
        case normal, search
    }
    
    var pageType: SwitchCompanyVC.PageType = .normal
}

// MARK: UITableViewDelegate, UITableViewDataSource
extension SwitchCompanyVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentDataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: CompanyCell = tableView.dequeueReusableCell(for: indexPath)
        let item = currentDataSource[indexPath.row]
        
        cell.updateCell(info: item.company)
        cell.selectionStyle = .none
        cell.isUserInteractionEnabled = item.company?.status != "INACTIVE"
        cell.baseDelegate = self
        
        // pin/unpin action
        cell.pinUnpinPublisher.sink { (businessID, forDelete) in
            self.viewModel.pinUnpinBy(businessID: businessID, forDelete: forDelete)
        }.store(in: &self.cancellables)
        
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let selectedCompany = currentDataSource[indexPath.row].company, selectedCompany.id != SELECTED_BUSINESS_ID {
            self.viewModel.selectCompany(with: selectedCompany)
        } else {
            self.navigationController?.popToRootViewController(animated: true)
        }
    }
}


extension SwitchCompanyVC: UISearchBarDelegate, UITextViewDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        pageType = .search
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        pageType = .normal
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.viewModel.searchByKeyword(keyword: searchBar.text ?? "")
    }
}



extension SwitchCompanyVC: BaseTableViewCellDelegate {
    func baseTableCellDidAction(cell: BaseTableViewCell, action: String?, value: AnyObject?) {
        if let company = value as? Company, let action = action {
            switch action {
            case "share":
                    let alertController = UIAlertController(title: "Do you want to share your company \(company.name ?? "")?", message: "", preferredStyle: .alert)
                    let share = UIAlertAction(title: "Share business", style: .default) { action in
                        self.shareBusiness(company: company, bindedView: self.view)
                    }
                    alertController.addAction(share)
                    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                    alertController.addAction(cancelAction)
                    self.present(alertController, animated: true, completion: nil)
            case "info":
                    let selectedCompanyVC = PagerManagerController(pageType: .selectedCompany, pages: [CompanyInfoVC(company: company),
                                                                                                       CallUsVC(company: company, viewModel: CallUsViewModel()),
                                                                                                       LocationsVC(company: company, viewModel: LocationsViewModel())])
                    let vc = selectedCompanyVC
                    self.navigationController?.pushViewController(vc, animated: true)
                break
            default:
                break
            }
        }
    }
}


// MARK: Constranits
extension SwitchCompanyVC {
    
    fileprivate func setupConstrinsts() {
        self.view.backgroundColor = UIColor.lightGrayBackgroundColor()
        self.view.addSubview(containerV)
        containerV.translatesAutoresizingMaskIntoConstraints = false
        containerV.pinToEdges(parentView: self.view)
        
        konnex_ios.addSubviews(parentView: containerV, views: [emptyView, searchBar, tableView, supportButton, createVCButton])
        
        emptyView.centerX(containerV.centerXAnchor)
        emptyView.centerY(containerV.centerYAnchor)
        
        searchBar.top(view.topAnchor)
        searchBar.left(view.leftAnchor)
        searchBar.right(view.rightAnchor)
        
        tableView.top(searchBar.bottomAnchor)
        tableView.left(view.leftAnchor)
        tableView.right(view.rightAnchor)
        tableView.bottom(view.bottomAnchor, -5)
        
        supportButton.right(containerV.rightAnchor, -20)
        supportButton.bottom(view.bottomAnchor, -20)
        supportButton.height(55)
        supportButton.width(55)
        
        createVCButton.left(containerV.leftAnchor, 20)
        createVCButton.bottom(view.bottomAnchor, -20)
        createVCButton.height(55)
        createVCButton.width(55)
    }
}
