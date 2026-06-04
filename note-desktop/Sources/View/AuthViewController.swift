import AppKit

public final class AuthViewController: NSViewController, LoginPageDelegate, SignupPageDelegate {
    private let authService: AuthService
    private let loginPage: LoginPage
    private let signupPage: SignupPage
    
    private var activeViewController: NSViewController?
    
    public var onAuthSuccess: ((String) -> Void)?
    
    public init(authService: AuthService) {
        self.authService = authService
        self.loginPage = LoginPage(authService: authService)
        self.signupPage = SignupPage(authService: authService)
        super.init(nibName: nil, bundle: nil)
        
        loginPage.delegate = self
        signupPage.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 400))
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        switchToViewController(loginPage)
    }
    
    private func switchToViewController(_ target: NSViewController) {
        if let current = activeViewController {
            addChild(target)
            
            target.view.frame = view.bounds
            target.view.autoresizingMask = [.width, .height]
            
            transition(from: current, to: target, options: .crossfade) { [weak self] in
                current.removeFromParent()
                self?.activeViewController = target
            }
        } else {
            addChild(target)
            target.view.frame = view.bounds
            target.view.autoresizingMask = [.width, .height]
            view.addSubview(target.view)
            activeViewController = target
        }
    }
    
    // MARK: - LoginPageDelegate
    public func loginPage(_ page: LoginPage, didLoginWithUser user: AuthUser) {
        onAuthSuccess?(user.id)
    }
    
    public func loginPageDidTapSwitchToSignup(_ page: LoginPage) {
        switchToViewController(signupPage)
    }
    
    // MARK: - SignupPageDelegate
    public func signupPage(_ page: SignupPage, didSignupWithUser user: AuthUser) {
        onAuthSuccess?(user.id)
    }
    
    public func signupPageDidTapSwitchToLogin(_ page: SignupPage) {
        switchToViewController(loginPage)
    }
}
