//
//  MirakurunApi.swift
//  Meruru
//
//  Created by castaneai on 2019/04/06.
//  Copyright © 2019 castaneai. All rights reserved.
//

import Foundation
import Alamofire
import Cocoa

public struct Status: Codable {
    let version: String
}

public struct Service: Codable {
    let id: Int
    let serviceId: Int
    let networkId: Int
    let name: String
    let channel: Channel
}

public struct Channel: Codable {
    let type: String
    let channel: String
}

public struct Program : Codable {
    let name: String
    let startAt: Int64
    let duration: Int64
}

public class MirakurunAPI {
    
    init(baseURL: URL) {
        self.baseURL = baseURL
    }
    private let baseURL: URL
    private let jsonDecoder: JSONDecoder = JSONDecoder()
    
    public func fetchPrograms(service: Service, completion: @escaping (AFResult<[Program]>) -> Void) {
        let url = self.baseURL.appendingPathComponent("programs")
        let params: Parameters = [
            "serviceId": service.serviceId,
        ]
        AF.request(url, parameters: params, encoding: URLEncoding(destination: .queryString))
            .responseDecodable { response in
            completion(response.result)
        }
    }
    
    public func getStreamURL(service: Service) -> URL? {
        guard  let baseURL = AppConfig.shared.currentData?.videoURL else {
            return nil
        }

        let replacedURL = baseURL.replacingOccurrences(of: "<serviceid>", with: String(service.id))
            .replacingOccurrences(of: "<type>", with: String(service.channel.type))
            .replacingOccurrences(of: "<channel>", with: String(service.channel.channel))

        guard let urlObject = URL(string: replacedURL) else {
            return nil
        }
        return urlObject
    }
    
    public func fetchStatus(completion: @escaping (AFResult<Status>) -> Void) {
        let url = self.baseURL.appendingPathComponent("status")
        AF.request(url).responseDecodable { response in
            completion(response.result)
        }
    }
    
    public func fetchServices(completion: @escaping (AFResult<[Service]>) -> Void) {
        let url = self.baseURL.appendingPathComponent("services")
        AF.request(url).responseDecodable { response in
            completion(response.result)
        }
    }
}
