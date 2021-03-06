//
//  CentralTableViewController.swift
//  HelloMyBLE_Don
//
//  Created by 楊振東 on 2021/7/27.
//

import UIKit
import CoreBluetooth

class CentralTableViewController: UITableViewController{
    
    let manager = CBCentralManager()
    var allItems = [String: DiscoveredItem]()
    var lastRefreshData = Date()
    
    var willDiscoverServices = [CBService]()
    var info = ""
    
    
    let targetServiceUUID = CBUUID(string: "8888")
    let targetCharUUID = CBUUID(string: "8889")
    var shouldTalkingAfterFound = false
    var talkingChar: CBCharacteristic?

    override func viewDidLoad() {
        super.viewDidLoad()
        manager.delegate = self

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Disconnect when we return from TalkingVC
        if let characteristic = talkingChar {
            let peripheral = characteristic.service.peripheral
            if peripheral.state == .connected {
                manager.cancelPeripheralConnection(peripheral)
            }
            talkingChar = nil // Clean up!
        }
    }
    
    @IBAction func scanEnableValueChange(_ sender: UISwitch) {
        if sender.isOn {
            startToScan()
        } else {
            stopScanning()
        }
    }
    
    func startToScan() {
        let services : [CBUUID]? = nil
        let options = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        manager.scanForPeripherals(withServices: services, options: options)
    }
    
    func stopScanning() {
        manager.stopScan()
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return allItems.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "myCell", for: indexPath)
        let item = getItem(at: indexPath)
        let name = item.peripheral.name ?? "n/a"
        
        cell.textLabel?.text = "\(name) RSSI: \(item.rssi)"
        cell.detailTextLabel?.text = String(format: "Last seen: %.1f seconds ago", Date().timeIntervalSince(item.lastSeen))

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //1
        shouldTalkingAfterFound = true
        let item = getItem(at: indexPath)
        manager.connect(item.peripheral, options: nil)
        //2
    }
    
    
    //讓app開始連接peripheral
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        //1
        shouldTalkingAfterFound = false
        let item = getItem(at: indexPath)
        manager.connect(item.peripheral, options: nil)
        //2
    }
    
    func getItem(at indexPath: IndexPath) -> DiscoveredItem {
        let keys = Array(allItems.keys)
        let targetKey = keys[indexPath.row]
        return allItems[targetKey]!
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        
        if let vc = segue.destination as? TalkingViewController {
            vc.talkingChar = talkingChar
        }
    }
    

}

extension UIViewController {
    func showAlert(message: String){
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let ok = UIAlertAction(title: "OK", style: .default)
        alert.addAction(ok)
        present(alert, animated: true)
    }
}

extension CentralTableViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        if state != .poweredOn {
            //error
            let message = "BLE is not ready:\(state.rawValue)"
            showAlert(message: message)
        }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "n/a"
        let identifier = peripheral.identifier.uuidString
        let now = Date()
        
        let existItem = allItems[identifier]
        if existItem == nil {
            print("Found \(name), RSS: \(RSSI), id: \(identifier), data: \(advertisementData)")
        }
        let item = DiscoveredItem(peripheral: peripheral, rssi: RSSI.intValue, lastSeen: now)
        allItems[identifier] = item
        
        if existItem == nil || now.timeIntervalSince(lastRefreshData) > 1.0 {
            lastRefreshData = now
            self.tableView.reloadData()
        }
        
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        //3
        print("didConnect: \(peripheral.identifier)")
        stopScanning()
        
        peripheral.delegate = self
        peripheral.discoverServices(nil) //回報所有services
        //4
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        startToScan()  //刷新
    }
}

extension CentralTableViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        //5
        if let error = error {
            print("didDiscoverServices: \(error)")
            manager.cancelPeripheralConnection(peripheral) //失敗就把連線取消
            //6a
            return
        }
        //6b
        guard  let services = peripheral.services else {
            assertionFailure("Fail to get services.")
            
            return
        }
        
//        for service in services {
//            peripheral.discoverCharacteristics(nil, for: service)
//        }
        info = "**** Service: \(services.count)\n"
        //7
        willDiscoverServices = services
        handleNextService(of: peripheral)
        //10
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        //11
        //18
        if let error = error {
            print("didDiscoverServices: \(error)")
            manager.cancelPeripheralConnection(peripheral) //失敗就把連線取消
            //12a
            return
        }
        //12b
        guard let characteristics = service.characteristics else {
            assertionFailure("Invalid characteristics")
            return
        }
        info += "** Service: \(service.uuid.uuidString):\(characteristics.count)\n"
        for ch in characteristics {
            info += "* CH: \(ch.uuid.uuidString)\n"
            if shouldTalkingAfterFound && ch.uuid == targetCharUUID {
                talkingChar = ch
                performSegue(withIdentifier: "goTalking", sender: nil)
                return  //important
            }
        }
        
        //13
        // Next Step
        if willDiscoverServices.isEmpty {
            // All done!
            //14a
            showAlert(message: info)
            manager.cancelPeripheralConnection(peripheral)
            //15a -->End
        } else {
            //14b
            handleNextService(of: peripheral)
            //17
        }
    }
    
    func handleNextService(of peripheral: CBPeripheral) {
        //8
        //15b
        guard let service = willDiscoverServices.first else {
            return
        }
        willDiscoverServices.removeFirst()
        peripheral.discoverCharacteristics(nil, for: service)
        //9
        //16
    }
}



struct DiscoveredItem {
    let peripheral: CBPeripheral
    let rssi: Int
    let lastSeen: Date
}
