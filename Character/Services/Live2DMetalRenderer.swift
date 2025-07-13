import UIKit
import Metal
import MetalKit
import simd

// MARK: - Live2D Metal View Delegate
protocol Live2DMetalViewDelegate: AnyObject {
    func live2DMetalView(_ view: Live2DMetalView, didUpdateFrame frameTime: TimeInterval)
    func live2DMetalView(_ view: Live2DMetalView, didTouchAt point: CGPoint)
}

// MARK: - Live2D Metal View
class Live2DMetalView: MTKView {
    // MARK: - Properties
    weak var live2DDelegate: Live2DMetalViewDelegate?
    var live2DManager: Live2DManager?
    private var _modelName: String = ""
    private var isLoadingModel: Bool = false
    
    var modelName: String {
        get { return _modelName }
        set {
            // 同じモデル名の場合は何もしない
            guard newValue != _modelName else { return }
            
            _modelName = newValue
            print("🔍 Live2DMetalView - modelName設定: \(newValue)")
            
            // モデル読み込みは別のメソッドで明示的に呼び出す
            if !newValue.isEmpty {
                loadModelInternal(modelName: newValue)
            }
        }
    }
    var isAnimationPlaying: Bool = true {
        didSet {
            isPaused = !isAnimationPlaying
        }
    }
    
    private var renderer: Live2DRenderer?
    private var commandQueue: MTLCommandQueue?
    private var lastTime: CFTimeInterval = 0.0
    
    // MARK: - Initialization
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        setupMetal()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        setupMetal()
    }
    
    private func setupMetal() {
        // Metal デバイスの設定を段階的に実行
        print("Metal デバイス初期化開始")
        
        DispatchQueue.main.async {
            guard let device = MTLCreateSystemDefaultDevice() else {
                print("Metal is not supported on this device")
                return
            }
            
            print("Metal デバイス作成成功")
            self.setupMetalDevice(device: device)
        }
    }
    
    private func setupMetalDevice(device: MTLDevice) {
        
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        
        // Metal view の設定
        setupMetalView()
        
        // レンダラーの初期化
        setupRenderer(device: device)
    }
    
    private func setupMetalView() {
        print("🔍 Live2DMetalView - setupMetalView開始")
        
        // Metal view の基本設定
        self.colorPixelFormat = .bgra8Unorm
        self.depthStencilPixelFormat = .depth32Float
        self.sampleCount = 1
        
        // デバッグ用: 背景を白にしてLive2Dコンテンツが見えるようにする
        self.clearColor = MTLClearColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        
        // 背景設定
        self.isOpaque = true
        self.backgroundColor = UIColor.white
        
        print("🔍 Live2DMetalView - 透明背景設定完了")
        
        // パフォーマンス最適化設定
        self.preferredFramesPerSecond = 30 // 60FPSから30FPSに削減
        self.enableSetNeedsDisplay = false
        self.isPaused = false // 🔴 デバッグ用: アニメーションを開始
        
        print("🔍 Live2DMetalView - setupMetalView完了")
        print("🔍 Live2DMetalView - isPaused: \(isPaused)")
        print("🔍 Live2DMetalView - preferredFramesPerSecond: \(preferredFramesPerSecond)")
    }
    
    private func setupRenderer(device: MTLDevice) {
        guard let commandQueue = self.commandQueue else {
            print("Failed to create command queue")
            return
        }
        
        // レンダラーの作成を非同期で実行
        DispatchQueue.global(qos: .utility).async {
            let newRenderer = Live2DRenderer(device: device, commandQueue: commandQueue)
            
            DispatchQueue.main.async {
                self.renderer = newRenderer
                self.delegate = newRenderer
                
                // Live2D Manager の作成と強制初期化
                if self.live2DManager == nil {
                    print("=== Live2DManager作成開始 ===")
                    self.live2DManager = Live2DManager()
                    print("=== Live2DManager作成完了 ===")
                }
                
                // Live2DManagerを強制的に初期化
                self.live2DManager?.initialize()
                
                newRenderer.live2DManager = self.live2DManager
                print("🔍 Live2DMetalView - Live2DManager設定完了")
                
                print("Live2D Metal Renderer initialized successfully")
            }
        }
    }
    
    // MARK: - Model Loading
    func loadModel(modelName: String) {
        print("🔍 Live2DMetalView - loadModel (外部呼び出し)開始: \(modelName)")
        
        // modelNameを設定（これにより内部的にloadModelInternalが呼ばれる）
        self.modelName = modelName
        
        print("🔍 Live2DMetalView - loadModel (外部呼び出し)完了")
    }
    
    private func loadModelInternal(modelName: String) {
        print("🔍 Live2DMetalView - loadModelInternal開始: \(modelName)")
        
        // 既に読み込み中の場合は何もしない
        guard !isLoadingModel else {
            print("🔍 Live2DMetalView - 既に読み込み中のためスキップ")
            return
        }
        
        isLoadingModel = true
        
        // モデル読み込みを非同期で実行（メインスレッドをブロックしない）
        DispatchQueue.global(qos: .utility).async {
            print("🔍 Live2DMetalView - バックグラウンドでモデル読み込み開始")
            
            // Live2DManagerのモデル読み込みを非同期で実行
            self.live2DManager?.loadModel(modelName: modelName)
            
            // レンダラーの設定もバックグラウンドで実行
            DispatchQueue.main.async {
                print("🔍 Live2DMetalView - レンダラー設定開始")
                self.renderer?.modelName = modelName
                print("🔍 Live2DMetalView - Loading Live2D model: \(modelName)")
                
                // モデル読み込み完了後にアニメーション開始
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🔍 Live2DMetalView - レンダリング開始")
                    self.startRendering()
                    self.isLoadingModel = false
                }
            }
        }
        
        print("🔍 Live2DMetalView - loadModelInternal完了")
    }
    
    // MARK: - Rendering Control
    func startRendering() {
        print("🔍 Live2DMetalView - startRendering開始")
        print("🔍 Live2DMetalView - isPaused変更前: \(isPaused)")
        
        isPaused = false
        
        print("🔍 Live2DMetalView - isPaused変更後: \(isPaused)")
        print("🔍 Live2DMetalView - startRendering完了")
    }
    
    func pauseRendering() {
        isPaused = true
    }
    
    func stopRendering() {
        isPaused = true
        renderer?.cleanup()
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        if let touch = touches.first {
            let location = touch.location(in: self)
            live2DDelegate?.live2DMetalView(self, didTouchAt: location)
        }
    }
}

// MARK: - Live2D Renderer
class Live2DRenderer: NSObject, MTKViewDelegate {
    // MARK: - Properties
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var texturePipelineState: MTLRenderPipelineState? // テクスチャ用パイプライン
    private var depthStencilState: MTLDepthStencilState?
    private var uniformBuffer: MTLBuffer?
    private var animationBuffer: MTLBuffer?
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    
    // Live2D関連
    var live2DManager: Live2DManager?
    var modelName: String?
    private var drawableSize: CGSize = CGSize(width: 1.0, height: 1.0)
    
    // レンダリング用の変数
    private var projectionMatrix = matrix_float4x4()
    private var modelViewMatrix = matrix_float4x4()
    private var time: Float = 0.0
    private var lastTime: CFTimeInterval = 0.0
    
    // MARK: - Initialization
    init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        super.init()
        setupRenderer()
    }
    
    private func setupRenderer() {
        // Create render pipeline state
        setupRenderPipeline()
        
        // Create depth stencil state
        setupDepthStencil()
        
        // Create buffers
        setupBuffers()
    }
    
    private func setupRenderPipeline() {
        // Create shader library from source code
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        struct Uniforms {
            float4x4 projectionMatrix;
            float4x4 modelViewMatrix;
        };

        vertex VertexOut simpleVertexShader(device float4* vertices [[buffer(0)]],
                                           constant Uniforms& uniforms [[buffer(1)]],
                                           uint vertexID [[vertex_id]]) {
            VertexOut out;
            
            // 頂点バッファから位置を取得
            float4 position = vertices[vertexID];
            
            // テクスチャ座標を計算
            float2 texCoords[4] = {
                float2(0.0, 1.0),  // 左下
                float2(1.0, 1.0),  // 右下
                float2(0.0, 0.0),  // 左上
                float2(1.0, 0.0)   // 右上
            };
            
            out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
            out.texCoord = texCoords[vertexID];
            
            return out;
        }

        vertex VertexOut textureVertexShader(device float4* vertices [[buffer(0)]],
                                           constant Uniforms& uniforms [[buffer(1)]],
                                           uint vertexID [[vertex_id]]) {
            VertexOut out;
            
            // 頂点バッファから位置を取得
            float4 position = vertices[vertexID];
            
            // テクスチャ座標を計算
            float2 texCoords[4] = {
                float2(0.0, 1.0),  // 左下
                float2(1.0, 1.0),  // 右下
                float2(0.0, 0.0),  // 左上
                float2(1.0, 0.0)   // 右上
            };
            
            out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
            out.texCoord = texCoords[vertexID];
            
            return out;
        }

        fragment float4 textureFragmentShader(VertexOut in [[stage_in]],
                                            texture2d<float> colorTexture [[texture(0)]]) {
            constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
            
            // Live2Dテクスチャをサンプリング
            float4 colorSample = colorTexture.sample(textureSampler, in.texCoord);
            
            return colorSample;
        }

        struct AnimationData {
            float time;
            float breathPhase;
            float blinkPhase;
            float padding;
        };

        fragment float4 simpleFragmentShader(VertexOut in [[stage_in]],
                                           constant AnimationData& animation [[buffer(2)]],
                                           texture2d<float> colorTexture [[texture(0)]]) {
            constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
            float2 uv = in.texCoord;
            
            // Live2Dテクスチャをサンプリング
            float4 colorSample = colorTexture.sample(textureSampler, uv);
            
            // テクスチャが読み込まれていない場合はピンク色を表示（デバッグ用）
            if (colorSample.a < 0.01) {
                return float4(1.0, 0.5, 0.8, 1.0); // ピンク色
            }
            
            // 呼吸アニメーション（明度調整）
            float breathIntensity = 0.95 + 0.05 * sin(animation.breathPhase);
            colorSample.rgb *= breathIntensity;
            
            return colorSample;
        }
        """
        
        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            print("✅ Live2DRenderer - Metalライブラリ作成成功")
            
            let descriptor = MTLRenderPipelineDescriptor()
            
            // 頂点シェーダーの取得
            guard let vertexFunction = library.makeFunction(name: "simpleVertexShader") else {
                print("❌ Live2DRenderer - 頂点シェーダーの取得に失敗")
                pipelineState = nil
                return
            }
            
            // フラグメントシェーダーの取得
            guard let fragmentFunction = library.makeFunction(name: "simpleFragmentShader") else {
                print("❌ Live2DRenderer - フラグメントシェーダーの取得に失敗")
                pipelineState = nil
                return
            }
            
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.depthAttachmentPixelFormat = .depth32Float
            
            // アルファブレンディングを有効にする
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].rgbBlendOperation = .add
            descriptor.colorAttachments[0].alphaBlendOperation = .add
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            print("✅ Live2DRenderer - Metal render pipeline作成成功")
            
            // テクスチャ用パイプラインステートを作成
            createTexturePipelineState(library: library)
            
        } catch {
            print("❌ Live2DRenderer - シェーダーライブラリまたはパイプライン作成失敗: \(error)")
            pipelineState = nil
        }
    }
    
    private func createTexturePipelineState(library: MTLLibrary) {
        print("🔍 Live2DRenderer - テクスチャパイプライン作成開始")
        
        do {
            let descriptor = MTLRenderPipelineDescriptor()
            
            // テクスチャ用のシェーダーを取得
            guard let vertexFunction = library.makeFunction(name: "textureVertexShader") else {
                print("❌ Live2DRenderer - テクスチャ頂点シェーダーの取得に失敗")
                return
            }
            
            guard let fragmentFunction = library.makeFunction(name: "textureFragmentShader") else {
                print("❌ Live2DRenderer - テクスチャフラグメントシェーダーの取得に失敗")
                return
            }
            
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.depthAttachmentPixelFormat = .depth32Float
            
            // アルファブレンディングを有効にする
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].rgbBlendOperation = .add
            descriptor.colorAttachments[0].alphaBlendOperation = .add
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            texturePipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            print("✅ Live2DRenderer - テクスチャパイプライン作成成功")
            
        } catch {
            print("❌ Live2DRenderer - テクスチャパイプライン作成失敗: \(error)")
            texturePipelineState = nil
        }
    }
    
    private func setupDepthStencil() {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: descriptor)
    }
    
    private func setupBuffers() {
        // Create uniform buffer
        uniformBuffer = device.makeBuffer(length: MemoryLayout<simd_float4x4>.size * 2, options: .storageModeShared)
        
        // Create animation buffer
        animationBuffer = device.makeBuffer(length: MemoryLayout<Float>.size * 4, options: .storageModeShared)
        
        // Create vertex buffer for quad
        let vertices: [Float] = [
            -1.0, -1.0, 0.0, 1.0,  // Bottom left
             1.0, -1.0, 0.0, 1.0,  // Bottom right
            -1.0,  1.0, 0.0, 1.0,  // Top left
             1.0,  1.0, 0.0, 1.0   // Top right
        ]
        
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: .storageModeShared)
        
        // Create index buffer for quad
        let indices: [UInt16] = [0, 1, 2, 1, 3, 2]
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size, options: .storageModeShared)
    }
    
    // MARK: - MTKViewDelegate
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Update projection matrix
        let aspect = Float(size.width / size.height)
        projectionMatrix = matrix_float4x4(ortho: -aspect, aspect, -1.0, 1.0, 0.1, 100.0)
        drawableSize = size
        
        // Live2Dレンダラーにサイズを通知（プレースホルダー実装）
        if let manager = live2DManager, manager.isModelLoaded() {
            print("ビューポートサイズ変更: \(size)")
        }
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else {
            print("🔍 Live2DRenderer - drawable または renderPassDescriptor が nil")
            return
        }
        
        // Update time
        let currentTime = CACurrentMediaTime()
        if lastTime == 0.0 {
            lastTime = currentTime
        }
        let deltaTime = Float(currentTime - lastTime)
        lastTime = currentTime
        time += deltaTime
        
        // Update Live2D model
        if let live2DManager = live2DManager {
            live2DManager.update(deltaTime: deltaTime)
        }
        
        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { 
            print("🔍 Live2DRenderer - commandBuffer作成失敗")
            return 
        }
        
        // Create render encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { 
            print("🔍 Live2DRenderer - renderEncoder作成失敗")
            return 
        }
        
        // デバッグ: 強制的にキャラクターを表示
        print("🔍 Live2DRenderer - レンダリング開始: drawable=\(drawable.texture.width)x\(drawable.texture.height)")
        
        // Only use pipeline if it was created successfully
        if let pipelineState = pipelineState, let depthStencilState = depthStencilState {
            // デバッグログを適度に減らす
            if Int(time * 10) % 100 == 0 {
                print("🔍 Live2DRenderer - パイプライン状態設定")
            }
            
            // Set pipeline state
            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.setDepthStencilState(depthStencilState)
            
            // Set uniforms
            updateUniforms()
            renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            renderEncoder.setFragmentBuffer(animationBuffer, offset: 0, index: 2)
            
            // Draw Live2D model if available
            if let live2DManager = live2DManager {
                drawLive2DModel(renderEncoder: renderEncoder, live2DManager: live2DManager)
            } else {
                if Int(time * 10) % 100 == 0 {
                    print("🔍 Live2DRenderer - Live2DManager無効、Live2D風描画")
                }
                // Live2D風キャラクター描画
                drawLive2DStyleCharacter(renderEncoder: renderEncoder, 
                                       breathPhase: time * 2.0, 
                                       isBlinking: Int(time * 3.0) % 3 == 0)
            }
        } else {
            print("❌ Live2DRenderer - パイプライン状態が無効、フォールバック描画")
            // Fallback: clear screen with a solid color when shaders are not available
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.8, green: 0.4, blue: 0.4, alpha: 1.0)
            
            // 赤色の警告画面を表示
            print("⚠️ Live2DRenderer - シェーダーが利用できません")
        }
        
        // End encoding
        renderEncoder.endEncoding()
        
        // Present drawable
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        // Notify delegate
        if let metalView = view as? Live2DMetalView {
            metalView.live2DDelegate?.live2DMetalView(metalView, didUpdateFrame: currentTime)
        }
    }
    
    private func updateUniforms() {
        // Update model view matrix
        modelViewMatrix = matrix_float4x4(translation: [0, 0, -5])
        
        // Write to uniform buffer
        if let uniformBuffer = uniformBuffer {
            let uniforms = uniformBuffer.contents().bindMemory(to: simd_float4x4.self, capacity: 2)
            uniforms[0] = projectionMatrix
            uniforms[1] = modelViewMatrix
        }
        
        // Update animation data
        if let animationBuffer = animationBuffer {
            let animationData = animationBuffer.contents().bindMemory(to: Float.self, capacity: 4)
            animationData[0] = time // current time
            animationData[1] = sin(time * 2.0) // breath phase
            animationData[2] = (Int(time * 3.0) % 100 < 20) ? 1.0 : 0.0 // blink phase
            animationData[3] = 0.0 // padding
        }
    }
    
    private func drawLive2DModel(renderEncoder: MTLRenderCommandEncoder, live2DManager: Live2DManager) {
        // Live2Dモデルの描画（実際のSDK使用）
        if live2DManager.isModelLoaded() {
            // 10秒に1回だけログ出力
            if Int(time * 10) % 100 == 0 {
                print("🔍 Live2DRenderer - 実際のLive2Dモデルを描画")
            }
            
            // Live2D SDKのレンダラーを使用してモデルを描画
            let renderer = live2DManager.getRenderer()
            let model = live2DManager.getModel()
            
            if Int(time * 10) % 100 == 0 {
                print("🔍 Live2DRenderer - renderer: \(renderer != nil ? "有効" : "無効"), model: \(model != nil ? "有効" : "無効")")
            }
            
            if let renderer = renderer as? UnsafeMutableRawPointer,
               let model = model as? UnsafeMutableRawPointer {
                // 実際のLive2D描画処理
                renderLive2DModel(renderer, model)
                
                // Live2D風キャラクターを描画（アニメーション付き）
                drawLive2DStyleCharacter(renderEncoder: renderEncoder, 
                                       breathPhase: time * 2.0, 
                                       isBlinking: Int(time * 3.0) % 3 == 0)
            } else {
                if Int(time * 10) % 100 == 0 {
                    print("🔍 Live2DRenderer - Live2Dレンダラーまたはモデルが無効、フォールバック描画")
                    print("🔍 Live2DRenderer - renderer type: \(type(of: renderer)), model type: \(type(of: model))")
                }
                drawLive2DStyleCharacter(renderEncoder: renderEncoder, 
                                       breathPhase: time * 2.0, 
                                       isBlinking: Int(time * 3.0) % 3 == 0)
            }
        } else {
            // 10秒に1回だけログ出力
            if Int(time * 10) % 100 == 0 {
                print("🔍 Live2DRenderer - モデル読み込み中、Live2D風キャラクターを描画")
            }
            // Live2D風キャラクターを描画（実際のキャラクター表示）
            drawLive2DStyleCharacter(renderEncoder: renderEncoder, 
                                   breathPhase: time * 2.0, 
                                   isBlinking: Int(time * 3.0) % 3 == 0)
        }
    }
    
    private func drawPlaceholder(renderEncoder: MTLRenderCommandEncoder) {
        // 頂点バッファとインデックスバッファを設定
        guard let vertexBuffer = self.vertexBuffer,
              let indexBuffer = self.indexBuffer else {
            print("❌ Live2DRenderer - 頂点バッファまたはインデックスバッファが nil")
            return
        }
        
        // デバッグログを大幅に削減
        if Int.random(in: 0..<600) == 0 {
            print("🔍 Live2DRenderer - drawPlaceholder実行中")
            print("🔍 Live2DRenderer - 頂点バッファサイズ: \(vertexBuffer.length)")
            print("🔍 Live2DRenderer - インデックスバッファサイズ: \(indexBuffer.length)")
        }
        
        // 頂点バッファを設定
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // インデックスバッファを使用して描画
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
        
        if Int.random(in: 0..<600) == 0 {
            print("✅ Live2DRenderer - drawPlaceholder完了")
        }
    }
    
    private func drawAnimatedPlaceholder(renderEncoder: MTLRenderCommandEncoder, breathPhase: Float, isBlinking: Bool) {
        // アニメーション付きプレースホルダーの描画
        // 呼吸や瞬きのアニメーションをグラデーションの色で表現
        drawPlaceholder(renderEncoder: renderEncoder)
        
        // デバッグ情報の出力（適度に減らす）
        if Int(breathPhase * 10) % 300 == 0 { // 30秒おきにログ出力
            print("Live2Dアニメーション状態: 呼吸=\(sin(breathPhase)), 瞬き=\(isBlinking)")
        }
    }
    
    private func drawLive2DStyleCharacter(renderEncoder: MTLRenderCommandEncoder, breathPhase: Float, isBlinking: Bool) {
        print("🎭 Live2DRenderer - Live2Dキャラクター描画開始")
        
        // 頂点バッファとインデックスバッファを設定
        guard let vertexBuffer = self.vertexBuffer,
              let indexBuffer = self.indexBuffer,
              let pipelineState = self.pipelineState,
              let depthStencilState = self.depthStencilState,
              let uniformBuffer = self.uniformBuffer,
              let animationBuffer = self.animationBuffer else {
            print("❌ Live2DRenderer - 必要なリソースが不足")
            return
        }
        
        // レンダラーパイプライン状態を設定
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        // バッファを設定
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(animationBuffer, offset: 0, index: 2)
        
        // Live2Dテクスチャを設定
        if let texture = loadLive2DTexture() {
            print("✅ Live2DRenderer - テクスチャ設定成功")
            renderEncoder.setFragmentTexture(texture, index: 0)
        } else {
            print("⚠️ Live2DRenderer - テクスチャ読み込み失敗、フォールバック描画")
        }
        
        // 描画実行
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
        
        print("✅ Live2DRenderer - Live2Dキャラクター描画完了")
    }
    
    // MARK: - Live2D Texture Loading
    private func loadLive2DTexture() -> MTLTexture? {
        print("🔍 Live2DRenderer - テクスチャ読み込み開始")
        
        // 🎨 テンポラリ: プログラムで作成したテクスチャを使用
        return createDebugTexture()
    }
    
    private func createDebugTexture() -> MTLTexture? {
        print("🎨 Live2DRenderer - デバッグテクスチャ作成開始")
        
        // 512x512の簡単なテクスチャを作成
        let width = 512
        let height = 512
        
        // カラフルなグラデーションテクスチャデータを作成
        var textureData: [UInt8] = []
        
        for y in 0..<height {
            for x in 0..<width {
                let normalizedX = Float(x) / Float(width)
                let normalizedY = Float(y) / Float(height)
                
                // Live2D風のキャラクター色（肌色ベース）
                let r = UInt8(255 * (0.8 + 0.2 * normalizedX))  // 肌色ベース
                let g = UInt8(255 * (0.6 + 0.3 * normalizedY))  // 肌色ベース  
                let b = UInt8(255 * (0.5 + 0.2 * (normalizedX + normalizedY) / 2))  // 肌色ベース
                let a = UInt8(255)  // 完全不透明
                
                textureData.append(r)
                textureData.append(g)
                textureData.append(b)
                textureData.append(a)
            }
        }
        
        // MTLTextureDescriptorを作成
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead]
        
        // テクスチャを作成
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            print("❌ Live2DRenderer - デバッグテクスチャ作成失敗")
            return nil
        }
        
        // テクスチャデータをコピー
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.replace(region: region, mipmapLevel: 0, withBytes: textureData, bytesPerRow: width * 4)
        
        print("✅ Live2DRenderer - デバッグテクスチャ作成成功: \(width)x\(height)")
        return texture
    }
    
    private func createMetalTexture(from image: UIImage) -> MTLTexture? {
        guard let cgImage = image.cgImage else {
            print("❌ Live2DRenderer - CGImage変換失敗")
            return nil
        }
        
        let textureLoader = MTKTextureLoader(device: device)
        
        do {
            let texture = try textureLoader.newTexture(cgImage: cgImage, options: [
                .textureUsage: MTLTextureUsage.shaderRead.rawValue,
                .SRGB: false
            ])
            print("✅ Live2DRenderer - MTLTexture作成成功: \(texture.width)x\(texture.height)")
            return texture
        } catch {
            print("❌ Live2DRenderer - MTLTexture作成失敗: \(error)")
            return nil
        }
    }
    
    private func listBundleContents() {
        print("🔍 Live2DRenderer - バンドル内容調査開始")
        
        guard let bundlePath = Bundle.main.resourcePath else {
            print("❌ Live2DRenderer - バンドルパス取得失敗")
            return
        }
        
        print("📁 バンドルパス: \(bundlePath)")
        
        // バンドル内のすべてのpngファイルを検索
        if let enumerator = FileManager.default.enumerator(atPath: bundlePath) {
            print("🔍 Live2DRenderer - バンドル内のPNGファイル一覧:")
            for case let file as String in enumerator {
                if file.lowercased().hasSuffix(".png") {
                    print("  📄 \(file)")
                }
            }
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        // Clean up resources
        uniformBuffer = nil
        animationBuffer = nil
        vertexBuffer = nil
        indexBuffer = nil
    }
}

// MARK: - Matrix Helper Functions
extension matrix_float4x4 {
    init(translation: SIMD3<Float>) {
        self.init(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(translation.x, translation.y, translation.z, 1)
        )
    }
    
    init(ortho left: Float, _ right: Float, _ bottom: Float, _ top: Float, _ near: Float, _ far: Float) {
        let ral = right + left
        let rsl = right - left
        let tab = top + bottom
        let tsb = top - bottom
        let fan = far + near
        let fsn = far - near
        
        self.init(
            SIMD4<Float>(2.0 / rsl, 0.0, 0.0, 0.0),
            SIMD4<Float>(0.0, 2.0 / tsb, 0.0, 0.0),
            SIMD4<Float>(0.0, 0.0, -2.0 / fsn, 0.0),
            SIMD4<Float>(-ral / rsl, -tab / tsb, -fan / fsn, 1.0)
        )
    }
}