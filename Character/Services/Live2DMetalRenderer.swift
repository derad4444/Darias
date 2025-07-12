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
        
        // 透明背景の設定を復元
        self.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        
        // 透明背景の設定
        self.isOpaque = false
        self.backgroundColor = UIColor.clear
        
        // デバッグ: 一時的に背景を見えるようにする
        // self.backgroundColor = UIColor.blue.withAlphaComponent(0.3)
        
        print("🔍 Live2DMetalView - 透明背景設定完了")
        
        // パフォーマンス最適化設定
        self.preferredFramesPerSecond = 30 // 60FPSから30FPSに削減
        self.enableSetNeedsDisplay = false
        self.isPaused = true // 初期は停止状態
        
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
                    self.live2DManager = Live2DManager()
                    print("🔍 Live2DMetalView - Live2DManager作成完了")
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

        fragment float4 simpleFragmentShader(VertexOut in [[stage_in]]) {
            float2 uv = in.texCoord;
            
            // Live2D風キャラクター描画（フォールバック用）
            float2 center = float2(0.5, 0.5);
            float dist = distance(uv, center);
            
            // 顔の輪郭（楕円形）
            float faceRadius = 0.35;
            float face = smoothstep(faceRadius + 0.02, faceRadius, dist);
            
            // 肌の色
            float3 skinColor = float3(1.0, 0.9, 0.8);
            
            // 目の描画
            float2 leftEye = float2(0.4, 0.6);
            float2 rightEye = float2(0.6, 0.6);
            float eyeSize = 0.05;
            
            float leftEyeDist = distance(uv, leftEye);
            float rightEyeDist = distance(uv, rightEye);
            
            float eyes = smoothstep(eyeSize, eyeSize - 0.01, leftEyeDist) + 
                        smoothstep(eyeSize, eyeSize - 0.01, rightEyeDist);
            
            // 口の描画
            float2 mouth = float2(0.5, 0.4);
            float mouthDist = distance(uv, mouth);
            float mouthShape = smoothstep(0.03, 0.025, mouthDist);
            
            // 髪の毛（上部）
            float hair = 0.0;
            if (uv.y > 0.6 && dist < 0.4) {
                hair = 1.0;
            }
            
            // 最終的な色の合成
            float3 finalColor = skinColor * face;
            
            // 目を黒く
            finalColor = mix(finalColor, float3(0.1, 0.1, 0.1), eyes);
            
            // 口をピンクに
            finalColor = mix(finalColor, float3(1.0, 0.7, 0.8), mouthShape);
            
            // 髪を茶色に
            finalColor = mix(finalColor, float3(0.6, 0.4, 0.2), hair);
            
            // アルファ値（顔の部分のみ不透明）
            float alpha = face + hair;
            
            return float4(finalColor, alpha);
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
        // 実際のLive2D風キャラクター描画
        if Int(breathPhase * 10) % 180 == 0 { // 18秒おきにログ出力
            print("✨ Live2DRenderer - drawLive2DStyleCharacter呼び出し: 呼吸=\(String(format: "%.2f", sin(breathPhase))), 瞬き=\(isBlinking)")
        }
        
        // 頂点バッファとインデックスバッファを設定
        guard let vertexBuffer = self.vertexBuffer,
              let indexBuffer = self.indexBuffer else {
            print("❌ Live2DRenderer - drawLive2DStyleCharacter: バッファが nil")
            return
        }
        
        // Live2DManagerからテクスチャを取得
        var hasTexture = false
        if let live2DManager = live2DManager,
           let model = live2DManager.getModel() as? UnsafeMutableRawPointer {
            
            // Live2DModelDataからテクスチャを取得
            let modelDataPointer = model.bindMemory(to: Live2DModelData.self, capacity: 1)
            let modelData = modelDataPointer.pointee
            
            if !modelData.textures.isEmpty {
                let texture = modelData.textures[0] // 最初のテクスチャを使用
                renderEncoder.setFragmentTexture(texture, index: 0)
                hasTexture = true
                
                if Int(breathPhase * 10) % 180 == 0 {
                    print("✨ Live2DRenderer - Live2Dテクスチャ使用: \(texture.width)x\(texture.height)")
                }
            }
        }
        
        // 頂点バッファを設定
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // テクスチャがある場合はテクスチャシェーダー、ない場合はフォールバックシェーダーを使用
        if hasTexture && texturePipelineState != nil {
            // テクスチャシェーダー用のパイプラインステートを使用
            renderEncoder.setRenderPipelineState(texturePipelineState!)
            renderEncoder.setDepthStencilState(depthStencilState!)
            renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            
            if Int(breathPhase * 10) % 180 == 0 {
                print("✅ Live2DRenderer - テクスチャパイプライン使用")
            }
        } else {
            // フォールバックシェーダーを使用
            if let pipelineState = pipelineState, let depthStencilState = depthStencilState {
                renderEncoder.setRenderPipelineState(pipelineState)
                renderEncoder.setDepthStencilState(depthStencilState)
                renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            }
            
            if Int(breathPhase * 10) % 180 == 0 {
                print("⚠️ Live2DRenderer - フォールバックシェーダー使用")
            }
        }
        
        // Live2Dキャラクターを描画
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
        
        if Int(breathPhase * 10) % 180 == 0 {
            print("✨ Live2DRenderer - Live2Dキャラクター描画完了 (テクスチャ: \(hasTexture ? "有り" : "無し"))")
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        // Clean up resources
        uniformBuffer = nil
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