//
//  Live2DObjCBridge.mm
//  Character
//
//  Objective-C++ Bridge for Live2D Cubism
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <UIKit/UIKit.h>

// Live2D Core Types
typedef unsigned int csmVersion;

// Live2D Core関数のプレースホルダー実装
csmVersion csmGetVersion() {
    // Live2D Cubism Core 5.0.0 に相当するバージョン番号
    return (5 << 24) | (0 << 16) | 0;
}

// Live2D Model Data Structure
struct Live2DModelData {
    void* modelPointer;
    bool isLoaded;
    float* vertices;
    int vertexCount;
    unsigned short* indices;
    int indexCount;
    void* texture;
    float currentTime;
    bool isAnimating;
};

// Global state
static bool g_frameworkInitialized = false;
static Live2DModelData* g_currentModel = nullptr;

@interface Live2DObjCBridge : NSObject
+ (void)initializeFramework;
+ (void)loadModelWithName:(NSString*)modelName;
+ (void)updateWithDeltaTime:(float)deltaTime;
+ (void)renderWithDevice:(id<MTLDevice>)device commandEncoder:(id<MTLRenderCommandEncoder>)encoder;
+ (BOOL)isModelLoaded;
+ (void)cleanup;
@end

@implementation Live2DObjCBridge

+ (void)initializeFramework {
    if (g_frameworkInitialized) {
        return;
    }
    
    NSLog(@"Live2D Framework初期化開始");
    g_frameworkInitialized = true;
    NSLog(@"Live2D Framework初期化完了");
}

+ (void)loadModelWithName:(NSString*)modelName {
    if (!g_frameworkInitialized) {
        [self initializeFramework];
    }
    
    NSLog(@"🎭 Live2D モデル読み込み開始: %@", modelName);
    
    // 既存モデルのクリーンアップ
    if (g_currentModel) {
        delete g_currentModel;
    }
    
    // 新しいモデルデータを作成
    g_currentModel = new Live2DModelData();
    g_currentModel->modelPointer = (void*)0x12345678;
    g_currentModel->isLoaded = true;
    g_currentModel->currentTime = 0.0f;
    g_currentModel->isAnimating = true;
    
    // サンプル頂点データ（四角形）
    static float vertices[] = {
        -0.8f, -0.8f, 0.0f, 1.0f,  // Bottom left
         0.8f, -0.8f, 0.0f, 1.0f,  // Bottom right
        -0.8f,  0.8f, 0.0f, 1.0f,  // Top left
         0.8f,  0.8f, 0.0f, 1.0f   // Top right
    };
    
    static unsigned short indices[] = {0, 1, 2, 1, 3, 2};
    
    g_currentModel->vertices = vertices;
    g_currentModel->vertexCount = 4;
    g_currentModel->indices = indices;
    g_currentModel->indexCount = 6;
    
    // テクスチャの読み込み
    [self loadTextureForModel:modelName];
    
    NSLog(@"✅ Live2D モデル読み込み完了: %@", modelName);
    NSLog(@"🎨 モデルデータ: vertices=%d, indices=%d, texture=%@", 
          g_currentModel->vertexCount, 
          g_currentModel->indexCount,
          g_currentModel->texture ? @"loaded" : @"null");
}

+ (void)loadTextureForModel:(NSString*)modelName {
    NSLog(@"テクスチャ読み込み開始");
    
    // テクスチャファイル名を決定
    NSString* textureName = @"texture_00_female";
    
    // バンドルからテクスチャを読み込み（Live2DModels/Femaleディレクトリから）
    NSString* texturePath = [[NSBundle mainBundle] pathForResource:textureName 
                                                            ofType:@"png" 
                                                       inDirectory:@"Live2DModels/Female"];
    if (!texturePath) {
        NSLog(@"❌ Live2DSwiftBridge - テクスチャファイルが見つかりません: %@.png in Live2DModels/Female/", textureName);
        
        // フォールバック: バンドルルートからも探してみる
        texturePath = [[NSBundle mainBundle] pathForResource:textureName ofType:@"png"];
        if (!texturePath) {
            NSLog(@"❌ Live2DSwiftBridge - バンドルルートでもテクスチャが見つかりません: %@.png", textureName);
            return;
        } else {
            NSLog(@"✅ Live2DSwiftBridge - バンドルルートでテクスチャ発見: %@", texturePath);
        }
    } else {
        NSLog(@"✅ Live2DSwiftBridge - テクスチャパス取得成功: %@", texturePath);
    }
    
    UIImage* image = [UIImage imageWithContentsOfFile:texturePath];
    if (!image) {
        NSLog(@"ERROR: 画像の読み込みに失敗: %@", texturePath);
        return;
    }
    
    // Metalテクスチャを作成
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device && g_currentModel) {
        MTKTextureLoader* textureLoader = [[MTKTextureLoader alloc] initWithDevice:device];
        
        NSError* error;
        id<MTLTexture> metalTexture = [textureLoader newTextureWithCGImage:image.CGImage options:nil error:&error];
        
        if (error) {
            NSLog(@"ERROR: テクスチャ作成エラー: %@", error.localizedDescription);
        } else {
            // テクスチャをvoid*として保存（retain）
            g_currentModel->texture = (__bridge_retained void*)metalTexture;
            NSLog(@"SUCCESS: テクスチャ作成成功: %ldx%ld", 
                  metalTexture.width, metalTexture.height);
        }
    }
}

+ (void)updateWithDeltaTime:(float)deltaTime {
    if (!g_currentModel || !g_currentModel->isLoaded) {
        return;
    }
    
    g_currentModel->currentTime += deltaTime;
    
    // アニメーション更新（呼吸、瞬きなど）
    // この実装では基本的なタイムトラッキングのみ行う
}

+ (void)renderWithDevice:(id<MTLDevice>)device commandEncoder:(id<MTLRenderCommandEncoder>)encoder {
    if (!g_currentModel || !g_currentModel->isLoaded) {
        return;
    }
    
    // この関数では、実際のLive2D描画の準備をします
    // Metal Rendererに必要な情報を提供
}

+ (BOOL)isModelLoaded {
    return g_currentModel && g_currentModel->isLoaded;
}

+ (void)cleanup {
    if (g_currentModel) {
        delete g_currentModel;
        g_currentModel = nullptr;
    }
    g_frameworkInitialized = false;
    NSLog(@"Live2DObjCBridge - クリーンアップ完了");
}

+ (Live2DModelData*)getCurrentModel {
    return g_currentModel;
}

@end

// C-style functions for the existing C++ bridge
extern "C" {
    void* createLive2DAllocator(void) {
        [Live2DObjCBridge initializeFramework];
        return (void*)0x11111111; // ダミーアロケーター
    }
    
    void initializeLive2DFramework(void* allocator) {
        [Live2DObjCBridge initializeFramework];
    }
    
    void disposeLive2DFramework(void) {
        [Live2DObjCBridge cleanup];
    }
    
    void* loadLive2DModel(const char* modelPath) {
        NSString* modelPath_NS = [NSString stringWithUTF8String:modelPath];
        NSLog(@"🎯 loadLive2DModel呼び出し: %@", modelPath_NS);
        
        // パスからモデル名を抽出（mock://の場合も実際のパスの場合も対応）
        NSString* modelName;
        if ([modelPath_NS hasPrefix:@"mock://"]) {
            NSLog(@"✅ モックパスを検出 - 強制的にモデルを作成");
            modelName = @"character_female"; // デフォルトのモデル名
        } else {
            NSLog(@"📁 実際のファイルパスを使用");
            modelName = [modelPath_NS lastPathComponent];
        }
        
        NSLog(@"🎭 モデル名決定: %@", modelName);
        [Live2DObjCBridge loadModelWithName:modelName];
        
        // モデルデータが作成されているかを確認
        Live2DModelData* currentModel = [Live2DObjCBridge getCurrentModel];
        if (currentModel) {
            NSLog(@"✅ モデルデータ作成成功 - ポインター: %p", currentModel);
        } else {
            NSLog(@"❌ モデルデータ作成失敗");
        }
        
        return currentModel;
    }
    
    void* createLive2DRenderer(void* device) {
        return (void*)0x22222222; // ダミーレンダラー
    }
    
    void updateLive2DModel(void* model, float deltaTime) {
        [Live2DObjCBridge updateWithDeltaTime:deltaTime];
    }
    
    void renderLive2DModel(void* renderer, void* model) {
        // Metalレンダリングは別途処理
    }
    
    void playLive2DMotion(void* model, const char* groupName, int motionIndex) {
        NSLog(@"Playing motion: %s[%d]", groupName, motionIndex);
    }
    
    void setLive2DExpression(void* model, const char* expressionName) {
        NSLog(@"Setting expression: %s", expressionName);
    }
    
    void setLive2DParameter(void* model, const char* paramName, float value) {
        NSLog(@"Setting parameter %s = %.2f", paramName, value);
    }
    
    int isLive2DModelLoaded(void* model) {
        return [Live2DObjCBridge isModelLoaded] ? 1 : 0;
    }
    
    // 新しい関数：モデルデータへのアクセス
    Live2DModelData* getLive2DModelData(void* model) {
        return [Live2DObjCBridge getCurrentModel];
    }
    
    // テクスチャを取得する関数
    void* getLive2DTexture(void) {
        Live2DModelData* modelData = [Live2DObjCBridge getCurrentModel];
        if (modelData && modelData->texture) {
            return modelData->texture;
        }
        return NULL;
    }
}