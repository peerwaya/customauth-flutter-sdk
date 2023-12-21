import Flutter
import UIKit
import CustomAuth
import FetchNodeDetails

struct CustomAuthArgs {
    let network: String
    let browserRedirectUri: String
    let redirectUri: String
    let enableOneKey: Bool
    let networkUrl: String?

    var ethereumNetwork: EthereumNetworkFND {
        get {
            switch network {
            case "mainnet":
                return EthereumNetworkFND.MAINNET
            case "testnet":
                return EthereumNetworkFND.TESTNET
            case "cyan":
                return EthereumNetworkFND.CYAN
            case "aqua":
                return EthereumNetworkFND.AQUA
            case "celeste":
                return EthereumNetworkFND.CELESTE
            default:
                return EthereumNetworkFND.MAINNET
            }
        }
    }
}

public class SwiftCustomAuthPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "customauth", binaryMessenger: registrar.messenger())
        let instance = SwiftCustomAuthPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    var customAuthArgs: CustomAuthArgs?

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "Invalid Flutter iOS plugin method arguments",
                    details: nil))
            return
        }
        Task {
            switch call.method {
            case "init":
                guard
                    let network = args["network"] as? String,
                    let browserRedirectUri = args["browserRedirectUri"] as? String,
                    let redirectUri = args["redirectUri"] as? String,
                    let enableOneKey = args["enableOneKey"] as? Bool
                else {
                    result(FlutterError(
                            code: "MISSING_ARGUMENTS",
                            message: "Missing init arguments",
                            details: nil))
                    return
                }
                var networkUrl = args["networkUrl"] as? String
                if networkUrl?.isEmpty ?? true {
                    networkUrl = nil
                }
                self.customAuthArgs = CustomAuthArgs(
                    network: network, browserRedirectUri: browserRedirectUri, redirectUri: redirectUri, enableOneKey: enableOneKey, networkUrl: networkUrl)
                print("CustomAuthPlugin#init: " +
                        "network=\(network), " +
                        "browserRedirectUri=\(redirectUri), redirectUri=\(redirectUri), enableOneKey=\(enableOneKey)")
                result(nil)
            case "triggerLogin":
                guard let initArgs = self.customAuthArgs
                else {
                    result(FlutterError(
                            code: "NotInitializedException",
                            message: "CustomAuth.init has to be called first",
                            details: nil))
                    return
                }
                guard
                    let typeOfLogin = args["typeOfLogin"] as? String,
                    let verifier = args["verifier"] as? String,
                    let clientId = args["clientId"] as? String
                else {
                    result(FlutterError(
                            code: "MissingArgumentException",
                            message: "Missing triggerLogin arguments",
                            details: nil))
                    return
                }
                guard let loginProvider = LoginProviders(rawValue: typeOfLogin) else {
                    result(FlutterError(
                            code: "InvalidTypeOfLoginException",
                            message: "Invalid type of login",
                            details: nil))
                    return
                }

                let jwtParams = args["jwtParams"] as? [String: String]
                let subVerifierDetails = SubVerifierDetails(
                    loginType: .web,
                    loginProvider: loginProvider,
                    clientId: clientId,
                    verifier: verifier,
                    redirectURL: initArgs.redirectUri,
                    browserRedirectURL: initArgs.browserRedirectUri,
                    jwtParams: jwtParams ?? [:]
                )
                let customAuthSdk = CustomAuth(
                    aggregateVerifierType: .singleLogin,
                    aggregateVerifier: verifier,
                    subVerifierDetails: [subVerifierDetails],
                    network: initArgs.ethereumNetwork,
                    enableOneKey: customAuthArgs?.enableOneKey ?? false,
                    networkUrl: customAuthArgs?.networkUrl
                )
                do {
                    let data = try await customAuthSdk.triggerLogin()
                    result(data)
                } catch {
                    result(FlutterError(
                        code: "IosSdkError", message: "Error from iOS SDK: \(error.localizedDescription)", details: error.localizedDescription
                    ))
                }
            case "triggerAggregateLogin":
                guard let initArgs = self.customAuthArgs
                else {
                    result(FlutterError(
                            code: "NotInitializedException",
                            message: "TorusDirect.init has to be called first",
                            details: nil))
                    return
                }
                guard
                    let aggregateVerifierType = args["aggregateVerifierType"] as? String,
                    let verifierIdentifier = args["verifierIdentifier"] as? String,
                    let subVerifierDetailsArray = args["subVerifierDetailsArray"] as? [Dictionary<String, Any>]
                else {
                    result(FlutterError(
                            code: "MissingArgumentException",
                            message: "Missing triggerAggregateLogin arguments",
                            details: nil))
                    return
                }
                var castedSubVerifierDetailsArray: [SubVerifierDetails] = []
                for details in subVerifierDetailsArray {
                    guard let loginProvider = LoginProviders(
                        rawValue: details["typeOfLogin"] as! String
                    ) else {
                        result(FlutterError(
                                code: "InvalidTypeOfLoginException",
                                message: "Invalid type of login",
                                details: nil))
                        return
                    }
                    let jwtParams = details["jwtParams"] as? [String: String]
                    castedSubVerifierDetailsArray.append(
                        SubVerifierDetails(
                            loginType: .web,
                            loginProvider: loginProvider,
                            clientId: details["clientId"] as! String,
                            verifier: details["verifier"] as! String,
                            redirectURL: initArgs.redirectUri,
                            browserRedirectURL: initArgs.browserRedirectUri,
                            jwtParams: jwtParams ?? [:]
                        )
                    )
                    let customAuthSdk = CustomAuth(
                        aggregateVerifierType: verifierTypes(rawValue: aggregateVerifierType)!,
                        aggregateVerifier: verifierIdentifier,
                        subVerifierDetails: castedSubVerifierDetailsArray,
                        network: initArgs.ethereumNetwork,
                        enableOneKey: customAuthArgs?.enableOneKey ?? false,
                        networkUrl: customAuthArgs?.networkUrl
                    )
                    do {
                        let data = try await customAuthSdk.triggerLogin()
                        result(data)
                    } catch {
                        result(FlutterError(
                            code: "IosSdkError", message: "Error from iOS SDK: \(error.localizedDescription)", details: error.localizedDescription
                        ))
                    }
                }
            case "getTorusKey":
                guard let initArgs = self.customAuthArgs
                else {
                    result(FlutterError(
                            code: "NotInitializedException",
                            message: "CustomAuth.init has to be called first",
                            details: nil))
                    return
                }
                guard
                    let verifier = args["verifier"] as? String,
                    let verifierId = args["verifierId"] as? String,
                    let idToken = args["idToken"] as? String,
                    let verifierParams = args["verifierParams"] as? [String: String]
                else {
                    result(FlutterError(
                            code: "MissingArgumentException",
                            message: "Missing getTorusKey arguments",
                            details: nil))
                    return
                }
                let subVerifierDetails = SubVerifierDetails(
                    loginType: .web,
                    loginProvider: .jwt,
                    clientId: "<empty>",
                    verifier: verifier,
                    redirectURL: initArgs.redirectUri,
                    browserRedirectURL: initArgs.browserRedirectUri,
                    jwtParams: [:]
                )
                let customAuthSdk = CustomAuth(
                    aggregateVerifierType: .singleLogin,
                    aggregateVerifier: verifier,
                    subVerifierDetails: [subVerifierDetails],
                    network: initArgs.ethereumNetwork,
                    enableOneKey: customAuthArgs?.enableOneKey ?? false,
                    networkUrl: customAuthArgs?.networkUrl
                )
                do {
                    let data = try await customAuthSdk.getTorusKey(verifier: verifier, verifierId: verifierId, idToken: idToken, userData: verifierParams)
                    result( [
                        "publicAddress": data["publicAddress"],
                        "privateKey": data["privateKey"],
                    ])
                } catch {
                    result(FlutterError(
                        code: "IosSdkError", message: "Error from iOS SDK: \(error.localizedDescription)", details: error.localizedDescription
                    ))
                }
            case "getAggregateTorusKey":
                guard let initArgs = self.customAuthArgs
                else {
                    result(FlutterError(
                            code: "NotInitializedException",
                            message: "CustomAuth.init has to be called first",
                            details: nil))
                    return
                }
                guard
                    let verifier = args["verifier"] as? String,
                    let verifierId = args["verifierId"] as? String,
                    let subVerifierInfoArray = args["subVerifierInfoArray"] as? [Dictionary<String, Any>]
                else {
                    result(FlutterError(
                            code: "MissingArgumentException",
                            message: "Missing getAggregateTorusKey arguments",
                            details: nil))
                    return
                }
                if subVerifierInfoArray.count != 1 {
                    result(FlutterError(
                        code: "InvalidArgumentException",
                        message: "subVerifierInfoArray must have length of 1",
                        details: nil
                    ))
                    return
                }
                let sviaVerifier = subVerifierInfoArray[0]["verifier"] as! String
                let sviaIdToken = subVerifierInfoArray[0]["idToken"] as! String
                let subVerifierDetails = SubVerifierDetails(
                    loginType: .web,
                    loginProvider: .jwt,
                    clientId: "<empty>",
                    verifier: sviaVerifier == "" ? verifier : sviaVerifier,
                    redirectURL: initArgs.redirectUri,
                    browserRedirectURL: initArgs.browserRedirectUri,
                    jwtParams: [:]
                )
                let customAuthSdk = CustomAuth(
                    aggregateVerifierType: .singleIdVerifier,
                    aggregateVerifier: verifier,
                    subVerifierDetails: [subVerifierDetails],
                    network: initArgs.ethereumNetwork,
                    enableOneKey: customAuthArgs?.enableOneKey ?? false,
                    networkUrl: customAuthArgs?.networkUrl
                )
                do {
                    let data = try await customAuthSdk.getAggregateTorusKey(verifier: verifier, verifierId: verifierId, idToken: sviaIdToken, subVerifierDetails: subVerifierDetails)
                    result(data)
                } catch {
                    result(FlutterError(
                        code: "IosSdkError", message: "Error from iOS SDK: \(error.localizedDescription)", details: error.localizedDescription
                    ))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
