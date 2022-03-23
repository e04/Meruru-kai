//
//  AppDelegate.swift
//  Meruru
//
//  Created by castaneai on 2019/04/06.
//  Copyright © 2019 castaneai. All rights reserved.
//

import VLCKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSComboBoxDelegate, VLCMediaPlayerDelegate {
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var videoWrapView: NSView!
    @IBOutlet weak var channelsMenu: NSMenu!
    @IBOutlet weak var preferenceWindow: NSWindow!
    @IBOutlet weak var mirakurunURL: NSTextField!
    @IBOutlet weak var videoURL: NSTextField!
    @IBOutlet weak var spinner: NSProgressIndicator!
    
    var mirakurun: MirakurunAPI!
    var player: VLCMediaPlayer!
    var services: [Service] = []
    var currentService: Service?
    var selectedService: Service?
    var receivedServiceId: Int?
    var timer = Timer()

    @IBAction func onClickPreference(_ sender: Any) {
        preferenceWindow.setIsVisible(true)
        mirakurunURL.stringValue = AppConfig.shared.currentData?.mirakurunPath ?? ""
        videoURL.stringValue = AppConfig.shared.currentData?.videoURL ?? ""
    }
    
    @IBAction func onClickSavePreference(_ sender: Any) {
        AppConfig.shared.currentData?.mirakurunPath = mirakurunURL.stringValue
        AppConfig.shared.currentData?.videoURL = videoURL.stringValue
        preferenceWindow.setIsVisible(false)
        self.selectService(selectedService: self.services[0])
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        initUI()
        
        connectToMirakurun()
        
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true, block: { (timer) in
            if let service = self.currentService {
                self.fetchPrograms(selectedService: service)
            }
        })
    }
    
    func connectToMirakurun() {
        guard let mirakurunPath = AppConfig.shared.currentData?.mirakurunPath else {
            preferenceWindow.setIsVisible(true)
            return
        }
        
        mirakurun = MirakurunAPI(baseURL: URL(string: mirakurunPath + "/api")!)
        mirakurun.fetchStatus { result in
            switch result {
            case .success:
                self.mirakurun.fetchServices { result in
                    switch result {
                    case .success(let services):
                        self.services = services
                        // ワンセグなどを除去
                        self.services = self.services.enumerated().compactMap{
                            if $0 == 0 {
                                return $1
                            }
                            if self.services[$0].networkId != self.services[$0 - 1].networkId {
                                return $1
                            }
                            return nil
                        }
                        DispatchQueue.main.async {
                            self.services.forEach { (service) in
                                self.channelsMenu.addItem(withTitle: service.name, action: #selector(self.onClickChannelMenuItem), keyEquivalent: "")
                            }
                        }
                        
                        if !self.openReceivedService() {
                            self.selectService(selectedService: self.services[0])
                        }
                        
                    case .failure(let error):
                        self.showErrorAndQuit(error: error)
                    }
                }
            case .failure(let error):
                debugPrint(error)
                self.showErrorAndQuit(error: NSError(domain: "failed to get Mirakurun's status (mirakurunPath: \(mirakurunPath))", code: 0))
            }
        }
    }
    
    
    func application(_ application: NSApplication, open urls: [URL]) {
        let url = urls[0]
        let id = Int(url.path.components(separatedBy: "/")[4])
        
        self.receivedServiceId = id
        openReceivedService()
    }
    
    func openReceivedService() -> Bool {
        guard let id = self.receivedServiceId else {
            return false
        }
        let targetService = self.services.first{$0.id == id}
        guard let service = targetService else {
            return false
        }
        self.selectService(selectedService: service)
        return true
    }
    
    func showErrorAndQuit(error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
        NSApplication.shared.terminate(self)
    }
    
    func initUI() {
        let videoView = VLCVideoView(frame: NSRect(x: 0, y: 0, width: videoWrapView.frame.width, height: videoWrapView.frame.height))
        videoView.autoresizingMask = [.width, .height]
        videoWrapView.addSubview(videoView)

        player = VLCMediaPlayer(videoView: videoView)
        player.delegate = self
        self.spinner.startAnimation(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func selectService(selectedService: Service) {
        self.spinner.startAnimation(self)
        currentService = selectedService
        fetchPrograms(selectedService: selectedService)
        DispatchQueue.main.async {
            self.player.stop()
            guard let videoURL = self.mirakurun.getStreamURL(service: selectedService) else {
                self.preferenceWindow.setIsVisible(true)
                return
            }
            let media = VLCMedia(url: videoURL)
            self.player.media = media
            self.player.play()
        }
    }
    
    func fetchPrograms(selectedService: Service) {
        mirakurun.fetchPrograms(service: selectedService) { result in
            switch result {
            case .success(let programs):
                guard let program = self.getNowProgram(programs: programs) else {
                    return
                }
                DispatchQueue.main.async {
                    self.window?.title = "\(program.name) - \(selectedService.name)"
                }
            case .failure(_):
                return
            }
        }
    }
    
    func getNowProgram(programs: [Program]) -> Program? {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        return programs.first { $0.startAt...($0.startAt + $0.duration) ~= now }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        player?.stop()
        do {
            try AppConfig.shared.save()
        } catch let err {
            let alert = NSAlert(error: err)
            alert.runModal()
        }
    }
    
    private final func fixVideoSize(){
        let previousFrame = self.window.frame
        let frame = NSRect(x: previousFrame.minX, y: previousFrame.minY, width: previousFrame.width + 0.1, height: previousFrame.height)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.window.setFrame(frame, display: true, animate: false)
        }
    }
    
    func mediaPlayerStateChanged(_ aNotification: Notification!) {
        print(self.player.state.rawValue)
        if self.player.state == .esAdded {
            fixVideoSize()
            self.spinner.stopAnimation(self)
        }
    }
    
    @objc func onClickChannelMenuItem(_ sender: NSMenuItem) {
        let name = sender.title
        let selectedChannelIndex = self.services.firstIndex { (service) -> Bool in
            return service.name == name
        }
        self.selectService(selectedService: self.services[selectedChannelIndex!])
    }
}

