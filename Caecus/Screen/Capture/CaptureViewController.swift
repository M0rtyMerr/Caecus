//
//  CaptureViewController.swift
//  SceneTextRecognitioniOS
//
//  Created by Khurram Shehzad on 09/08/2017.
//  Copyright © 2017 devcrew. All rights reserved.
//

import AVFoundation
import UIKit
import Vision
import RxSwift
import RxCocoa
import TesseractOCR
import Reusable

class CaptureViewController: UIViewController, StoryboardBased {
    @IBOutlet private var cameraView: CameraView!
    @IBOutlet private var resultTextView: UITextView!
    @IBOutlet private var captureButton: UIButton!
    private let disposeBag = DisposeBag()
    private let resultText = BehaviorRelay<String>(value: "")
    private var textDetectionRequest: VNDetectTextRectanglesRequest?
    private let session = AVCaptureSession()
    private var textObservations = [VNTextObservation]()
    private var tesseract = G8Tesseract(language: "eng", engineMode: .lstmOnly)
    private var font = CTFontCreateWithName("Helvetica" as CFString, 18, nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tesseract?.pageSegmentationMode = .sparseText
        tesseract?.charWhitelist = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890()!?.,"
        if isAuthorized() {
            configureTextDetection()
            configureCamera()
        }
        bindOutlets()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CaptureViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        var imageRequestOptions = [VNImageOption: Any]()
        if let cameraData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
            imageRequestOptions[.cameraIntrinsics] = cameraData
        }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 6)!, options: imageRequestOptions)
        do {
            try imageRequestHandler.perform([textDetectionRequest!])
        }
        catch {
            print("Error occured \(error)")
        }
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let transform = ciImage.orientationTransform(for: CGImagePropertyOrientation(rawValue: 6)!)
        ciImage = ciImage.transformed(by: transform)
        let size = ciImage.extent.size
        var recognizedText = [String]()
        for textObservation in textObservations {
            guard let rects = textObservation.characterBoxes else {
                continue
            }
            var xMin = CGFloat.greatestFiniteMagnitude
            var xMax: CGFloat = 0
            var yMin = CGFloat.greatestFiniteMagnitude
            var yMax: CGFloat = 0
            for rect in rects {
                xMin = min(xMin, rect.bottomLeft.x)
                xMax = max(xMax, rect.bottomRight.x)
                yMin = min(yMin, rect.bottomRight.y)
                yMax = max(yMax, rect.topRight.y)
            }
            let imageRect = CGRect(x: xMin * size.width, y: yMin * size.height, width: (xMax - xMin) * size.width, height: (yMax - yMin) * size.height)
            guard let cgImage = CIContext(options: nil).createCGImage(ciImage, from: imageRect) else {
                continue
            }
            let uiImage = UIImage(cgImage: cgImage)
            tesseract?.image = uiImage
            tesseract?.recognize()
            guard var text = tesseract?.recognizedText else {
                continue
            }
            text = text.trimmingCharacters(in: CharacterSet.newlines)
            recognizedText.append(text)
        }
        resultText.accept(recognizedText.joined(separator: " "))
    }
}

// MARK: - Private
private extension CaptureViewController {
    func bindOutlets() {
        resultText
            .throttle(0.3, latest: false, scheduler: MainScheduler.instance)
            .asDriver(onErrorJustReturn: "")
            .drive(resultTextView.rx.text)
            .disposed(by: disposeBag)
        
        captureButton.rx.tap
            .bind { [unowned self] in
                let translateAndSayViewController = TranslateAndSayViewController.instantiate().then {
                    $0.reactor = TranslateAndSayReactor(
                        text: self.resultText.value, credentialsService: CredentialsServiceImpl()
//                        text: "Hello world", credentialsService: CredentialsServiceImpl()
                    )
                }
                self.navigationController?.pushViewController(translateAndSayViewController, animated: true)
            }
            .disposed(by: disposeBag)
    }
    
    func configureTextDetection() {
        textDetectionRequest = VNDetectTextRectanglesRequest(completionHandler: handleDetection)
        textDetectionRequest?.reportCharacterBoxes = true
    }
    
    func handleDetection(request: VNRequest, error: Error?) {
        guard let textResults = request.results?.compactMap({ $0 as? VNTextObservation }), !textResults.isEmpty else { return }
        textObservations = textResults
    }
    
    func isAuthorized() -> Bool {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        switch authorizationStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.configureTextDetection()
                        self.configureCamera()
                    }
                }
            }
            return true
        case .authorized:
            return true
        case .denied, .restricted: return false
        }
    }
    
    func configureCamera() {
        cameraView.session = session
        
        let cameraDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back)
        var cameraDevice: AVCaptureDevice?
        for device in cameraDevices.devices {
            if device.position == .back {
                cameraDevice = device
                break
            }
        }
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: cameraDevice!)
            if session.canAddInput(captureDeviceInput) {
                session.addInput(captureDeviceInput)
            }
        }
        catch {
            print("Error occured \(error)")
            return
        }
        session.sessionPreset = .high
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "Buffer Queue", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil))
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }
        cameraView.videoPreviewLayer.videoGravity = .resize
        session.startRunning()
    }
}
