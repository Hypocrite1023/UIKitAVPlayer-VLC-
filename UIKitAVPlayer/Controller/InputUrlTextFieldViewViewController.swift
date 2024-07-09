//
//  InputUrlTextFieldViewViewController.swift
//  UIKitAVPlayer
//
//  Created by 邱翊均 on 2024/7/2.
//

import UIKit
import MobileVLCKit

class InputUrlTextFieldViewViewController: UIViewController {
    
    var inputUrlTextFieldView: InputUrlTextFieldView!
//    var avPlayer: AVPlayerModel?
    var vlcMediaPlayer = VLCMediaPlayer()
    var vlcMedia: VLCMedia?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        inputUrlTextFieldView = InputUrlTextFieldView(frame: UIScreen.main.bounds)
        inputUrlTextFieldView.urlInputField.text = "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        inputUrlTextFieldView.submitButtonDelegate = self
        self.view.addSubview(inputUrlTextFieldView)
        inputUrlTextFieldView.setupPortraitConstraints()
        print(self.view.frame)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        inputUrlTextFieldView.setupPortraitConstraints()
    }
    
    deinit {
        print("InputUrlTextFieldViewViewController deinit")
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension InputUrlTextFieldViewViewController: InputUrlTextFieldButtonTapDelegate {
    func urlSubmitButtonTap(sender: UIButton) {
        if let inputURL = inputUrlTextFieldView.urlInputField.text {
            inputUrlTextFieldView.urlInputField.resignFirstResponder()
            print(inputURL.description)
            if let url = URL(string: inputURL) {
                if UIApplication.shared.canOpenURL(url) {
//                    avPlayer = AVPlayerModel(url: url)
//                    vlcMediaPlayer = VLCMediaPlayer()
//                    vlcMediaPlayer.drawable = inputUrlTextFieldView.playerView
//                    vlcMediaPlayer.media = VLCMedia(url: url)
//                    vlcMediaPlayer.play()
                    vlcMedia = VLCMedia(url: url)
                    vlcMedia?.addOption(":network-caching=3000")
                    vlcMedia?.addOption(":avcodec-hw=auto")
                    self.inputUrlTextFieldView.urlInputField.text?.removeAll()
                    navigationController?.pushViewController(MainViewViewController(vlcMedia: vlcMedia!), animated: true)
//                    navigationController?.pushViewController(VideoViewController(mediaPlayer: vlcMediaPlayer, frame: UIScreen.main.bounds), animated: true)

                } else {
                    print("wrong url")
                }
            }
        }
    }
}
