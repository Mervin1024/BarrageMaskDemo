//
//  SVBarrageMaskResourceCollection.swift
//  iPhoneVideo
//
//  Created by mayao's Mac on 2021/8/18.
//  Copyright © 2021 SOHU. All rights reserved.
//

import Foundation

extension SVBarrageMaskResourceCollection {
    /// 单个 SVG 遮罩的文件信息
    struct SVGResource {
        /// 该遮罩的时间戳（单位 s）
        let timeStamp: TimeInterval
        /// 本地文件地址
        let fileUrl: URL?
    }
}

class SVBarrageMaskResourceCollection {
    /// 目前已加载的所有资源集合
    private var totalResourceArray = Array<SVGResource>()
    
    //MARK: --- Init ---
    init() {
        loadMaskLayerInfoList()
    }
    
    //MARK: --- Public ---
    /// 加载 timeStamp 所属的时间片范围内的 SVG 资源，读取本地或网络下载
    /// - Parameter timeStamp: 播放时间戳
    /// - Parameter preloadEnabled: 当前片段有可能触发下一篇段的提前加载。为 false 则关闭触发
    func loadMaskLayerInfoList() {
        guard let directoryURL = Bundle.main.url(forResource: "astzb1_svgo_15fps5", withExtension: nil) else {
            return
        }
        var totalArray = self.generateSVGResource(from: directoryURL)
        totalArray.sort { $0.timeStamp < $1.timeStamp }
        self.totalResourceArray.append(contentsOf: totalArray)
    }
    
    /// 二分法查找最接近的那一帧蒙版
    /// approximate: 相差多少算接近，默认34毫秒（屏幕刷新率默认一帧 16.7 毫秒，这里误差设定 2 帧内）
    subscript(timeStamp: TimeInterval, approximate: TimeInterval = 0.034) -> SVGResource? {
        var low = 0, high = totalResourceArray.count - 1
        var mid = (low + high) >> 1
        while low <= high {
            let mask = totalResourceArray[mid]
            if timeStamp == mask.timeStamp {
                return mask
            } else if timeStamp < mask.timeStamp {
                high = mid - 1
            } else {
                if timeStamp - mask.timeStamp <= approximate {
                    return mask
                } else {
                    low = mid + 1
                }
            }
            mid = (low + high) >> 1
        }
        return nil
    }
    
    //MARK: --- Private ---
    /// 根据解压目录解析本地资源
    private func generateSVGResource(from directoryURL: URL) -> [SVGResource] {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directoryURL.path) else {
            print("[AI弹幕文件] 提取文件目录失败 - URL: \(directoryURL)")
            return []
        }

        var dataArray = [SVGResource]()
        contents.forEach {
            let url = directoryURL.appendingPathComponent($0)
            guard url.pathExtension.lowercased() == "svg" else {
                /// 文件后缀必须是 png
                print("[AI弹幕文件] 出现无法处理的文件类型 - URL: \(url.lastPathComponent)")
                return
            }
            let fileName = url.deletingPathExtension().lastPathComponent
            let times = fileName.components(separatedBy: "_")
            guard times.count >= 4 else {
                /// 正确的文件命名规则是 “h_m_s_ms” 或者 “h_m_s_ms_x”，x 代表片段结尾
                return
            }
            let timeStamp: TimeInterval = {
                var t: TimeInterval = 0
                t += (Double(times[3]) ?? 0) * 0.001    /// 毫秒
                t += (Double(times[2]) ?? 0) * 1        /// 秒
                t += (Double(times[1]) ?? 0) * 60       /// 分
                t += (Double(times[0]) ?? 0) * 3600     /// 时
                return t
            }()
            dataArray.append(.init(timeStamp: timeStamp, fileUrl: url))
            if times.count > 4,
               times[4].lowercased() == "x" {
                /// 表明这一帧是该片段最后一帧（视频帧，刷新率25），显示完后结束蒙版效果
                dataArray.append(.init(timeStamp: timeStamp+0.04, fileUrl: nil))
            }
        }
        return dataArray
    }
}
