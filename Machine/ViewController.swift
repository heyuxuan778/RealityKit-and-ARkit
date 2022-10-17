//
//  ViewController.swift
//  Machine
//
//  Created by Down on 2022/9/18.
//

import UIKit
import RealityKit
import ARKit
import Speech
class ViewController: UIViewController {
    @IBOutlet var arView: ARView!
    
    var entity: Entity?
    var moveToLocation: Transform = Transform()
    let moveTime: Double = 5
    //语音识别
    let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    let speechRequest = SFSpeechAudioBufferRecognitionRequest()
    var speechTask = SFSpeechRecognitionTask()
    // 音频实例化
    let audioEngine = AVAudioEngine() //设立音频节点，处理音频输入和输出
    let audioSession = AVAudioSession() //音频记录初始化
    override func viewDidLoad() {
        super.viewDidLoad()
        entity = try! Entity.loadModel(named: "toy_robot_vintage.usdz")
        entity?.generateCollisionShapes(recursive: true)
        //包裹起来 增加碰撞属性
        arView.installGestures([.rotation,.scale,.translation], for: entity! as! HasCollision)
        //创建session
        startARSession()
        //创建手势 将2d位置转换为3d位置 获取位置传递到下面的函数中
        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTapLocation)))
        arView.addGestureRecognizer(UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLocation)))
        arView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressLocation)))
        startSpeechRecognition()
        
    }
    @objc func handleTapLocation(_ recognizer:UITapGestureRecognizer){
        let tapLocation = recognizer.location(in: arView)
        //发射粒子 转化为3d坐标
        let result = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .horizontal)
        //得到x,y,z坐标
        if let firstResult = result.first{
            let worldPosition = simd_make_float3(firstResult.worldTransform.columns.3)
            placeModelInWorld(object: entity!, position: worldPosition)
        }
    }
    @objc func handleSwipeLocation(_ recognizer: UISwipeGestureRecognizer){
        let longPressLocation = recognizer.location(in: arView)
        if let entity = arView.entity(at: longPressLocation){
            entity.anchor?.removeFromParent()
        }
    }
    @objc func handleLongPressLocation(_ recognizer: UILongPressGestureRecognizer){
        let doubleTapLocation = recognizer.location(in: arView)
        let result = arView.raycast(from: doubleTapLocation, allowing: .estimatedPlane, alignment: .horizontal)
        //得到x,y,z坐标
        if let firstResult = result.first{
            let worldPosition = simd_make_float3(firstResult.worldTransform.columns.3)
            if (arView.entity(at: doubleTapLocation) == nil){
//                let entityOne = try! Entity.loadModel(named: "\(models[count])")
//                let objectAnchor = AnchorEntity(world: worldPosition)
//                objectAnchor.addChild(entityOne)
//                arView.scene.addAnchor(objectAnchor)
                let objectAnchor = AnchorEntity(world: worldPosition)
                let entity1 = try! Entity.loadModel(named: "toy_robot_vintageOne.usdz")
                entity1.generateCollisionShapes(recursive: true)
                arView.installGestures([.translation,.rotation,.scale], for: entity1)
                objectAnchor.addChild(entity1)
                arView.scene.addAnchor(objectAnchor)
                
            }
        }
    }
    func startARSession(){
        arView.automaticallyConfigureSession = true
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
//        arView.debugOptions = .showAnchorGeometry
        arView.session.run(configuration)
    }
    func placeModelInWorld(object:Entity,position:SIMD3<Float>){
        let objectAnchor = AnchorEntity(world: position)
        objectAnchor.addChild(object)
        arView.scene.addAnchor(objectAnchor)
    }
    func rebotMove(direction: String){
        switch direction{
        case "forward":
            moveToLocation.translation = (entity!.transform.translation)+simd_float3(x:0,y:0,z:20)
            entity!.move(to: moveToLocation, relativeTo: entity!, duration: moveTime)
            walkAnimation(movementDuration: moveTime)
            print("moveForward")
        case "back":
            moveToLocation.translation = (entity!.transform.translation)+simd_float3(x:0,y:0,z:-20)
            entity!.move(to: moveToLocation, relativeTo: entity!, duration: moveTime)
            walkAnimation(movementDuration: moveTime)
        case "left":
            let rotateToAngle = simd_quatf(angle: GLKMathDegreesToRadians(90), axis: SIMD3(x:0,y:1,z:0))
            entity!.setOrientation(rotateToAngle, relativeTo: entity!)
        case "right":
            let rotateToAngle = simd_quatf(angle: GLKMathDegreesToRadians(-90), axis: SIMD3(x:0,y:1,z:0))
            entity!.setOrientation(rotateToAngle, relativeTo: entity!)
        default:
            print("没有移动指令")
        }
    }
    func walkAnimation(movementDuration: Double){
        if let rebotAnimation = entity!.availableAnimations.first{
            entity!.playAnimation(rebotAnimation.repeat(duration: movementDuration),transitionDuration: 0.5,startsPaused: false)
            print("Yes")
        }else{
            print("没有相关动画")
        }
    }
    func startSpeechRecognition(){
        //获得允许
        requestPermission()
        //记录
        startAudioRecoding()
        //识别
        speechRecognize()
    }
    func requestPermission(){
        SFSpeechRecognizer.requestAuthorization { (authorizationStatus) in
            if(authorizationStatus  == .authorized){
                print("允许")
            }else if(authorizationStatus  == .denied){
                print("拒绝")
            }else if(authorizationStatus == .notDetermined){
                print("等待您的决定")
            }else if(authorizationStatus == .restricted){
                print("无法启用")
            }
        }
    }
    func startAudioRecoding(){
        //创造输入节点
        let node = audioEngine.inputNode
        let recordingFormate = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormate) { (buffer, _) in
            self.speechRequest.append(buffer)
        }
        //启动引擎
        
        do{
            //配置音频会话为从麦克风录制
            try audioSession.setCategory(.record,mode: .measurement,options: .duckOthers)
            try audioSession.setActive(true,options: .notifyOthersOnDeactivation)
            audioEngine.prepare()
            try audioEngine.start()
        }
        catch{
            
        }
        
    }
    func speechRecognize(){
        guard let speechRecognizer = SFSpeechRecognizer()else{
            print("语音识别不可用")
            return
        }
        if (speechRecognizer.isAvailable == false){
            print("无法正常工作")
        }
        var count = 0
        speechTask = speechRecognizer.recognitionTask(with: speechRequest, resultHandler: { (result, error) in
            count += 1
            if(count == 1){
                guard let result = result else {
                    return
                }
                let recognizedText = result.bestTranscription.segments.last
                self.rebotMove(direction: recognizedText!.substring)
                print(recognizedText!.substring)
            }else if(count>=3){
                count = 0
            }
        })
    }
}
