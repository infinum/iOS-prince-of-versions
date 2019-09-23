//
//  AppVersionChecker.swift
//  AppVersionChecker
//
//  Created by Jasmin Abou Aldan on 21/06/16.
//  Copyright © 2016 Infinum Ltd. All rights reserved.
//

import Foundation

public class PrinceOfVersions: NSObject {

    // MARK: - Public interface

    public struct UpdateInfoResponse {

        /// The server's response to the URL request.
        public let response: URLResponse?

        /// The result of response serialization.
        public let result: Result<UpdateInfo, UpdateInfoError>
    }

    public typealias CompletionBlock = (UpdateInfoResponse) -> Void
    public typealias NewVersionBlock = (Version, Bool, [String: Any]?) -> Void
    public typealias NoNewVersionBlock = (Bool, [String: Any]?) -> Void
    public typealias ErrorBlock = (Error) -> Void

    // MARK: Private properties

    private var _shouldPinCertificates: Bool = false

}

// MARK: - Public methods -

public extension PrinceOfVersions {

    /**
     Used for getting the versioning configuration stored on server.

     After check with server is finished, this method will return all informations about the app versioning.
     It's up to the user to handle that info in a way sutable for the app.
     For automated check if new optional or mandatory version is available, you can use `checkForUpdates` method.

     - parameter URL: URL that containts configuration data.
     - parameter httpHeaderFields: Optional HTTP header fields.
     - parameter shouldPinCertificates: Boolean that indicates whether PoV should use security keys from all certificates found in the main bundle. Default value is `false`.
     - parameter completion: The completion handler to call when the load request is complete. It returns result that contains UpdatInfo data or UpdateInfoError error
     - parameter delegateQueue: An operation queue for scheduling the delegate calls and completion handlers. The queue should be a serial queue, in order to ensure the correct ordering of callbacks. If nil, the session creates a serial operation queue for performing all delegate method calls and completion handler calls.

     - returns: Discardable `URLSessionDataTask`
     */
    @discardableResult
    func loadConfiguration(
        from URL: URL,
        httpHeaderFields: [String : String?]? = nil,
        shouldPinCertificates: Bool = false,
        completion: @escaping CompletionBlock,
        delegateQueue: OperationQueue? = nil
        ) -> URLSessionDataTask {

        _shouldPinCertificates = shouldPinCertificates

        let defaultSession = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: delegateQueue)
        var request = URLRequest(url: URL)

        if let headerFields = httpHeaderFields {
            for (fieldName, fieldValue) in headerFields {
                request.setValue(fieldValue, forHTTPHeaderField: fieldName)
            }
        }

        let dataTask = defaultSession.dataTask(with: request, completionHandler: { (data, response, error) in

            let result: Result<UpdateInfo, UpdateInfoError>
            if let error = error {
                result = Result.failure(.unknown(error.localizedDescription))
            } else {
                do {
                    let updateInfo = try UpdateInfo(data: data)
                    result = Result.success(updateInfo)
                } catch _ {
                    result = Result.failure(.invalidJsonData)
                }
            }
            let updateInfoResponse = UpdateInfoResponse(
                response: response,
                result: result
            )
            completion(updateInfoResponse)
        })
        dataTask.resume()

        /// Call to `finishTasksAndInvalidate` will break the connection with delegate
        /// and avoid memory leak. It is safe to call it immediately after dataTask
        /// resume() call since it won't cancel running task.
        defaultSession.finishTasksAndInvalidate()

        return dataTask
    }

    /**
     Used for getting the automated information about update availability.

     This method checks minimum required version, current installed version on device and current available version of the app with data stored on URL.
     It also checks if minimum version is satisfied and what should be frequency of notifying user.

     - parameter URL: URL that containts configuration data.
     - parameter httpHeaderFields: Optional HTTP header fields.
     - parameter shouldPinCertificates: Boolean that indicates whether PoV should use security keys from all certificates found in the main bundle. Default value is `false`.
     - parameter newVersion: The completion handler to call when the load request is complete in case if new version is available. It returns result that contains info about new optional or non-optional available version, as well as info if minimum version is satisfied
     - parameter noNewVersion: The completion handler to call when the load request is complete in case if there is no new versions available. It returns result that contains if minimum version is satisfied.

     - returns: Discardable `URLSessionDataTask`
     */
    @discardableResult
    func checkForUpdates(
        from URL: URL,
        httpHeaderFields: [String : String?]? = nil,
        shouldPinCertificates: Bool = false,
        newVersion: @escaping NewVersionBlock,
        noNewVersion: @escaping NoNewVersionBlock,
        error: @escaping ErrorBlock
        ) -> URLSessionDataTask {
        return loadConfiguration(
            from: URL,
            httpHeaderFields: httpHeaderFields,
            shouldPinCertificates: shouldPinCertificates,
            completion: { (response) in
            switch response.result {
            case .failure(let updateInfoError):
                error(updateInfoError)

            case .success(let info):
                if let minimumSdk = info.minimumSdkForLatestVersion, minimumSdk > info.sdkVersion {
                    noNewVersion(info.isMinimumVersionSatisfied, info.metadata)
                } else {
                    let latestVersion = info.latestVersion
                    if (latestVersion > info.installedVersion) && (!latestVersion.wasNotified || info.notificationType == .always) {
                        newVersion(latestVersion, info.isMinimumVersionSatisfied, info.metadata)
                        latestVersion.markNotified()
                    } else {
                        noNewVersion(info.isMinimumVersionSatisfied, info.metadata)
                    }
                }
            }
        })
    }
}

// MARK: - Private helpers -

private extension PrinceOfVersions {

    func _certificates(in bundle: Bundle = .main) -> [SecCertificate] {
        let paths = [".cer", ".CER", ".crt", ".CRT", ".der", ".DER"]
            .map { bundle.paths(forResourcesOfType: $0, inDirectory: nil) }
            .joined()

        /// Remove duplicates and extract certificate data from it
        return Set(paths)
            .compactMap { try? Data(contentsOf: URL(fileURLWithPath: $0)) as CFData }
            .compactMap { SecCertificateCreateWithData(nil, $0) }
    }

    func _pinnedKeys() -> [SecKey] {
        return _certificates()
            .compactMap { _publicKey(for: $0) }
    }

    func _publicKey(for certificate: SecCertificate) -> SecKey? {
        var publicKey: SecKey?

        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        let trustCreationStatus = SecTrustCreateWithCertificates(certificate, policy, &trust)

        if let trust = trust, trustCreationStatus == errSecSuccess {
            publicKey = SecTrustCopyPublicKey(trust)
        }

        return publicKey
    }

}

// MARK: - URLSessionDelegate -

extension PrinceOfVersions: URLSessionDelegate {
    
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let trust = challenge.protectionSpace.serverTrust, SecTrustGetCertificateCount(trust) > 0 else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        guard _shouldPinCertificates else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        if
            let serverCertificate = SecTrustGetCertificateAtIndex(trust, 0),
            let serverCertificateKey = _publicKey(for: serverCertificate)
        {
            let hasKey = _pinnedKeys().contains(where: { (key) -> Bool in
                return (serverCertificateKey as AnyObject).isEqual(key)
            })
            
            if hasKey {
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }
        }
        completionHandler(.cancelAuthenticationChallenge, nil)
    }

}
