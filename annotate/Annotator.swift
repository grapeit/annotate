//
//  Annotator.swift
//  annotator
//
//  Created by Aleksandr Vinogradov on 11/4/18.
//  Copyright © 2018 grapeit. All rights reserved.
//

import UIKit

protocol AnnotatorDelegate {
  func annotation(_ annotation: Annotation)
  func annotationFailed()
}

class Annotator {
  var delegate: AnnotatorDelegate?

  func annotate(_ image: UIImage) {
    DispatchQueue.global(qos: .userInitiated).async {
      guard let data = image.jpegData(compressionQuality: 0.0) else {
        DispatchQueue.main.sync {
          self.delegate?.annotationFailed()
        }
        return
      }
      self.annotate(imageData: data)
    }
  }

  private func annotate(imageData: Data) {
    guard let url = URL(string: "https://vision.googleapis.com/v1/images:annotate?key=AIzaSyDco8FRFXVOagkWAwiFeTbQC-hl6yWkRE4") else {
      DispatchQueue.main.sync {
        self.delegate?.annotationFailed()
      }
      return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    var body = """
{"requests": [{
"features": [{"type": "SAFE_SEARCH_DETECTION"}, {"type": "FACE_DETECTION"}, {"type": "LANDMARK_DETECTION"}],
"image": {"content": "
"""
    body += imageData.base64EncodedString()
    body += "\"}}]}"
    request.httpBody = body.data(using: .utf8)
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      guard let data = data, error == nil else {
        DispatchQueue.main.sync {
          self.delegate?.annotationFailed()
        }
        return
      }
      self.parseAndReport(data: data)
    }
    task.resume()
  }

  private func parseAndReport(data: Data) {
    guard let responses = try? JSONDecoder().decode(Responses.self, from: data), responses.responses.count > 0 else {
      DispatchQueue.main.sync {
        self.delegate?.annotationFailed()
      }
      return
    }
    DispatchQueue.main.sync {
      self.delegate?.annotation(Annotation(responses.responses[0]))
    }
  }
}

class Annotation {
  let adult: Float
  let spoof: Float
  let medical: Float
  let violence: Float
  let racy: Float
  let faces: Int
  var joy: Float!
  var sorrow: Float!
  var anger: Float!
  var surprise: Float!
  var headwear: Float!
  var landmarks: [String]?

  fileprivate init(_ r: Response) {
    self.adult = likelihood(r.safeSearchAnnotation.adult)
    self.spoof = likelihood(r.safeSearchAnnotation.spoof)
    self.medical = likelihood(r.safeSearchAnnotation.medical)
    self.violence = likelihood(r.safeSearchAnnotation.violence)
    self.racy = likelihood(r.safeSearchAnnotation.racy)

    self.faces = r.faceAnnotations?.count ?? 0
    if self.faces > 0, let face = r.faceAnnotations?[0] {
      self.joy = likelihood(face.joyLikelihood)
      self.sorrow = likelihood(face.sorrowLikelihood)
      self.anger = likelihood(face.angerLikelihood)
      self.surprise = likelihood(face.surpriseLikelihood)
      self.headwear = likelihood(face.headwearLikelihood)
    }

    if let landmarks = r.landmarkAnnotations {
      self.landmarks = landmarks.compactMap { $0.description }
    }
  }

  func describe() -> String {
    var text = String(format: "adult: %.0f%%\n", self.adult * 100)
    text += String(format: "spoof: %.0f%%\n", self.spoof * 100)
    text += String(format: "medical: %.0f%%\n", self.medical * 100)
    text += String(format: "violence: %.0f%%\n", self.violence * 100)
    text += String(format: "racy: %.0f%%\n", self.racy * 100)
    if self.faces > 0 {
      if self.faces > 1 {
        text += String(format: "\n%d faces detected, guess which one is annotated\n", self.faces)
      }
      text += String(format: "joy: %.0f%%\n", self.joy * 100)
      text += String(format: "sorrow: %.0f%%\n", self.sorrow * 100)
      text += String(format: "anger: %.0f%%\n", self.anger * 100)
      text += String(format: "surprise: %.0f%%\n", self.surprise * 100)
      text += String(format: "headwear: %.0f%%\n", self.headwear * 100)
    } else {
      text += "\nno faces\n"
    }
    if let landmarks = self.landmarks {
      text += "\nlandmarks: "
      var first = true
      for i in landmarks {
        if first {
          first = false
        } else {
          text += ", "
        }
        text += i
      }
    } else {
      text += "\nno landmarks\n"
    }
    return text
  }
}

fileprivate struct Responses: Decodable {
  let responses: [Response]
}

fileprivate struct Response: Decodable {
  let safeSearchAnnotation: SafeSearchAnnotation
  let faceAnnotations: [FaceAnnotation]?
  let landmarkAnnotations: [LandmarkAnnotation]?
}

fileprivate struct SafeSearchAnnotation: Decodable {
  let adult: String
  let spoof: String
  let medical: String
  let violence: String
  let racy: String
}

fileprivate struct FaceAnnotation: Decodable {
  let joyLikelihood: String
  let sorrowLikelihood: String
  let angerLikelihood: String
  let surpriseLikelihood: String
  let underExposedLikelihood: String
  let blurredLikelihood: String
  let headwearLikelihood: String
}

fileprivate struct LandmarkAnnotation: Decodable {
  let description: String
}

fileprivate func likelihood(_ s: String) -> Float {
  switch s {
  case "VERY_UNLIKELY":
    return 0.0
  case "UNLIKELY":
    return 0.25
  case "POSSIBLE":
    return 0.5
  case "LIKELY":
    return 0.75
  case "VERY_LIKELY":
    return 1.0
  default:
    return 0.0
  }
}
