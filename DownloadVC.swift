//
//  DownloadVC.swift
//  HardeX
//
//  Created by SteemeX on 30/11/2017.
//  Copyright © 2017 SteemeX. All rights reserved.
//

import UIKit

class DownloadVC: UIViewController {
// Variables
    var downloadList = [URL]()
    var offlineURLs = [URL]()
    var downloadAllList = [URL]()
    var tempTrackName = ""
    var loadingLock = false
    var downloadingItem = URL(string: "")
    var task = URLSessionDownloadTask()
// Constants
    let baseURL = URL(string: "http://steemex.ru/hardex/")
// Outlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var viewLoading: UIView!
    @IBOutlet weak var viewLoadingItemInfo: UIView!
    @IBOutlet weak var viewDownloadAll: UIView!
    @IBOutlet weak var viewCancelDownloading: UIView!
    @IBOutlet weak var downloadProgress: UIProgressView!
    @IBOutlet weak var lblDownloaded: UILabel!
    @IBOutlet weak var lblMbTotal: UILabel!
// Buttons
    @IBAction func btnDownloadAll(_ sender: Any) {
        downloadAll()
    }
    @IBAction func btnCancelDownloading(_ sender: Any) {
        task.cancel()
        loadOfflineURLsFromFileManager()
        tableView.reloadData()
        downloadingItem = URL(string: "")
        tableView.reloadData()
        viewLoadingItemInfo.isHidden = true
        loadingLock = false
        downloadAllList = [URL]()
        viewCancelDownloading.isHidden = true
        if availableDownloads() { viewDownloadAll.isHidden = false }
    }
// View Logic
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    override func viewDidAppear(_ animated: Bool) {
        // viewCancel и нижний view не должны появляться если переходим с playerVC
         viewDownloadAll.isHidden = true
         viewCancelDownloading.isHidden = true
        tableView.rowHeight = 44
        loadOfflineURLsFromFileManager()
        viewLoading.isHidden = false
        Source.getNewTracks() {
            downloadList in
            self.downloadList = downloadList
            //sleep(5)
            DispatchQueue.main.async {
                self.downloadList = self.sortByDownloaded(downloadList: self.downloadList)
                self.tableView.reloadData()
                self.viewLoading.isHidden = true
                if self.availableDownloads() {
                    self.viewDownloadAll.isHidden = false
                }
            }
        }
    }
}
// Table
extension DownloadVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = Bundle.main.loadNibNamed("MainCell", owner: self, options: nil)?.first as! MainCell
        cell.lblInfo.text = getTrackNameFromURL(url: downloadList[indexPath.row])
        cell.imgView.image = #imageLiteral(resourceName: "download")
        if downloadingItem == downloadList[indexPath.row] {
            cell.imgView.isHidden = true
            cell.activityIndicator.isHidden = false
        } else {
            cell.activityIndicator.isHidden = true
        }
        if !offlineURLs.isEmpty {
            for item in offlineURLs {
                if item.lastPathComponent == downloadList[indexPath.row].lastPathComponent {
                    cell.imgView.image = #imageLiteral(resourceName: "downloaded")
                    break
                }
            }
        }
        return cell
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return downloadList.count
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        downloadTrack(url: downloadList[indexPath.row])
        print("delegating")
        //changeTabBarItem(zeroOrOne: 0)
    }
}
// Tools
extension DownloadVC {
    func getTrackNameFromURL(url: URL) -> String {
        let lastPathComponent = url.lastPathComponent.replacingOccurrences(of: "_", with: " ", options: .literal, range: nil)
        let trackName = (lastPathComponent as NSString).replacingOccurrences(of: ".mp3", with: "")
        return trackName
    }
    func sortByDownloaded(downloadList: [URL]) -> [URL] {
        var downloadedURLs = [URL]()
        for offlineURL in offlineURLs {
            let offlineUrlAsDownloadedItem = baseURL?.appendingPathComponent(offlineURL.lastPathComponent)
            downloadedURLs.append(offlineUrlAsDownloadedItem!)
        }
        let result = downloadList.filter { element in
            return !downloadedURLs.contains(element)
        }
        return result + downloadedURLs
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

}
// Download Manager
extension DownloadVC: URLSessionDownloadDelegate {
    func downloadAll() {
        var downloaded = [String]()
        var offline = [String]()
        for item in offlineURLs {
            downloaded.append(item.lastPathComponent)
        }
        for item in downloadList {
            offline.append(item.lastPathComponent)
        }
        let itemsForDownload = offline.filter { !downloaded.contains($0) }

        for item in itemsForDownload {
            let itemChecking = baseURL?.appendingPathComponent(item)
            if downloadList.contains(itemChecking!) {
                downloadAllList.append(itemChecking!)
                print(itemChecking!)
            }
            print(downloadAllList.count)
        }
        if itemsForDownload.isEmpty { return }
        downloadTrack(url: downloadAllList.first!)
        print("tracks to download:  \(downloadAllList.count)")
        print("downloading and removing: \(downloadAllList.first!)")
        downloadAllList.removeFirst()
        print("tracks to download:  \(downloadAllList.count)")
        viewDownloadAll.isHidden = true
    }
    func availableDownloads() -> Bool {
        var downloaded = [String]()
        var offline = [String]()
        for item in offlineURLs {
            downloaded.append(item.lastPathComponent)
        }
        for item in downloadList {
            offline.append(item.lastPathComponent)
        }
        let itemsForDownload = offline.filter { !downloaded.contains($0) }
        if itemsForDownload.isEmpty {
            return false
        } else {
            return true
        }
        
    }
    func downloadTrack(url: URL) {
        if loadingLock { return }
        downloadingItem = url
        tableView.reloadData()
        lblDownloaded.text = String("")
        lblMbTotal.text = String("")
        downloadProgress.progress = 0
        print("Preparing to download...")
        tempTrackName = url.lastPathComponent
        for item in offlineURLs {
            if url.lastPathComponent == item.lastPathComponent {
                print("File already exist!")
                downloadingItem = URL(string: "")
                tableView.reloadData()
                return
            }
        }
        print("Downloading...")
        viewCancelDownloading.isHidden = false
        viewLoadingItemInfo.isHidden = false
        loadingLock = true
        let config = URLSessionConfiguration.background(withIdentifier: url.absoluteString)
        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        let request = URLRequest(url: url)
        task = session.downloadTask(with: request)
        task.resume()
    }
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            let documentsURL =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsURL.appendingPathComponent(tempTrackName)
            do {
                try FileManager.default.moveItem(at: location, to: destinationURL)
                loadOfflineURLsFromFileManager()
                tableView.reloadData()
                downloadingItem = URL(string: "")
                tableView.reloadData()
                viewLoadingItemInfo.isHidden = true
                loadingLock = false
                if !downloadAllList.isEmpty {
                    print("tracks to download: \(downloadAllList.count)")
                    downloadTrack(url: downloadAllList.first!)
                    print("downloaded and removed from downloadlist\(downloadAllList.first!)")
                    downloadAllList.removeFirst()    ////////
                    print("tracks to download: \(downloadAllList.count)")
                } else {
                    viewCancelDownloading.isHidden = true
                }
                if availableDownloads() {
                    viewDownloadAll.isHidden = false
                } else {
                    viewDownloadAll.isHidden = true
                }
                //playerVC.tableView.reloadData()
            } catch let error as NSError {
                print("Error with moving downloaded file: \(error.localizedDescription)")
                downloadingItem = URL(string: "")
                tableView.reloadData()
                viewLoadingItemInfo.isHidden = true
                loadingLock = false
                viewCancelDownloading.isHidden = true
                downloadAllList = [URL]()  ////////
                return
            }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let mBytes = String((totalBytesWritten / 1024) / 1024) + " Mb"
        let mBytesTotal = String((totalBytesExpectedToWrite / 1024) / 1024) + " Mb"
        let uploadProgress:Float = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        lblDownloaded.text = String(mBytes)
        lblMbTotal.text = String(mBytesTotal)
        downloadProgress.progress = uploadProgress
    }
}
// Data manager
extension DownloadVC {
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
}












