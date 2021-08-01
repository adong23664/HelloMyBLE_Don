//
//  PeripheralViewController.swift
//  HelloMyBLE_Don
//
//  Created by 楊振東 on 2021/7/29.
//

import UIKit
import CoreBluetooth

class PeripheralViewController: UIViewController {

    @IBOutlet weak var logTextView: UITextView!
    @IBOutlet weak var inputTextField: UITextField!
    
    let manager = CBPeripheralManager()
    let serviceUUID = CBUUID(string: "8888")
    let charUUID = CBUUID(string: "8889")
    let chatroomName = "Don的聊天室"
    
    var mainChar : CBMutableCharacteristic!
    var resendBuffer = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        manager.delegate = self
    }
    

    @IBAction func sendBtnPressed(_ sender: Any) {
        guard let text = inputTextField.text, !text.isEmpty else {
            return
        }
        inputTextField.resignFirstResponder()
        let message = "[\(chatroomName)] \(text)\n"
        sendMessage(message, central: nil)
        logTextView.text = logTextView.text + message
    }
    
    @IBAction func startAdvertisingValueChanged(_ sender: UISwitch) {
        if sender.isOn {
            startAdvertising()
        } else {
            stopAdvertising()
        }
    }
    
    
    func startAdvertising() {
        if mainChar == nil {
            let properties: CBCharacteristicProperties = [.notify, .read, .write]
            let permissions: CBAttributePermissions = [.readable, .writeable]
            mainChar = CBMutableCharacteristic(type: charUUID, properties: properties, value: nil, permissions: permissions)
            
            let service = CBMutableService(type: serviceUUID, primary: true)
            service.characteristics = [mainChar]
            manager.add(service)
        }
        let uuids = [serviceUUID]  //import! it must be a array
        let info: [String: Any] = [CBAdvertisementDataLocalNameKey: chatroomName, CBAdvertisementDataServiceUUIDsKey: uuids]
        manager.startAdvertising(info)
    }
    func stopAdvertising() {
        manager.stopAdvertising()
    }
    
    func sendMessage(_ message: String, central: CBCentral?) {
        guard let data = message.data(using: .utf8) else {
            assertionFailure("Fail to convert string to data")
            return
        }
        let centrals = (central == nil ? nil : [central!])
        let success = manager.updateValue(data, for: mainChar, onSubscribedCentrals: centrals)
        if !success {
            resendBuffer += message
        }
    }
    
}

extension PeripheralViewController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        let state = peripheral.state
        if state != .poweredOn {
            print("BLE is not ready: \(state.rawValue)")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        guard let count = mainChar.subscribedCentrals?.count else {
            assertionFailure("Fail to get count of subscribedCentrals")
            return
        }
        let hello = "[歡迎來到\(chatroomName), 目前人數\(count)人]\n"
        let message = "[有人加入了, 目前人數: \(count)]( max update length: \(central.maximumUpdateValueLength)\n"
        //maximumUpdateValueLength : 告訴peripheral 這個central 同一時間內最多能接收的封包大小
        sendMessage(hello, central: central)
        sendMessage(message, central: nil)
        logTextView.text = logTextView.text + message
        
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        guard let count = mainChar.subscribedCentrals?.count else {
            assertionFailure("Fail to get count of subscribedCentrals")
            return
    }
        let message = "[有人離開了, 目前人數: \(count)]\n"
        sendMessage(message, central: nil)
    
    //Note! This method will be called only when we get false from updateValue() before.
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        print("peripheraManagerIsReady")
        sendMessage(resendBuffer, central: nil)
        resendBuffer = ""
    }
       
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard let data = request.value,
                  let message = String(data: data, encoding: .utf8) else {
                assertionFailure("Fail to convert data to string")
                return
            }
            
            sendMessage(message, central: nil)
            manager.respond(to: request, withResult: .success)
            logTextView.text = logTextView.text + message
        }
    }
 }

}
