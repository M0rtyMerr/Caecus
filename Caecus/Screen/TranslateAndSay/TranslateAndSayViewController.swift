//
//  TranslateAndSayViewController.swift
//  Caecus
//
//  Created by Anton Nazarov on 06/03/2019.
//  Copyright © 2019 Anton Nazarov. All rights reserved.
//

import UIKit
import RxSwift
import Reusable
import ReactorKit
import TextToSpeech
import AVKit

final class TranslateAndSayViewController: UIViewController, StoryboardBased, StoryboardView {
    @IBOutlet private var sourceTextView: UITextView!
    @IBOutlet private var targetTextView: UITextView!
    @IBOutlet private var translateButton: UIButton!
    @IBOutlet private var soundButton: UIButton!
    @IBOutlet private var languagesTableView: UITableView!
    private var player: AVAudioPlayer!
    var disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        languagesTableView.register(cellType: LanguageTableViewCell.self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    func bind(reactor: TranslateAndSayReactor) {
        reactor.state.map { $0.text }.asDriver(onErrorJustReturn: "").drive(sourceTextView.rx.text).disposed(by: disposeBag)
        reactor.state.map { $0.translation }.asDriver(onErrorJustReturn: "").drive(targetTextView.rx.text).disposed(by: disposeBag)
        
        reactor.state.map { $0.voices }
            .distinctUntilChanged()
            .asDriver(onErrorJustReturn: [])
            .drive(languagesTableView.rx.items(LanguageTableViewCell.self)) { _, voice, cell in
                cell.configure(voice: voice)
            }
            .disposed(by: disposeBag)
        
        reactor.state.map { $0.soundData }
            .distinctUntilChanged()
            .bind { [unowned self] in
                guard let data = $0 else { return }
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try? AVAudioSession.sharedInstance().setActive(true)
                self.player = try! AVAudioPlayer(data: data)
                self.player.prepareToPlay()
                self.player.play()
            }
            .disposed(by: disposeBag)
        
        bindOutlets(reactor: reactor)
    }
}

// MARK: - Private
private extension TranslateAndSayViewController {
    func bindOutlets(reactor: TranslateAndSayReactor) {
        translateButton.rx.tap.map { .translate }.bind(to: reactor.action).disposed(by: disposeBag)
        soundButton.rx.tap.map { .sound }.bind(to: reactor.action).disposed(by: disposeBag)
        languagesTableView.rx.modelSelected(Voice.self).map(Reactor.Action.chooseVoice).bind(to: reactor.action).disposed(by: disposeBag)
//        languagesTableView.rx.itemSelected.bind {
//            self.languagesTableView.selectRow(at: $0, animated: false, scrollPosition: .none)
//            }
    }
}
