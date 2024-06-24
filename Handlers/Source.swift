//
//  Source.swift
//  HardeX
//
//  Created by SteemeX on 30/11/2017.
//  Copyright © 2017 SteemeX. All rights reserved.
//

import UIKit

class Source {
    class func getNewTracks(success: @escaping (_ items: [URL]) -> Void) {
        let prefixURL = URL(string: "http://steemex.ru/hardex/")!
        let url = URL(string: "http://steemex.ru/hardex/json.php")!
        URLSession.shared.dataTask(with: url) {
            (data, response, error) in
            if error == nil {
                guard let data = data else {
                    print("Source: error getting data!")
                    return
                }
                var downloadList = [URL]()
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as! NSDictionary
                    let files = json["files"] as! NSArray
                    //print(files)
                    for file in files {
                        let stringURL = (file as! NSDictionary)["file"] as! String
                        //print(stringURL)
                        if stringURL.range(of: ".mp3") != nil {
                            downloadList.append(prefixURL.appendingPathComponent(stringURL))
                        }
                    }
                    success(downloadList)
                } catch { print("Source: error in JSONSerialization!") }
            } else { print("Source: error != nil \(String(describing: error))") }
        }.resume()
    }
}
