//
//  AppDelegate.swift
//  Timer
//
//  Created by Thomas Maier on 24.10.19.
//  Copyright © 2019 TinkeringAround. All rights reserved.
//

import Cocoa
import ServiceManagement


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // Components:
    let statusbarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let popover = NSPopover()
    
    let customView = NSStackView()
    var timeView: NSButton?
    var jobView: NSTextView?
    
    var panRecognizer = NSPanGestureRecognizer()
    var wc: WC?
    var Timer: TimerController = TimerController()
    
    lazy var jobTextField: NSTextField = {
        let tf = NSTextField(frame: NSRect(x: 10, y: 70, width: 200, height: 22))
        tf.placeholderString = "Enter Task Name"
        tf.isBordered = true
        tf.bezelStyle = .roundedBezel
        tf.isEditable = true
        tf.isSelectable = true
        tf.focusRingType = .none
        tf.refusesFirstResponder = false
        tf.usesSingleLineMode = true
        tf.cell?.usesSingleLineMode = true
        tf.allowsEditingTextAttributes = true
        tf.isAutomaticTextCompletionEnabled = false
        tf.target = self
        tf.action = #selector(jobNameChanged(_:))
        return tf
    }()
    
    // Attributes:
    let statusBarHeight: Int = 22
    let windowSize: Int = 40
    let timeSteps: Int = 120 // 2h a 60 Min
    let minHeight: Int = 50
    let heightLimiter: Int = 100
    let adjustment: Int = 4
    
    // ===================================================================
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        do {
            try SMAppService.mainApp.register()
            print("已添加开机启动项")
        } catch {
            print("开机启动添加失败: \(error)")
        }
        
        // 设置状态栏按钮
        if let button = statusbarItem.button {
            button.image = NSImage(named: NSImage.Name("clock"))
            button.target = self
            button.action = #selector(togglePopover(_:)) // 单击触发 Popover
            panRecognizer = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            button.addGestureRecognizer(panRecognizer)
            
            // Initialize Button for Timer
            Timer.initialize(statusBarButton: button)
            statusbarItem.length = NSStatusItem.variableLength
        }
        
        // 配置 Popover
        let contentController = NSViewController()
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 120))
        
        // 添加 jobTextField
        contentView.addSubview(jobTextField)
        
        // 添加 Stoppen 按钮
        let stopButton = NSButton(title: "Stoppen", target: self, action: #selector(stopTimer))
        stopButton.frame = NSRect(x: 10, y: 40, width: 100, height: 22)
        stopButton.keyEquivalent = "x"
        contentView.addSubview(stopButton)
        
        // 添加 Beenden 按钮
        let quitButton = NSButton(title: "Beenden", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        quitButton.frame = NSRect(x: 110, y: 40, width: 100, height: 22)
        quitButton.keyEquivalent = "q"
        contentView.addSubview(quitButton)
        
        contentController.view = contentView
        popover.contentViewController = contentController
        popover.behavior = .transient // 点击外部自动关闭
        popover.delegate = self
        
        // Window Setup
        let sb = NSStoryboard(name: "Main", bundle: nil)
        wc = sb.instantiateController(withIdentifier: "Classic") as? WC
        
        // Starting App
        print("Starting App...")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        Timer.stop()
    }
    
    // 切换 Popover 显示/隐藏
    @objc func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusbarItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // 确保 jobTextField 获得焦点
            DispatchQueue.main.async {
                self.jobTextField.window?.makeFirstResponder(self.jobTextField)
                print("jobTextField 设置为第一响应者")
            }
        }
    }
    
    @objc func handlePan(_ sender: NSPanGestureRecognizer) {
        guard let button = statusbarItem.button else { return }
        let position: NSPoint = NSEvent.mouseLocation
        
        switch sender.state {
        case .began, .changed:
            // 拖拽开始或进行中，显示并更新窗口
            if !(wc?.window!.isVisible)! {
                wc?.showWindow(self)
            }
            updateWindow(point: position)
        case .ended:
            // 拖拽结束，启动定时器
            let minutes: Int = yToMinutes(y: position.y)
            if minutes > 0 {
                self.Timer.start(minutes: minutes)
            }
            wc?.close()
        default:
            break
        }
    }
    
    @objc func jobNameChanged(_ sender: NSTextField) {
        // 更新状态栏按钮显示
        Timer.setJobName(jobName: sender.stringValue)
        // 只有在输入完成时关闭 Popover
//        if sender.currentEditor()?.selectedRange.length == 0 {
//            popover.performClose(nil)
//        }
        popover.performClose(nil)
    }
    
    @objc func stopTimer() {
        self.Timer.stop()
    }
    
    // ===================================================================
    func getScreenHeight() -> Int {
        return Int(NSScreen.deepest!.frame.height) - statusBarHeight
    }
    
    func yToHeight(y: CGFloat) -> Int {
        let screenHeight = getScreenHeight()
        var height: Int = screenHeight + statusBarHeight - Int(y)
        if height > (screenHeight - heightLimiter) {
            height = screenHeight - heightLimiter
        }
        return height
    }
    
    func yToMinutes(y: CGFloat) -> Int {
        let screenHeight: Int = getScreenHeight()
        var height: Int = screenHeight + statusBarHeight - Int(y) - minHeight
        if height > screenHeight + statusBarHeight - minHeight - heightLimiter {
            height = screenHeight + statusBarHeight - heightLimiter - minHeight
        }
        
        var minutes = Int(CGFloat(height) / CGFloat(screenHeight - heightLimiter - minHeight) * CGFloat(timeSteps))
        if minutes > 120 { minutes = 120 }
        else if minutes < 0 { minutes = 0 }
        return minutes
    }
    
    func updateWindow(point: NSPoint) {
        let height: Int = yToHeight(y: point.y)
        if let button = statusbarItem.button {
            let buttonLocationX: CGFloat = button.window!.frame.origin.x
            let x: Int = Int(buttonLocationX - ((CGFloat(windowSize) - button.frame.width) / 2))
            let y: Int = getScreenHeight() - height + adjustment
            wc?.window?.setFrame(NSRect(x: x, y: y, width: windowSize, height: height), display: true)
            wc?.update(minutes: yToMinutes(y: point.y), height: height)
        }
    }
}

// Popover 委托
extension AppDelegate: NSPopoverDelegate {
    func popoverWillShow(_ notification: Notification) {
        DispatchQueue.main.async {
            self.jobTextField.window?.makeFirstResponder(self.jobTextField)
            print("Popover 显示，jobTextField 设置为第一响应者")
        }
    }
}
