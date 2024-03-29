//
//  Logging.swift
//  BluenetShared
//
//  Created by Alex de Mulder on 27/01/2017.
//  Copyright © 2017 Alex de Mulder. All rights reserved.
//

import Foundation

#if os(iOS)
import UIKit
#endif

public enum LogLevel : Int {
    case VERBOSE = 0
    case DEBUG   = 1
    case INFO    = 2
    case WARN    = 3
    case ERROR   = 4
    case NONE    = 5
}

func memoryFootprint() -> Float? {
    // The `TASK_VM_INFO_COUNT` and `TASK_VM_INFO_REV1_COUNT` macros are too
    // complex for the Swift C importer, so we have to define them ourselves.
    let TASK_VM_INFO_COUNT = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let TASK_VM_INFO_REV1_COUNT = mach_msg_type_number_t(MemoryLayout.offset(of: \task_vm_info_data_t.min_address)! / MemoryLayout<integer_t>.size)
    var info = task_vm_info_data_t()
    var count = TASK_VM_INFO_COUNT
    let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
        infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
        }
    }
    guard
        kr == KERN_SUCCESS,
        count >= TASK_VM_INFO_REV1_COUNT
    else { return nil }
    
    let usedBytes = Float(info.phys_footprint)
    return usedBytes
    
}


open class LogClass {
    let lock = NSRecursiveLock()
    
    let dir: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last! as URL
    
    var logPrintLevel : LogLevel = .INFO
    var logFileLevel  : LogLevel = .NONE
    var logBaseFilename : String = "BluenetLog"
    var printTimestamps : Bool = false
    
    var lastTimestamp : Double = 0
    
    var daysToStoreLogs : Int = 3
    
    public init() {
        cleanLogs()
    }
    
    public init(daysToStoreLogs: Int) {
        self.daysToStoreLogs = daysToStoreLogs
        cleanLogs()
    }
    
    public init(logBaseFilename: String) {
        self.logBaseFilename = logBaseFilename
        cleanLogs()
    }
    
    public init(daysToStoreLogs:Int, logBaseFilename: String) {
        self.daysToStoreLogs = daysToStoreLogs
        self.logBaseFilename = logBaseFilename
        cleanLogs()
    }
    
    open func setPrintLevel(_ level : LogLevel) {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        logPrintLevel = level
    }
    open func setFileLevel(_ level : LogLevel) {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        logFileLevel = level
    }
    open func setTimestampPrinting( newState: Bool ) {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        printTimestamps = newState
    }
    
    /**
     * Will remove all logs that have a different name before changing the name.
     */
    open func setBaseFilename(baseFilename: String) {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        clearLogs()
        logBaseFilename = baseFilename
        cleanLogs()
    }
    
    open func setDaysToStoreLogs(daysToStoreLogs: Int) {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        self.daysToStoreLogs = daysToStoreLogs
        cleanLogs()
    }
    
    open func verbose(_ data: String) {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        _log("-- VERBOSE: \(data)", level: .VERBOSE, explicitNoWriteToFile: false)
    }
    
    open func debug(_ data: String) {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        _log("-- DEBUG: \(data)", level: .DEBUG, explicitNoWriteToFile: false)
    }
    
    open func info(_ data: String) {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        _log("-- INFO: \(data)", level: .INFO, explicitNoWriteToFile: false)
    }
    
    open func warn(_ data: String) {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        _log("-- WARN: \(data)", level: .WARN, explicitNoWriteToFile: false)
    }
    
    open func error(_ data: String) {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        _log("-- ERROR: \(data)", level: .ERROR, explicitNoWriteToFile: false)
    }
    
    
    open func file(_ data: String) {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        _logFile("-- FILE: \(data)", filenameBase: logBaseFilename)
    }
    
    open func clearLogs() {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        clearLogs(keepAmountOfDays: 0)
    }
    
    open func cleanLogs() {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        clearLogs(keepAmountOfDays: daysToStoreLogs)
    }
    
    open func clearLogs(keepAmountOfDays: Int) {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        #if os(iOS)
            var allowedNames = Set<String>()
            if (keepAmountOfDays > 0) {
                for i in [Int](0...keepAmountOfDays) {
                    let date = Date().addingTimeInterval((-24 * 3600 * Double(i)))
                    allowedNames.insert(_getFilename(filenameBase: self.logBaseFilename, date: date))
                }
            }
            
            let filemanager = FileManager()
            let files = try? filemanager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [])
            if let filesFound = files {
                for file in filesFound {
                    let filename = file.lastPathComponent
                    if (filename.contains(self.logBaseFilename)) {
                        if (allowedNames.contains(filename) == false) {
                            do {
                                try filemanager.removeItem(atPath: file.path)
                            }
                            catch let err {
                                print("Could not remove file \(filename) at \(file.path) due to: \(err)")
                            }
                        }
                    }
                }
            }
        #endif
    }
    
    
    
    func _log(_ data: String, level: LogLevel, explicitNoWriteToFile: Bool = false) {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        if (logPrintLevel.rawValue <= level.rawValue) {
            if (printTimestamps) {
                let timestamp = Date().timeIntervalSince1970
                let time = Date().description
                let deltaT = timestamp - self.lastTimestamp
                self.lastTimestamp = timestamp
                print("\(timestamp) (dt: \(deltaT)) @ \(time) \(data)")
            }
            else {
                print(data)
            }
        }
        if (logFileLevel.rawValue <= level.rawValue && explicitNoWriteToFile == false) {
            _logFile(data, filenameBase: logBaseFilename)
        }
    }
    
    
    func _logFile(_ data: String, filenameBase: String) {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        #if os(iOS)
            let date = Date()
            let filename = _getFilename(filenameBase: filenameBase, date: date);
            
            let url = dir.appendingPathComponent(filename)
            
            UIDevice.current.isBatteryMonitoringEnabled = true
            let battery = UIDevice.current.batteryLevel
        
            let usedBytes: UInt64? = UInt64(memoryFootprint() ?? 0)
            let usedMB = Double(usedBytes ?? 0) / 1024 / 1024
            
            let timestamp = Date().timeIntervalSince1970
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let dateInFormat = dateFormatter.string(from: Date())
            let content = "\(round(1000*timestamp)) @ \(dateInFormat) - battery:\(battery) - ram:\(usedMB)MB - " + data + "\n"
            let contentToWrite = content.data(using: String.Encoding.utf8)!
            
            if let fileHandle = FileHandle(forWritingAtPath: url.path) {
                defer {
                    fileHandle.closeFile()
                }
                fileHandle.seekToEndOfFile()
                fileHandle.write(contentToWrite)
            }
            else {
                do {
                    try contentToWrite.write(to: url, options: .atomic)
                }
                catch {
                    print("Could not write to file \(error)")
                }
            }
        #endif
    }
    
    func _getFilename(filenameBase: String, date: Date) -> String {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        let styler = DateFormatter()
        styler.dateFormat = "yyyy-MM-dd"
        let dateString = styler.string(from: date)
        let filename = filenameBase + dateString + ".log"
        
        return filename
    }
    
}

