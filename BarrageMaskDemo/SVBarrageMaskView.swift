//
//  SVBarrageMaskView.swift
//  iPhoneVideo
//
//  Created by mayao's Mac on 2021/8/18.
//  Copyright © 2021 SOHU. All rights reserved.
//

import UIKit
import SVGKit

@objc class SVBarrageMaskView: UIView {
    //MARK: --- Public Properties ---
    /// 设置第 x 秒的弹幕遮罩
    @objc var timeStamp: TimeInterval = 0 {
        didSet {
            guard !timeStamp.isInfinite && !timeStamp.isNaN else { return }
            if let currentMaskResource = self.currentMaskResource {
                let diff = abs(currentMaskResource.timeStamp - timeStamp)
                if diff == 0 {
                    return
                }
                /// 500 毫秒内没有后续帧，就置空
                if diff > 0.5 {
                    self.currentMaskResource = nil
                }
            }
            /// 寻找最接近当前 time 的帧
            if let info = resourceCollection[timeStamp],
               info.timeStamp != self.currentMaskResource?.timeStamp {
                print("[AI弹幕遮罩] 设置当前帧 timeStamp: \(timeStamp), fileName: \(info.fileUrl?.lastPathComponent ?? "nil")")
                self.currentMaskResource = info
            }
        }
    }
        
    
    //MARK: --- Private Properties ---
    private var resourceCollection = SVBarrageMaskResourceCollection()
    
    private var currentMaskResource: SVBarrageMaskResourceCollection.SVGResource? {
        didSet {
            func clearMask() {
                self.layer.mask = nil
                print("[AI弹幕遮罩] 当前帧置空")
            }
            guard let fileUrl = currentMaskResource?.fileUrl else {
                clearMask()
                return
            }
            let beginTime = CFAbsoluteTimeGetCurrent()
            generateMaskLayer(fileUrl) { (layer) in
                guard let layer = layer,
                      fileUrl == self.currentMaskResource?.fileUrl else {
                    clearMask()
                    return
                }
                self.layer.mask = layer
                let costTime = (CFAbsoluteTimeGetCurrent() - beginTime) * 1000
                print("[AI弹幕遮罩] 当前帧遮罩 Layer 设置耗时 \(String(format: "%.3f", costTime))ms")
            }
        }
    }
    
    //MARK: --- Init ---
    private var tempFrame: CGRect = .zero
    override func layoutSubviews() {
        if tempFrame != self.layer.bounds {
            tempFrame = self.layer.bounds
            if let resource = self.currentMaskResource {
                /// 触发 didSet
                self.currentMaskResource = resource
            }
        }
        super.layoutSubviews()
    }
    
    //MARK: --- Public ---
        
    //MARK: --- Private ---
    private lazy var svgParseQueue = DispatchQueue(label: "SV.SVBarrageMaskView.SVGParseQueue",
                                                   qos: .default,
                                                   attributes: .concurrent)
    private func generateMaskLayer(_ fileUrl: URL,
                                   complete: @escaping (CALayer?)->Void) {
        let viewBounds = self.bounds
        func generateMaskLayer(image: SVGKImage) -> CALayer {
            /// SVG 图像是根据视频实际画面大小进行绘制出来的，因此图像 Size 的比例不等于播放器 View 的比例
            /// 这里需要计算 SVG 图像在 scaleAspectFit 填充模式下，调整后的 frame
            func scaleAspectFitResult(_ imageSize: CGSize) -> (frame: CGRect, transform: CGAffineTransform) {
                let originalAspect = imageSize.height / imageSize.width
                let containerAspect = viewBounds.height / viewBounds.width
                /// PlayView / SVG 的比值
                var scale: CGFloat = 1
                if originalAspect <= containerAspect {
                    scale = viewBounds.width / imageSize.width
                } else {
                    scale = viewBounds.height / imageSize.height
                }
                /// SVG 计算填充后大小的 Size
                let adjustedSize = CGSize(width: imageSize.width * scale,
                                          height: imageSize.height * scale)
                /// 居中后的顶点坐标
                let origin = CGPoint(x: (viewBounds.width - adjustedSize.width) / 2,
                                     y: (viewBounds.height - adjustedSize.height) / 2)
                /// 居中后的 frame
                let frame = CGRect(origin: origin, size: adjustedSize)
                
                /// 计算形变参数
                let imageBounds = CGRect(origin: .zero, size: imageSize)
                let tx = viewBounds.midX - imageBounds.midX
                let ty = viewBounds.midY - imageBounds.midY
                let transform = CGAffineTransform.identity.translatedBy(x: tx, y: ty).scaledBy(x: scale, y: scale)
                return (frame, transform)
            }
            let scaleResult = scaleAspectFitResult(image.size)
            
            var gapLayers = [CALayer]()
            /// 如果 SVG 图像不能填充满播放器 View，可能会使画面边缘的弹幕无法显示，
            /// 因此需要在 SVG 边缘填补画面
            func gapLayer(_ frame: CGRect) -> CALayer {
                let layer = CALayer()
                layer.frame = frame
                layer.backgroundColor = UIColor.systemYellow.cgColor
                return layer
            }
            if lroundf(Float(scaleResult.frame.height)) < lroundf(Float(viewBounds.height)) {
                /// 上下有空隙，需要填补
                /// -------------------------
                /// |        gapView        |
                /// |-----------------------|
                /// |          SVG          |
                /// |-----------------------|
                /// |        gapView        |
                /// -------------------------
                let gapHeight = (viewBounds.height - scaleResult.frame.height) / 2
                gapLayers.append(gapLayer(.init(x: 0,
                                                y: 0,
                                                width: scaleResult.frame.width,
                                                height: gapHeight)))
                gapLayers.append(gapLayer(.init(x: 0,
                                                y: scaleResult.frame.maxY,
                                                width: scaleResult.frame.width,
                                                height: gapHeight)))
            } else if lroundf(Float(scaleResult.frame.width)) < lroundf(Float(viewBounds.width)) {
                /// 左右有空隙，需要填补
                /// -------------------------
                /// |    |             |    |
                /// |    |             |    |
                /// |    |     SVG     |    |
                /// |    |             |    |
                /// |    |             |    |
                /// -------------------------
                let gapWidth = (viewBounds.width - scaleResult.frame.width) / 2
                gapLayers.append(gapLayer(.init(x: 0,
                                                y: 0,
                                                width: gapWidth,
                                                height: scaleResult.frame.height)))
                gapLayers.append(gapLayer(.init(x: scaleResult.frame.maxX,
                                                y: 0,
                                                width: gapWidth,
                                                height: scaleResult.frame.height)))
            }
            let layer = CALayer()
            layer.frame = viewBounds
            gapLayers.forEach {
                layer.addSublayer($0)
            }
            if let caLayerTree = image.caLayerTree {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                /// 关闭 layer 的隐式动画效果
                caLayerTree.setAffineTransform(scaleResult.transform)
                CATransaction.commit()
                layer.addSublayer(caLayerTree)
            }
            return layer
        }
        
        /// 异步解析 SVGKImage
        svgParseQueue.async {
            guard let svgImage = SVGKImage(contentsOfFile: fileUrl.path) else {
                DispatchQueue.main.async {
                    complete(nil)
                }
                return
            }
            let layer = generateMaskLayer(image: svgImage)
            DispatchQueue.main.async {
                complete(layer)
            }
        }
    }
}
