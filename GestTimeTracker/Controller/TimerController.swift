//
//  TimerController.swift
//  Timer
//
//  Created by Thomas Maier on 06.11.19.
//  Copyright © 2019 TinkeringAround. All rights reserved.
//

import Cocoa
import EventKit

class TimerController  {
    
    // Components
    var statusBarButton: NSButton? = nil
    var statusBarMenu: NSMenu? = nil
    var timer : Timer? = nil
    let progressBar: ProgressBar = ProgressBar(frame: CGRect(x: 0, y: 0, width: 30, height: 22))
    let notification: NSUserNotification = NSUserNotification()
    
    // Attributes:
    var seconds: Int = 0
    var maxSeconds: Int = 1
    var steps : Int = 10
    let numberUpdates : Int = 60
    
    @Published var jobName : String = "drag here"
    var startDate: Date = Date()
    var endDate: Date = Date()
    let eventStore = EKEventStore()

    
    // ===================================================================
    func initialize(statusBarButton: NSStatusBarButton, statusBarMenu: NSMenu) -> Void {
        self.statusBarButton = statusBarButton
        self.statusBarMenu = statusBarMenu
        
        notification.title = "Tinkering Timer"
        notification.setValue(NSImage(named: "AppIcon"), forKey: "_identityImage")
        notification.setValue(true, forKey: "_ignoresDoNotDisturb")
        notification.setValue(true, forKey: "_clearable")
        notification.soundName = NSUserNotificationDefaultSoundName
        
        statusBarButton.attributedTitle = formatString(seconds: seconds)
    }
    
    func start(minutes: Int) -> Void {
        if(self.timer != nil) { self.timer!.invalidate() }
        
        // Set Values
        if(self.seconds < 1 ){
            self.startDate = Date()
        }
        self.seconds += minutes * 60
        self.endDate = self.startDate.addingTimeInterval(Double(minutes) * 60.0)
        self.maxSeconds = seconds
        self.steps = Int(CGFloat(seconds) / CGFloat(numberUpdates))
        
        // Start
        progressBar.start(seconds: seconds)
        self.timer = Timer.scheduledTimer(timeInterval: TimeInterval(steps), target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
        
        // Show Progress Bar
        statusBarButton?.image = nil
        statusBarButton?.attributedTitle = formatString(seconds: seconds)

//        statusBarButton?.addSubview(progressBar)
        
        // Add Menu Item with Time
//        let menuItem : NSMenuItem = statusBarMenu!.items[0]
//        menuItem.title = remainingTime()
//        menuItem.isHidden = false
    }
    
    /// 请求权限并创建事件
    /// 添加事件到指定日历，如果日历不存在就创建
       func addEvent(title: String, startDate: Date, endDate: Date, calendarName: String) {
           
           // 1️⃣ 请求权限
           eventStore.requestAccess(to: .event) { granted, error in
               if let error = error {
                   print("请求权限错误: \(error)")
                   return
               }
               
               guard granted else {
                   print("用户拒绝访问日历")
                   return
               }
               
               // 2️⃣ 查找指定日历
               var calendar: EKCalendar? = self.eventStore.calendars(for: .event).first(where: { $0.title == calendarName })
               
               // 如果没有找到，则创建新日历
               if calendar == nil {
                   calendar = EKCalendar(for: .event, eventStore: self.eventStore)
                   calendar!.title = calendarName
                   
                   // 使用默认 iCloud/本地源
                   if let localSource = self.eventStore.sources.first(where: { $0.sourceType == .local }) {
                       calendar!.source = localSource
                   } else if let icloudSource = self.eventStore.sources.first(where: { $0.sourceType == .calDAV }) {
                       calendar!.source = icloudSource
                   } else {
                       print("没有可用的日历源")
                       return
                   }
                   
                   do {
                       try self.eventStore.saveCalendar(calendar!, commit: true)
                       print("已创建日历：\(calendarName)")
                   } catch {
                       print("创建日历失败: \(error)")
                       return
                   }
               }
               
               // 3️⃣ 创建事件
               let event = EKEvent(eventStore: self.eventStore)
               event.title = title
               event.startDate = startDate
               event.endDate = endDate
               event.calendar = calendar
               
               // 4️⃣ 保存事件
               do {
                   try self.eventStore.save(event, span: .thisEvent)
                   print("事件已保存到 \(calendarName)：\(title)")
               } catch {
                   print("保存事件失败: \(error)")
               }
           }
       }

    
    func stop() -> Void {
        self.timer?.invalidate()
        
        // Remove MenuItem
        statusBarMenu!.items[0].isHidden = true
        
        // Reset StatusBar Image
        progressBar.removeFromSuperview()
        statusBarButton?.image = NSImage(named:NSImage.Name("clock"))
        statusBarButton?.attributedTitle = formatString(seconds: seconds)
        
        // insert calender
        addEvent(title: self.jobName, startDate: self.startDate, endDate: self.endDate,calendarName:  "Tracker")
    }
    
    func showNotification() -> Void {
        notification.identifier = String(NSDate().timeIntervalSince1970)
        var message = String(maxSeconds / 60) + " Minuten sind "
        if(maxSeconds / 60 == 1) {
            message = "1 Minute ist "
        }
        notification.informativeText = message + "abgelaufen."
        
        let notificationCenter = NSUserNotificationCenter.default
        notificationCenter.deliver(notification)
    }
    
    func secondsToMinutes(seconds: Int) -> Int {
        return Int(CGFloat(seconds) / 60)
    }
    
    func formatTime(seconds: Int) -> String {
        let minutes = seconds / 60
        if(minutes<1){
            let remainingSeconds = seconds % 60
            if(remainingSeconds < 1){return ""}
            return String(format: "%d秒", remainingSeconds)
        }
        return String(format: "%d分", minutes)
    }
    
    func formatString(seconds: Int) -> NSMutableAttributedString {
        let timeStr = formatTime(seconds: seconds)
        let jobStr = jobName

        let timeAttr = NSAttributedString(string: timeStr, attributes: [
            .font: NSFont.boldSystemFont(ofSize: 14),
            .foregroundColor: NSColor.white,
            .baselineOffset: -2 // 负值往下，正值往上，根据需要微调
        ])

        let separatorAttr = NSAttributedString(string: " |  ", attributes: [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.gray
        ])

        let jobAttr = NSAttributedString(string: jobStr, attributes: [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.white,
            .baselineOffset: -2 // 负值往下，正值往上，根据需要微调
        ])

        let combined = NSMutableAttributedString()
        combined.append(timeAttr)
        combined.append(separatorAttr)
        combined.append(jobAttr)

        return combined
    }

    
    func remainingTime() -> String {
        let minutes = secondsToMinutes(seconds: seconds)
        var message = "Noch " + String(minutes) + " Minuten..."
        if(minutes == 0) {
            message = "Weniger als 1 Minute..."
        }
        return message
    }
    
    // ===================================================================
    @objc func update(_ sender: Timer) {
        seconds -= steps
        if(seconds <= 0) {
            showNotification()
            stop()
        } else {
            statusBarMenu!.items[0].title = remainingTime()
//            progressBar.update(seconds: seconds)
            statusBarButton?.attributedTitle = formatString(seconds: seconds)
        }
    }
    
    func setJobName(jobName:String){
        self.jobName = jobName
        statusBarMenu!.items[0].title = remainingTime()
        statusBarButton?.attributedTitle = formatString(seconds: seconds)
    }
}
