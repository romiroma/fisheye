//
//  CameraSessionView.swift
//  FishEye
//
//  Created by Roman on 17.07.2022.
//

import SwiftUI
import AVFoundation

struct CameraSessionView: View {

    @ObservedObject var session: CameraSession

    var body: some View {
        switch session.state {
        case .failure(let error):
            Text(error.localizedDescription).foregroundColor(.red)
        case .permissions(let aVAuthorizationStatus):
            switch aVAuthorizationStatus {
            case .notDetermined:
                Button("Request Permissions") {
                    Task {
                        await session.requestPermissions()
                    }
                }
            case .authorized:
                Text("Thumbs up emoji here").onAppear {
                    session.start()
                }
            case .denied:
                Text("Permission to camera denied by user.")
            default:
                Text("This case is handled.")
            }
        case .setup:
            ProgressView("Setting Up...")
        case .idle:
            ProgressView().onAppear() {
                session.start()
            }
        case .started:
            EmptyView()
        }
    }
}
