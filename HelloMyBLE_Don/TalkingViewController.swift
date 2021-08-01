//
//  ViewController.swift
//  HelloMyBLE_Don
//
//  Created by 楊振東 on 2021/7/27.
//

import UIKit
import CoreBluetooth

class TalkingViewController: UIViewController {
    
    @IBOutlet weak var inputTextField: UITextField!
    @IBOutlet weak var logTextView: UITextView!
    
    var talkingPeripheral: CBPeripheral!
    var talkingChar: CBCharacteristic!

    override func viewDidLoad() {
        super.viewDidLoad()
        guard talkingChar != nil else {
            assertionFailure("talkingChar is nil")
            return
        }
        talkingPeripheral = talkingChar.service.peripheral
        talkingPeripheral.delegate = self
        
        talkingPeripheral.setNotifyValue(true, for: talkingChar)
    }


    @IBAction func sendBtnPressed(_ sender: Any) {
        guard let text = inputTextField.text, !text.isEmpty else {
            return
        }
        inputTextField.resignFirstResponder()  //Dismiss keyboard
        guard let data = "[阿東] \(text) \n".data(using: .utf8) else {
            assertionFailure("Fail to convert text to data")
            return
        }
        
        //Detect write type
        let properties = talkingChar.properties
        let type: CBCharacteristicWriteType =
            properties.contains(.writeWithoutResponse) ? .withResponse: .withResponse
        talkingPeripheral.writeValue(data, for: talkingChar, type: type)
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("didwriteValueFor fail : \(error)")
            return
        }
        print("didWriteValueFor OK!")
    }
}

extension TalkingViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, let content = String(data: data, encoding:.utf8) else {
            print("Invail incoming content")
            return
        }
        logTextView.text = logTextView.text + content
    }
}
