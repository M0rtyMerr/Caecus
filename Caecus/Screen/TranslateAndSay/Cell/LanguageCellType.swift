//
//  LanguageCellType.swift
//  Caecus
//
//  Created by Anton Nazarov on 06/03/2019.
//  Copyright © 2019 Anton Nazarov. All rights reserved.
//

import LanguageTranslator
import TextToSpeech

enum LanguageCellType {
    case voice(Voice)
    case language(IdentifiableLanguage)
}
