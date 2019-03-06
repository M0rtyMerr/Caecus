//
//  LanguageTableViewCell.swift
//  Caecus
//
//  Created by Anton Nazarov on 06/03/2019.
//  Copyright © 2019 Anton Nazarov. All rights reserved.
//

import UIKit
import Reusable
import TextToSpeech

final class LanguageTableViewCell: UITableViewCell, NibReusable {
    @IBOutlet private var titleLabel: UILabel!
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        accessoryType = selected ? .checkmark : .none
    }
    
    func configure(voice: Voice) {
        titleLabel.text = "\(voice.language) \(voice.gender)"
    }
}
