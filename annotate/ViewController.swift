//
//  ViewController.swift
//  annotate
//
//  Created by Aleksandr Vinogradov on 11/4/18.
//  Copyright © 2018 grapeit. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
  @IBOutlet weak var pictureView: UIImageView!
  @IBOutlet weak var takePictureButton: UIButton!
  @IBOutlet weak var loadPictureButton: UIButton!
  @IBOutlet weak var infoTextView: UITextView!

  let annotator = Annotator()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.annotator.delegate = self
    self.infoTextView.isEditable = false
  }
  
  @IBAction func takePictureButtonClicked(_ sender: UIButton) {
    let vc = UIImagePickerController()
    vc.sourceType = sender === loadPictureButton ? .photoLibrary : .camera
    vc.allowsEditing = true
    vc.delegate = self
    present(vc, animated: true)
  }

  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.dismiss(animated: true)
    guard let image = info[.editedImage] as? UIImage else {
      return
    }
    pictureView.image = image
    infoTextView.text = "processing..."
    self.annotator.annotate(image)
  }
}

extension ViewController: AnnotatorDelegate {
  func annotation(_ annotation: Annotation) {
    infoTextView.text = annotation.describe()
  }

  func annotationFailed() {
    infoTextView.text = "something went wrong :("
  }
}
