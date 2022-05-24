//
//  VideoDownloadViewController.swift
//  OverPlay
//
//  Created by Luke Van In on 2022/05/24.
//

import UIKit
import OSLog
import Combine


private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "download-ui")


final class VideoDownloadViewController: UIViewController {
    
    private var loadingCancellable: AnyCancellable?
    
    private let loadingActivityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.style = .large
        view.tintColor = .white
        view.hidesWhenStopped = true
        view.stopAnimating()
        return view
    }()
    
    private let errorIconImageView: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let downloadController: DownloadController
    
    init(downloadController: DownloadController) {
        self.downloadController = downloadController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        let layoutStack: UIStackView = {
            let view = UIStackView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.axis = .vertical
            view.alignment = .center
            view.spacing = 16
            view.addArrangedSubview(loadingActivityIndicator)
            view.addArrangedSubview(errorIconImageView)
            return view
        }()
        
        view.backgroundColor = .black
        view.tintColor = .white
        view.addSubview(layoutStack)

        NSLayoutConstraint.activate([
            
            errorIconImageView.widthAnchor.constraint(equalToConstant: 64),
            errorIconImageView.heightAnchor.constraint(equalToConstant: 64),
            
            layoutStack.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: +32),
            layoutStack.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -32),
            layoutStack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadingCancellable = downloadController.statePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self = self else {
                    return
                }
                self.invalidateState(state: state)
            }
        downloadController.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        loadingCancellable?.cancel()
        loadingCancellable = nil
    }
    
    private func invalidateState(state: DownloadState) {
        let loadingIndicatorHidden: Bool
        let errorIconHidden: Bool
        
        switch state {
        
        case .pending:
            loadingIndicatorHidden = false
            errorIconHidden = true
        
        case .downloading:
            loadingIndicatorHidden = false
            errorIconHidden = true
            
        case .completed(let url):
            loadingIndicatorHidden = true
            errorIconHidden = true
            createVideoPlayer(url: url)
            
        case .failed(let error):
            loadingIndicatorHidden = true
            errorIconHidden = false
        }
        
        if loadingActivityIndicator.isHidden != loadingIndicatorHidden {
            if loadingIndicatorHidden == true {
                loadingActivityIndicator.stopAnimating()
            }
            else {
                loadingActivityIndicator.startAnimating()
            }
        }
        
        errorIconImageView.isHidden = errorIconHidden
    }
    
    private func createVideoPlayer(url: URL) {
        do {
            // TODO: Use coordinator to instantiate and present view controller
            let builder = VideoViewControllerBuilder().with(url: url)
            let viewController = try builder.build()
            viewController.willMove(toParent: self)
            addChild(viewController)
            viewController.view.frame = view.bounds
            view.addSubview(viewController.view)
            viewController.didMove(toParent: self)
        }
        catch {
            logger.error("Cannot instantiate video view controller \(error.localizedDescription)")
        }
    }
}
