//
//  RemoteConfigService.swift
//  EasyScanner
//
//  Created by Quang Ly Hoang on 14/03/2022.
//

import UIKit
import FirebaseRemoteConfig

public protocol RemoteKeyIdentifiable {
    /// remote configute key from firebase.
    var remoteKeyIDString: String { get }
}

open class RemoteConfigService {
    // MARK: - Singleton
    public static let shared = RemoteConfigService()
    public var isFetch: Bool = false
    
    // MARK: - init
    private init() {
        #if DEBUG
        settingForDebug()
        #endif
    }
    
    // MARK: - Functions
    private func settingForDebug() {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        settings.fetchTimeout = 5
        RemoteConfig.remoteConfig().configSettings = settings
    }
    
   public func fetchCloudValues(complete: @escaping BoolBlockAds) {
        RemoteConfig.remoteConfig().fetch { _, error in
            if error != nil {
                DispatchQueue.main.async {
                    complete(false)
                }
                return
            }
            
            RemoteConfig.remoteConfig().activate { _, _ in
                DispatchQueue.main.async {
                    self.isFetch = true
                    complete(true)
                }
            }
        }
    }
    
    public func loadDefaultValues(allKey: [RemoteKeyIdentifiable], value: Any) {
        let defaults = Dictionary(uniqueKeysWithValues: allKey.map{ ($0.remoteKeyIDString, value) })
        RemoteConfig.remoteConfig().setDefaults(defaults as? [String: NSObject])
    }
    
    public func number(forKey key: RemoteKeyIdentifiable) -> Int {
        return RemoteConfig.remoteConfig()[key.remoteKeyIDString].numberValue.intValue
    }
    
    public func bool(forKey key: RemoteKeyIdentifiable) -> Bool {
        return RemoteConfig.remoteConfig()[key.remoteKeyIDString].boolValue
    }
    
    public func string(forKey key: RemoteKeyIdentifiable) -> String {
        return RemoteConfig.remoteConfig()[key.remoteKeyIDString].stringValue
    }
    
    public func double(forKey key: RemoteKeyIdentifiable) -> Double {
        return RemoteConfig.remoteConfig()[key.remoteKeyIDString].numberValue.doubleValue
    }
    
    public func objectJson<T: Decodable>(forKey key: RemoteKeyIdentifiable, type: T.Type) -> T? {
        let data = RemoteConfig.remoteConfig()[key.remoteKeyIDString].dataValue
        return try? JSONDecoder().decode(type, from: data)
    }
}
