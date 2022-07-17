//
//  CameraSession.swift
//  FishEye
//
//  Created by Roman on 17.07.2022.
//

import AVFoundation
import Combine

final class CameraSession: ObservableObject {

    // MARK: - Session State
    @Published var state: State = .permissions(AVCaptureDevice.authorizationStatus(for: .video))

    private let sessionQueue: DispatchQueue = .init(label: "com.andrykevych.fisheye.sessionQueue", qos: .userInitiated)
    private let sampleBufferQueue: DispatchQueue = .init(label: "com.andrykevych.fisheye.sampleBufferQueue", qos: .userInteractive)
    private lazy var session: AVCaptureSession = .init()

    // MARK: - Session IO
    private var deviceInput: AVCaptureDeviceInput!
    private var dataOutput: AVCaptureVideoDataOutput!
    private var cancellables: Set<AnyCancellable> = .init()
    private let sampleBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate

    init(sampleBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
        self.sampleBufferDelegate = sampleBufferDelegate
    }
}

extension CameraSession {

    enum Error: Swift.Error {
        case noCameraDeviceFound
        case cantCreateDeviceInput(Swift.Error)
        case cantAddInput(AVCaptureDeviceInput)
        case cantAddOutput(AVCaptureVideoDataOutput)
        case cantAddConnection(AVCaptureConnection)
        case unsupportedPixelFormat(OSType)
    }

    enum State {
        case permissions(AVAuthorizationStatus)
        case setup
        case idle
        case started
        case failure(Error)
    }

    func start() {
        sessionQueue.async { [unowned self] in
            switch state {
            case .failure:
                setup()
            case .idle:
                session.startRunning()
            case .setup:
                break
            case .started:
                break
            case .permissions(let status):
                switch status {
                case .authorized:
                    setup()
                default:
                    break
                }
            }
        }
        cancellables.insert(
            session.publisher(for: \.isRunning, options: [.new]).receive(on: DispatchQueue.main).sink { [weak self] in
                if $0 {
                    self?.publish(.started)
                } else {
                    self?.publish(.idle)
                }
            }
        )
    }

    func requestPermissions() async {
        if await AVCaptureDevice.requestAccess(for: .video) {
            publish(.permissions(.authorized))
        } else {
            publish(.permissions(AVCaptureDevice.authorizationStatus(for: .video)))
        }

    }

    private func setup() {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            publish(.failure(.noCameraDeviceFound))
            return
        }
        do {
            deviceInput = try AVCaptureDeviceInput(device: camera)
        } catch {
            publish(.failure(.cantCreateDeviceInput(error)))
            return
        }
        guard session.canAddInput(deviceInput) else {
            publish(.failure(.cantAddInput(deviceInput)))
            return
        }
        session.addInputWithNoConnections(deviceInput)
        dataOutput = AVCaptureVideoDataOutput()
        let pixelFormat = kCVPixelFormatType_32BGRA
        guard dataOutput.availableVideoPixelFormatTypes.contains(pixelFormat) else {
            publish(.failure(.unsupportedPixelFormat(pixelFormat)))
            return
        }
        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: pixelFormat]
        dataOutput.alwaysDiscardsLateVideoFrames = true

        guard session.canAddOutput(dataOutput) else {
            publish(.failure(.cantAddOutput(dataOutput)))
            return
        }
        session.addOutputWithNoConnections(dataOutput)
        dataOutput.setSampleBufferDelegate(sampleBufferDelegate, queue: sampleBufferQueue)

        guard let videoPort = deviceInput.ports(for: .video,
                                                sourceDeviceType: camera.deviceType,
                                                sourceDevicePosition: camera.position).first else {
            publish(.failure(.cantAddInput(deviceInput)))
            return
        }

        let connection = AVCaptureConnection(
            inputPorts: [videoPort],
            output: dataOutput
        )
        guard session.canAddConnection(connection) else {
            publish(.failure(.cantAddConnection(connection)))
            return
        }
        session.addConnection(connection)
        connection.isEnabled = true
        connection.videoOrientation = .portrait
        connection.preferredVideoStabilizationMode = .standard

        publish(.idle)
    }

    private func publish(_ newValue: State) {
        DispatchQueue.main.async { [weak self] in
            self?.state = newValue
        }
    }
}
