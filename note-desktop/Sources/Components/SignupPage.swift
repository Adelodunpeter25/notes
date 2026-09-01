import AppKit

@MainActor
public protocol SignupPageDelegate: AnyObject {
    func signupPage(_ page: SignupPage, didSignupWithUser user: AuthUser)
    func signupPageDidTapSwitchToLogin(_ page: SignupPage)
}

public final class SignupPage: NSViewController {
    public weak var delegate: SignupPageDelegate?
    private let authService: AuthService
    
    // UI Elements
    private let containerBox = NSBox()
    private let titleLabel = NSTextField(labelWithString: "Create Account")
    private let usernameField = NSTextField()
    private let emailField = NSTextField()
    private let passwordField = NSSecureTextField()
    private let signupButton = NSButton()
    private let switchButton = NSButton()
    private let errorLabel = NSTextField(labelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    
    public init(authService: AuthService) {
        self.authService = authService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 400))
        setupUI()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // 1. Card Container (Sleek Box)
        containerBox.boxType = .custom
        containerBox.cornerRadius = 12
        containerBox.borderWidth = 1
        containerBox.borderColor = NSColor.separatorColor
        containerBox.fillColor = NSColor.controlBackgroundColor
        containerBox.wantsLayer = true
        
        view.addSubview(containerBox)
        containerBox.translatesAutoresizingMaskIntoConstraints = false
        
        // 2. Title Header
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        
        // 3. Fields
        usernameField.placeholderString = "Username"
        usernameField.font = NSFont.systemFont(ofSize: 13)
        usernameField.bezelStyle = .roundedBezel
        
        emailField.placeholderString = "Email"
        emailField.font = NSFont.systemFont(ofSize: 13)
        emailField.bezelStyle = .roundedBezel
        
        passwordField.placeholderString = "Password"
        passwordField.font = NSFont.systemFont(ofSize: 13)
        passwordField.bezelStyle = .roundedBezel
        
        // 4. Error label (Curated soft-red color)
        errorLabel.font = NSFont.systemFont(ofSize: 12)
        errorLabel.textColor = NSColor.systemRed
        errorLabel.alignment = .center
        errorLabel.cell?.wraps = true
        errorLabel.cell?.isScrollable = false
        
        // 5. Buttons
        signupButton.title = "Sign Up"
        signupButton.bezelStyle = .rounded
        signupButton.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        signupButton.target = self
        signupButton.action = #selector(signupTapped)
        signupButton.keyEquivalent = "\r" // Enter key submits
        
        switchButton.title = "Already have an account? Log In"
        switchButton.isBordered = false
        switchButton.font = NSFont.systemFont(ofSize: 12)
        switchButton.contentTintColor = AppColors.accent
        switchButton.target = self
        switchButton.action = #selector(switchToLogin)
        
        // 6. Spinner
        progressIndicator.style = .spinning
        progressIndicator.isIndeterminate = true
        progressIndicator.controlSize = .small
        progressIndicator.isHidden = true
        
        // Layout Inside Card Container
        let formStack = NSStackView(views: [
            titleLabel,
            usernameField,
            emailField,
            passwordField,
            errorLabel,
            signupButton,
            switchButton,
            progressIndicator
        ])
        formStack.orientation = .vertical
        formStack.spacing = 12
        formStack.alignment = .centerX
        
        containerBox.addSubview(formStack)
        formStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Center the card inside parent view
            containerBox.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerBox.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerBox.widthAnchor.constraint(equalToConstant: 320),
            containerBox.heightAnchor.constraint(equalToConstant: 340),
            
            // Layout stack view inside card
            formStack.leadingAnchor.constraint(equalTo: containerBox.leadingAnchor, constant: 24),
            formStack.trailingAnchor.constraint(equalTo: containerBox.trailingAnchor, constant: -24),
            formStack.centerYAnchor.constraint(equalTo: containerBox.centerYAnchor),
            
            usernameField.widthAnchor.constraint(equalTo: formStack.widthAnchor),
            emailField.widthAnchor.constraint(equalTo: formStack.widthAnchor),
            passwordField.widthAnchor.constraint(equalTo: formStack.widthAnchor),
            signupButton.widthAnchor.constraint(equalTo: formStack.widthAnchor),
            errorLabel.widthAnchor.constraint(equalTo: formStack.widthAnchor)
        ])
    }
    
    @objc private func signupTapped() {
        let username = usernameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = emailField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordField.stringValue
        
        guard !username.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorLabel.stringValue = "Please fill in all fields."
            return
        }
        
        setLoading(true)
        errorLabel.stringValue = ""
        
        authService.registerUser(username: username, email: email, password: Array(password)) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.setLoading(false)
                switch result {
                case .success(let response):
                    self.delegate?.signupPage(self, didSignupWithUser: response.user)
                case .failure(let error):
                    self.errorLabel.stringValue = error.localizedDescription
                }
            }
        }
    }
    
    @objc private func switchToLogin() {
        delegate?.signupPageDidTapSwitchToLogin(self)
    }
    
    private func setLoading(_ isLoading: Bool) {
        usernameField.isEnabled = !isLoading
        emailField.isEnabled = !isLoading
        passwordField.isEnabled = !isLoading
        signupButton.isEnabled = !isLoading
        switchButton.isEnabled = !isLoading
        
        if isLoading {
            progressIndicator.isHidden = false
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.isHidden = true
            progressIndicator.stopAnimation(nil)
        }
    }
}
