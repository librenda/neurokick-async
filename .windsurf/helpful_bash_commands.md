(base) Brendas-MacBook-Air:NeuroKick-Qwen-Local-LLM-Working-Copy b432li$ export OLLAMA_CONTEXT_LENGTH=8192
(base) Brendas-MacBook-Air:NeuroKick-Qwen-Local-LLM-Working-Copy b432li$ echo $OLLAMA_CONTEXT_LENGTH
8192


(base) b432li@Brendas-MacBook-Air NeuroKick-Qwen-Local-LLM-Working-Copy % ollama show qwen3:4b
  Model
    architecture        qwen3     
    parameters          4.0B      
    context length      40960     
    embedding length    2560      
    quantization        Q4_K_M    

  Capabilities
    completion    
    tools         

  Parameters
    top_k             20                
    top_p             0.95              
    repeat_penalty    1                 
    stop              "<|im_start|>"    
    stop              "<|im_end|>"      
    temperature       0.6               

  License
    Apache License               
    Version 2.0, January 2004    

(base) b432li@Brendas-MacBook-Air NeuroKick-Qwen-Local-LLM-Working-Copy % ollama show qwen3:4b-8192
  Model
    architecture        qwen3     
    parameters          4.0B      
    context length      40960     
    embedding length    2560      
    quantization        Q4_K_M    

  Capabilities
    completion    
    tools         

  Parameters
    num_ctx           8192              
    repeat_penalty    1                 
    stop              "<|im_start|>"    
    stop              "<|im_end|>"      
    temperature       0.6               
    top_k             20                
    top_p             0.95              

  License
    Apache License               
    Version 2.0, January 2004    

(base) b432li@Brendas-MacBook-Air NeuroKick-Qwen-Local-LLM-Working-Copy % 

Perfect! Now let's test our implementation. Let's build and run the project to see if our auto-save functionality works:
input

cd /Users/b432li/Code/NeuroKick-Qwen-Local-LLM-Working-Copy && xcodebuild -project MacAudioRecorder.xcodeproj -scheme MacAudioRecorder -configuration Debug build

output
cd /Users/b432li/Code/NeuroKick-Qwen-Local-LLM-Working-Copy
    builtin-validationUtility /Users/b432li/Library/Developer/Xcode/DerivedData/MacAudioRecorder-dawtuwiatso
dfbbbjlqvxmsxuqun/Build/Products/Debug/MacAudioRecorder.app -no-validate-extension -infoplist-subpath Conten
ts/Info.plist

RegisterWithLaunchServices /Users/b432li/Library/Developer/Xcode/DerivedData/MacAudioRecorder-dawtuwiatsodfb
bbjlqvxmsxuqun/Build/Products/Debug/MacAudioRecorder.app (in target 'MacAudioRecorder' from project 'MacAudi
oRecorder')
    cd /Users/b432li/Code/NeuroKick-Qwen-Local-LLM-Working-Copy
    /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/V
ersions/Current/Support/lsregister -f -R -trusted /Users/b432li/Library/Developer/Xcode/DerivedData/MacAudio
Recorder-dawtuwiatsodfbbbjlqvxmsxuqun/Build/Products/Debug/MacAudioRecorder.app

** BUILD SUCCEEDED **

Excellent! The build succeeded with only some deprecation warnings (which are normal). Now let's check if our auto-save files are being created by looking at the Documents folder:
ls -la ~/Documents/ | grep -E "(transcript|analysis|NeuroKick)"

output
-rw-r--r--@   1 b432li  staff    4095 May 31 02:12 behavioural_analysis_1.txt
drwxr-xr-x   19 b432li  staff     608 May  8 02:51 NeuroKick-gemma-Local-LLM
-rw-r--r--@   1 b432li  staff    5312 May 31 02:03 workplace_analysis.txt
