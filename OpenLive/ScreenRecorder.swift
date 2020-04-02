//
//  ScreenRecorder.swift
//  OpenLive
//
//  Created by cyril chaillan on 27/03/2020.
//  Copyright © 2020 Agora. All rights reserved.
//

import Foundation
import ReplayKit
import AVKit


class ScreenRecorder
{
    var assetWriter:AVAssetWriter!
    var videoInput:AVAssetWriterInput!
    var audioInput:AVAssetWriterInput!
    var micInput: AVAssetWriterInput!
    var videoUrl: String = ""

    //MARK: Screen Recording
    func startRecording(withFileName fileName: String, recordingHandler:@escaping (Error?)-> Void) {
        if #available(iOS 11.0, *) {
            self.videoUrl = ReplayFileUtil.filePath(fileName)
            let fileURL = URL(fileURLWithPath: self.videoUrl)
            assetWriter = try! AVAssetWriter(outputURL: fileURL, fileType: AVFileType.mp4)
            
            let videoOutputSettings: Dictionary<String, Any> = [
                AVVideoCodecKey : AVVideoCodecType.h264,
                AVVideoWidthKey : floor(UIScreen.main.bounds.size.width / 16) * 16,
                AVVideoHeightKey : floor(UIScreen.main.bounds.size.height / 16) * 16
            ];
            let audioSettings = [
            AVFormatIDKey : kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey : 2,
            AVSampleRateKey : 44100.0,
            AVEncoderBitRateKey: 192000
            ] as [String : Any]
//            kAudioFormatMPEG4AAC_HE

            videoInput  = AVAssetWriterInput (mediaType: .video, outputSettings: videoOutputSettings)
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            micInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            videoInput.expectsMediaDataInRealTime = true
            audioInput.expectsMediaDataInRealTime = true
            micInput.expectsMediaDataInRealTime = true
            if assetWriter.canAdd(videoInput) {
                assetWriter.add(videoInput)
            }
            if assetWriter.canAdd(audioInput) {
                assetWriter.add(audioInput)
            }
            if assetWriter.canAdd(micInput) {
                assetWriter.add(micInput)
            }

            RPScreenRecorder.shared().isMicrophoneEnabled = true
            RPScreenRecorder.shared().startCapture(handler: { (sample, bufferType, error) in
//                print(sample,bufferType,error)

                recordingHandler(error)

                if CMSampleBufferDataIsReady(sample) {
                    DispatchQueue.main.async {
                        if self.assetWriter.status == AVAssetWriter.Status.unknown {
                            self.assetWriter.startWriting()
                            self.assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sample))
                        }
                    }

                    if self.assetWriter.status == AVAssetWriter.Status.failed {
                        print("Error occured, status = \(self.assetWriter.status.rawValue), \(self.assetWriter.error!.localizedDescription) \(String(describing: self.assetWriter.error))")
                        return
                    }

                    if (bufferType == .video) {
                        if self.videoInput.isReadyForMoreMediaData {
                            DispatchQueue.main.async {
                                self.videoInput.append(sample)
                            }
                        }
                    } else if bufferType == .audioApp {
                        if self.audioInput.isReadyForMoreMediaData {
                            DispatchQueue.main.async {
                                self.audioInput.append(sample)
                            }
                        }
                    } else if bufferType == .audioMic {
                       if self.micInput.isReadyForMoreMediaData {
                        DispatchQueue.main.async {
                            self.micInput.append(sample)
                        }
                       }
                   }

                }

            }) { (error) in
                recordingHandler(error)
//                debugPrint(error)
            }
        } else {
            // Fallback on earlier versions
        }
    }

    func stopRecording(handler: @escaping (Error?) -> Void) {
        if #available(iOS 11.0, *) {
            RPScreenRecorder.shared().stopCapture { (error) in
                handler(error)
                DispatchQueue.main.async {
                    self.audioInput.markAsFinished()
                    self.videoInput.markAsFinished()
                    self.micInput.markAsFinished()
                    self.assetWriter.finishWriting {
//                        print(ReplayFileUtil.fetchAllReplays())
                        UISaveVideoAtPathToSavedPhotosAlbum(self.videoUrl, nil, nil, nil)
                    }
                }
            }
        } else {
            // Fallback on earlier versions
        }
    }


}
