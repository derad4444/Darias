import SwiftUI
import UIKit

// MARK: - Live2D Placeholder View (Metal Toolchain不要)
struct Live2DPlaceholderView: UIViewRepresentable {
    let modelName: String
    @Binding var isAnimationPlaying: Bool
    
    init(modelName: String, isAnimationPlaying: Binding<Bool> = .constant(true)) {
        self.modelName = modelName
        self._isAnimationPlaying = isAnimationPlaying
    }
    
    func makeUIView(context: Context) -> Live2DSimpleView {
        let view = Live2DSimpleView()
        view.modelName = modelName
        view.delegate = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: Live2DSimpleView, context: Context) {
        uiView.isAnimationPlaying = isAnimationPlaying
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: Live2DPlaceholderView
        
        init(_ parent: Live2DPlaceholderView) {
            self.parent = parent
        }
    }
}

// MARK: - Simple Live2D View (UIView based)
class Live2DSimpleView: UIView {
    var modelName: String = "" {
        didSet {
            updateDisplay()
        }
    }
    
    var isAnimationPlaying: Bool = true {
        didSet {
            updateAnimationState()
        }
    }
    
    weak var delegate: AnyObject?
    
    private var characterImageView: UIImageView!
    private var statusLabel: UILabel!
    private var animationTimer: Timer?
    private var currentFrame: Int = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = UIColor.systemGray6
        layer.cornerRadius = 12
        layer.borderWidth = 2
        layer.borderColor = UIColor.systemBlue.cgColor
        
        // キャラクター画像ビュー
        characterImageView = UIImageView()
        characterImageView.contentMode = .scaleAspectFit
        characterImageView.backgroundColor = UIColor.clear
        characterImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(characterImageView)
        
        // ステータスラベル
        statusLabel = UILabel()
        statusLabel.text = "Live2D Character\n(Placeholder Mode)"
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = UIColor.systemBlue
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusLabel)
        
        // Auto Layout
        NSLayoutConstraint.activate([
            characterImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            characterImageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20),
            characterImageView.widthAnchor.constraint(equalToConstant: 100),
            characterImageView.heightAnchor.constraint(equalToConstant: 100),
            
            statusLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: characterImageView.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16)
        ])
        
        updateDisplay()
    }
    
    private func updateDisplay() {
        // キャラクターアイコンの設定
        let iconName: String
        if modelName.contains("female") {
            iconName = "person.crop.circle.fill"
        } else if modelName.contains("male") {
            iconName = "person.crop.square.fill"
        } else {
            iconName = "person.circle.fill"
        }
        
        let iconColor: UIColor
        if modelName.contains("female") {
            iconColor = UIColor.systemPink
        } else if modelName.contains("male") {
            iconColor = UIColor.systemBlue
        } else {
            iconColor = UIColor.systemPurple
        }
        
        characterImageView.image = UIImage(systemName: iconName)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 60, weight: .light))
            .withTintColor(iconColor, renderingMode: .alwaysOriginal)
        
        statusLabel.text = "Live2D Character\n(\(modelName.isEmpty ? "Default" : modelName))\nPlaceholder Mode"
    }
    
    private func updateAnimationState() {
        if isAnimationPlaying {
            startAnimation()
        } else {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        guard animationTimer == nil else { return }
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.animateFrame()
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func animateFrame() {
        currentFrame += 1
        
        // 簡単なパルスアニメーション
        UIView.animate(withDuration: 0.3, delay: 0, options: [.autoreverse], animations: {
            self.characterImageView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }) { _ in
            self.characterImageView.transform = CGAffineTransform.identity
        }
        
        // 色の変化（キャラクターに応じて）
        let colors: [UIColor]
        if modelName.contains("female") {
            colors = [.systemPink, .systemRed, .systemOrange, .systemYellow]
        } else if modelName.contains("male") {
            colors = [.systemBlue, .systemTeal, .systemCyan, .systemIndigo]
        } else {
            colors = [.systemBlue, .systemGreen, .systemOrange, .systemPurple]
        }
        let color = colors[currentFrame % colors.count]
        
        UIView.animate(withDuration: 0.3) {
            self.layer.borderColor = color.cgColor
            self.characterImageView.image = self.characterImageView.image?
                .withTintColor(color, renderingMode: .alwaysOriginal)
        }
    }
    
    // タッチイベントの処理
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        // タッチエフェクト
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = CGAffineTransform.identity
            }
        }
        
        // Live2Dイベントをシミュレート
        if let touch = touches.first {
            let location = touch.location(in: self)
            simulateLive2DTouch(at: location)
        }
    }
    
    private func simulateLive2DTouch(at point: CGPoint) {
        // タッチ位置に応じたリアクションをシミュレート
        let relativeX = Float(point.x / bounds.width)
        let relativeY = Float(point.y / bounds.height)
        
        print("Live2D Touch Simulated - X: \(relativeX), Y: \(relativeY)")
        
        // タッチエフェクトの表示
        let effectView = UIView(frame: CGRect(x: point.x - 15, y: point.y - 15, width: 30, height: 30))
        effectView.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.7)
        effectView.layer.cornerRadius = 15
        addSubview(effectView)
        
        UIView.animate(withDuration: 0.5, animations: {
            effectView.transform = CGAffineTransform(scaleX: 2.0, y: 2.0)
            effectView.alpha = 0
        }) { _ in
            effectView.removeFromSuperview()
        }
    }
    
    deinit {
        animationTimer?.invalidate()
    }
}

// MARK: - Preview
struct Live2DPlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        Live2DPlaceholderView(
            modelName: "character_female",
            isAnimationPlaying: .constant(true)
        )
        .frame(width: 300, height: 400)
        .background(Color.gray.opacity(0.1))
    }
}