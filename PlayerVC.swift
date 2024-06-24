//
//  PlayerVC.swift
//  HardeX
//
//  Created by SteemeX on 30/11/2017.
//  Copyright © 2017 SteemeX. All rights reserved.
//

import UIKit
import AVFoundation
import NotificationCenter
import SystemConfiguration
import MediaPlayer

class PlayerVC: UIViewController {
// Variables
    var qPlayer = AVQueuePlayer()
    var offlineURLs = [URL]()
    var playQue = [URL]()
    var randomMode = true
    var updater : CADisplayLink! = nil
    var selectedTrack = -1
    var paused = true
    var laterQue = 0
// Constants
    let commandCenter = MPRemoteCommandCenter.shared
    let mpic = MPNowPlayingInfoCenter.default()
    let theSession = AVAudioSession.sharedInstance()
    let randomPercentage: Float = 70
// Outlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var outletBtnPlayPause: UIButton!
    @IBOutlet weak var outletBtnPlayMode: UIButton!
    @IBOutlet weak var outletSlider: UISlider!
    @IBOutlet weak var lblCurrentTrackTime: UILabel!
    @IBOutlet weak var lblCurrentTrackTimeTotal: UILabel!
    @IBOutlet weak var outletSliderView: UIView!
// Buttons
    @IBAction func btnPlayPause(_ sender: Any) { playPause() }
    @IBAction func btnPlayMode(_ sender: Any) { changePlayMode() }
    @IBAction func btnSlider(_ sender: Any) {
        lblCurrentTrackTime.text = getCurrentItemStringSeconds()
        let sec = Double(outletSlider.value)
        let cmt = CMTime(seconds: sec, preferredTimescale: 1)
        qPlayer.seek(to: cmt)
    }
    @IBAction func btnNext(_ sender: Any) {
        if offlineURLs.isEmpty { return }
        if offlineURLs.count == 1 {
            playTrack(url: offlineURLs.first!)
            return
        }
        let percent = Float(offlineURLs.count) / 100
        let percent70 = Int(percent * randomPercentage)
        if playQue.count >= percent70 {
            playQue = Array(playQue.dropFirst(playQue.count / 2))
        }
            if randomMode {
                var urls = offlineURLs
                urls = urls.filter { !playQue.contains($0) }
                let randomNumber = Int(arc4random_uniform(UInt32(urls.count)))
                let randomTrack = urls[randomNumber]
                playTrack(url: randomTrack)
            } else {
                if !playQue.isEmpty {
                    let currentTrack = playQue.last
                    let index = offlineURLs.index(of: currentTrack!)! + 1
                    playTrack(url: offlineURLs[index])
                } else {
                    playTrack(url: offlineURLs.first!)
                }
                
//                if index >= offlineURLs.count {
//                    playTrack(url: offlineURLs.first!)
//                } else {
//                    playTrack(url: offlineURLs[index])
//                }
            }
    }
    @IBAction func btnPrevious(_ sender: Any) {
        if playQue.count > 1 {
            playQue.removeLast()
            playTrack(url: playQue.last!, nextSeek: false)
        } else if playQue.count == 1 {
            playTrack(url: playQue.first!)
        }

    }
// View logic
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeCommandCenter()
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleInterruption(notification:)), name: NSNotification.Name.AVAudioSessionInterruption, object: theSession)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleHeadset(notification:)), name: NSNotification.Name.AVAudioSessionRouteChange, object: theSession)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        tableView.rowHeight = 44
        loadOfflineURLsFromFileManager()
        if offlineURLs.isEmpty { changeTabBarItem(zeroOrOne: 1) }
        tableView.reloadData()
        if selectedTrack == -1 { return }
        let index = IndexPath(row: selectedTrack, section: 0)
        tableView.selectRow(at: index, animated: false, scrollPosition: .middle)
    }
}
// Button's fuctions
extension PlayerVC {
    func playPause() {
        if offlineURLs.isEmpty { return }
        if qPlayer.rate > 0 {
            outletBtnPlayPause.setImage(#imageLiteral(resourceName: "plPause"), for: .normal)
            qPlayer.pause()
            paused = true
        } else {
            outletBtnPlayPause.setImage(#imageLiteral(resourceName: "pause"), for: .normal)
            if qPlayer.rate == 0 && !offlineURLs.isEmpty {
                if qPlayer.rate == 0 && !playQue.isEmpty {
                    qPlayer.play()
                    return
                }
                if randomMode {
                    let randomNumber = Int(arc4random_uniform(UInt32(offlineURLs.count)))
                    let randomTrack = offlineURLs[randomNumber]
                    playTrack(url: randomTrack)
                } else {
                    playTrack(url: offlineURLs.first!)
                }
            }
        }
    }
    func changePlayMode() {
        randomMode = !randomMode
        if randomMode {
            outletBtnPlayMode.setImage(#imageLiteral(resourceName: "random"), for: .normal)
        } else {
            outletBtnPlayMode.setImage(#imageLiteral(resourceName: "standart"), for: .normal)
        }
    }
}
// Player logic ///////////////////////////
extension PlayerVC {
    func playTrack(url: URL, nextSeek: Bool? = true) {
//        if laterQue > 0 {
//            playTrack(url: playQue.last!)
//            laterQue -= 1
//        }
        qPlayer = AVQueuePlayer(url: url)
        selectedTrack = offlineURLs.index(of: url)!
        outletSlider.isEnabled = true
        paused = false
        setInfoToLockScreen(url: url)
        outletSlider.maximumValue = Float(getCurrentItemTotalSeconds())
        lblCurrentTrackTimeTotal.text = getCurrentItemTotalStringSeconds()
        selectedTrack = offlineURLs.index(of: url)!
        updater = CADisplayLink(target: self, selector: #selector(self.trackAudio))
        updater.preferredFramesPerSecond = 1
        updater.add(to: RunLoop.current, forMode: RunLoopMode.commonModes)
        if nextSeek! { playQue.append(url) }
        NotificationCenter.default.addObserver(self, selector: #selector(self.btnNext(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: qPlayer.currentItem)
        qPlayer.play()
        outletBtnPlayPause.setImage(#imageLiteral(resourceName: "pause"), for: .normal)
        let index = IndexPath(row: offlineURLs.index(of: url)!, section: 0)
        tableView.selectRow(at: index, animated: false, scrollPosition: .middle)
        //if laterQue > 0 { laterQue -= 1 }
    }
}
// Table
extension PlayerVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = Bundle.main.loadNibNamed("MainCell", owner: self, options: nil)?.first as! MainCell
        cell.lblInfo.text = getTrackNameFromURL(url: offlineURLs[indexPath.row])
        let bgColorView = UIView()
        bgColorView.backgroundColor = UIColor.gray //make good blue
        cell.selectedBackgroundView = bgColorView
        return cell
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return offlineURLs.count
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        playTrack(url: offlineURLs[indexPath.row])
        outletBtnPlayPause.setImage(#imageLiteral(resourceName: "pause"), for: .normal)
    }
    func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
        let playNext = UITableViewRowAction(style: .normal, title: "Play next") { action, index in
//            ///////////////////////////
         
            print(self.offlineURLs[editActionsForRowAt.row])
            
//                let index = IndexPath(row: self.playQue.count, section: 0)
//                tableView.selectRow(at: index, animated: false, scrollPosition: .middle)
            

            
            //self.laterQue += 1
            //self.playQue.append(self.offlineURLs[editActionsForRowAt.row])
          //  let index = IndexPath(row: editActionsForRowAt.row, section: 0)
           // tableView.selectRow(at: index, animated: false, scrollPosition: .middle)
        }
        playNext.backgroundColor = .green
        let deleteTrack = UITableViewRowAction(style: .normal, title: "Delete") { action, index in
            let index = self.playQue.index(of: self.offlineURLs[editActionsForRowAt.row])
            self.removeFile(name: self.offlineURLs[editActionsForRowAt.row].lastPathComponent)
            self.offlineURLs.remove(at: editActionsForRowAt.row)
            if index != nil {
                self.playQue.remove(at: index!)
            }
            DispatchQueue.main.async {
                tableView.reloadData()
//                let index = IndexPath(row: self.playQue.count, section: 0)
//                tableView.selectRow(at: index, animated: false, scrollPosition: .middle)
            }
        }
        deleteTrack.backgroundColor = .red
    
        
        return [deleteTrack]//, playNext]
    }
}
// Tools
extension PlayerVC {
    @objc func nothing() {
    }
    @objc func setLockscreenSlider() {
        print("Trying to set lockscreen slider and timing")
        //print(mpic.playbackState.rawValue)
    }
    func setInfoToLockScreen(url: URL) {
        let fullName = getTrackNameFromURL(url: url)
        var trackName = ""
        var artist = ""
        if fullName.range(of:" - ") != nil {
            var components = fullName.components(separatedBy: " - ")
            trackName = components[0]
            artist = components[1]
        } else {
            trackName = fullName
            artist = ""
        }
        mpic.nowPlayingInfo = [
            MPMediaItemPropertyTitle: trackName,
            MPMediaItemPropertyArtist: artist]
    }
    @objc func handleInterruption(notification: NSNotification) {
        guard let value = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue,
            let interruptionType =  AVAudioSessionInterruptionType(rawValue: value)
            else {
                print("notification.userInfo?[AVAudioSessionInterruptionTypeKey]", notification.userInfo?[AVAudioSessionInterruptionTypeKey]! ?? print("Interruption error!"))
                return }
        print(interruptionType.rawValue)
        if interruptionType.rawValue == 1 {
            qPlayer.pause()
            paused = false
            outletBtnPlayPause.setImage(#imageLiteral(resourceName: "plPause"), for: .normal)
        }
        if interruptionType.rawValue == 0 && paused {
            qPlayer.play()
            outletBtnPlayPause.setImage(#imageLiteral(resourceName: "pause"), for: .normal)
        }
    }
    @objc func handleHeadset(notification: NSNotification) {
        let event = (notification.userInfo!["AVAudioSessionRouteChangeReasonKey"]! as! Int)
        if event == 2 {
            qPlayer.pause()
            paused = true
            DispatchQueue.main.async {
                self.outletBtnPlayPause.setImage(#imageLiteral(resourceName: "plPause"), for: .normal)
            }
        }
    }
    func changeTabBarItem(zeroOrOne: Int) {
        let controllerIndex: Int = zeroOrOne
        let tabBarController: UITabBarController? = self.tabBarController
        let fromView: UIView? = tabBarController?.selectedViewController?.view
        let toView: UIView? = tabBarController?.viewControllers?[controllerIndex].view
        // Transition using a page curl.
        UIView.transition(from: fromView ?? UIView(), to: toView ?? UIView(), duration: 0.0, options: controllerIndex > (tabBarController?.selectedIndex)! ? .showHideTransitionViews : .showHideTransitionViews, completion: {(_ finished: Bool) -> Void in
            if finished {
                tabBarController?.selectedIndex = controllerIndex
            }
        })
    }
    func getTrackNameFromURL(url: URL) -> String {
        let lastPathComponent = url.lastPathComponent.replacingOccurrences(of: "_", with: " ", options: .literal, range: nil)
        let trackName = (lastPathComponent as NSString).replacingOccurrences(of: ".mp3", with: "")
        return trackName
    }
    @objc func trackAudio(_ sender: Any) {
        lblCurrentTrackTime.text = getCurrentItemStringSeconds()
        outletSlider.value = Float(getCurrentItemSeconds())
    }
    func initializeCommandCenter() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared
        commandCenter().seekBackwardCommand.isEnabled = true
        commandCenter().seekForwardCommand.addTarget(self, action: #selector(self.nothing))
        commandCenter().seekForwardCommand.isEnabled = true
        commandCenter().seekBackwardCommand.addTarget(self, action: #selector(self.nothing))
        commandCenter().nextTrackCommand.isEnabled = true
        commandCenter().nextTrackCommand.addTarget(self, action: #selector(self.btnNext(_:)))
        commandCenter().playCommand.isEnabled = true
        commandCenter().playCommand.addTarget(self, action: #selector(self.btnPlayPause(_:)))
        commandCenter().pauseCommand.isEnabled = true
        commandCenter().pauseCommand.addTarget(self, action: #selector(self.btnPlayPause(_:)))
        commandCenter().previousTrackCommand.isEnabled = true
        commandCenter().previousTrackCommand.addTarget(self, action: #selector(self.btnPrevious(_:)))
        commandCenter().changePlaybackPositionCommand.isEnabled = true
        //commandCenter().changePlaybackPositionCommand.addTarget(self, action: #selector(self.setLockscreenSlider))
    }
}
// Data manager
extension PlayerVC {
    func loadOfflineURLsFromFileManager() {
        let documentsURL =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: [])
            offlineURLs = [URL]()
            if directoryContents.isEmpty {
                print("No files found with loadOfflineURLsFromFileManager())")
                // Empty playlist logic here
                return
            }
            for item in directoryContents {
                offlineURLs.append(item)
            }
        } catch { print("Error in loadOfflineURLsFromFileManager()!") }
    }
    func removeFile(name: String) {
        let documentsURL =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            try FileManager.default.removeItem(at: documentsURL.appendingPathComponent(name))
        } catch {
            print("Error loading files with FileManager: \(error.localizedDescription)")
        }
    }
    func loadAllFilesFromFileManager() {
        let documentsURL =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: [])
            if directoryContents.isEmpty {
                print("No files found with loadAllFilesFromFileManager()")
                return
            }
            if !directoryContents.isEmpty { print("Files found: \(directoryContents.count)") }
            for item in directoryContents {
                print(item)
            }
        } catch { print("Error in loadAllFilesFromFileManager()!") }
    }
}
// Time Handler
extension PlayerVC {
    func getCurrentItemStringSeconds() -> String {
        let currentSeconds = Int(CMTimeGetSeconds(qPlayer.currentTime()))
        var str = ""
        if currentSeconds > 60 {
            let minutes = String(currentSeconds / 60)
            var seconds = String(currentSeconds % 60)
            if Int(seconds)! < 10 { seconds = "0" + seconds }
            str = minutes + ":" + seconds
        } else {
            let minutes = "0"
            var seconds = String(currentSeconds % 60)
            if Int(seconds)! < 10 { seconds = "0" + seconds }
            str = minutes + ":" + seconds
            
        }
        return str
    }
    func getCurrentItemTotalSeconds() -> Int {
        return Int(CMTimeGetSeconds(qPlayer.currentItem!.asset.duration))
    }
    func getCurrentItemSeconds() -> Int {
        return Int(CMTimeGetSeconds(qPlayer.currentTime()))
    }
    func getCurrentItemTotalStringSeconds() -> String {
        let currentSeconds = Int(CMTimeGetSeconds(qPlayer.currentItem!.asset.duration))
        var str = ""
        if currentSeconds > 60 {
            let minutes = String(currentSeconds / 60)
            var seconds = String(currentSeconds % 60)
            if Int(seconds)! < 10 { seconds = "0" + seconds }
            str = minutes + ":" + seconds
        } else {
            let minutes = "0"
            var seconds = String(currentSeconds % 60)
            if Int(seconds)! < 10 { seconds = "0" + seconds }
            str = minutes + ":" + seconds
        }
        return str
        
    }
}










