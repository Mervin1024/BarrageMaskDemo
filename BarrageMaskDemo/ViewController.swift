//
//  ViewController.swift
//  BarrageMaskDemo
//
//  Created by mayao's Mac on 2021/12/24.
//

import UIKit

class ViewController: UIViewController {

    lazy var maskView: SVBarrageMaskView = {
        let maskView = SVBarrageMaskView()
        maskView.backgroundColor = .black
        maskView.frame = .init(x: 0, y: 100, width: view.frame.width, height: view.frame.width / 16.0 * 9.0)
        return maskView
    }()
    
    var beginTime: TimeInterval = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(maskView)

        let link = CADisplayLink(target: self, selector: #selector(check))
        link.preferredFramesPerSecond = 60
        link.add(to: .main, forMode: .common)
        beginTime = CFAbsoluteTimeGetCurrent()
    }

    @objc func check() {
        var timeStamp: TimeInterval = 0
        if beginTime == 0 {
            beginTime = CFAbsoluteTimeGetCurrent()
        } else {
            timeStamp = CFAbsoluteTimeGetCurrent() - beginTime
        }
        maskView.timeStamp = timeStamp
    }
}

