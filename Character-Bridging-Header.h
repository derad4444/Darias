//
//  Character-Bridging-Header.h
//  Character
//
//  Live2D Cubism SDK for iOS Bridging Header
//

#ifndef Character_Bridging_Header_h
#define Character_Bridging_Header_h

// Objective-C++ compatibility
#ifdef __cplusplus
#define EXTERN_C extern "C"
#else
#define EXTERN_C extern
#endif

// Live2D Cubism Core
#import "Live2D/Core/include/Live2DCubismCore.h"

// C++ wrapper functions for Swift
EXTERN_C void* createLive2DAllocator(void);
EXTERN_C void initializeLive2DFramework(void* allocator);
EXTERN_C void disposeLive2DFramework(void);
EXTERN_C void* loadLive2DModel(const char* modelPath);
EXTERN_C void* createLive2DRenderer(void* device);
EXTERN_C void updateLive2DModel(void* model, float deltaTime);
EXTERN_C void renderLive2DModel(void* renderer, void* model);
EXTERN_C void playLive2DMotion(void* model, const char* groupName, int motionIndex);
EXTERN_C void setLive2DExpression(void* model, const char* expressionName);
EXTERN_C void setLive2DParameter(void* model, const char* paramName, float value);
EXTERN_C int isLive2DModelLoaded(void* model);

#endif /* Character_Bridging_Header_h */
