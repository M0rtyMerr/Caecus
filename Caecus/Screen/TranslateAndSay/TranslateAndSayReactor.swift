//
//  TranslateAndSayReactor.swift
//  Caecus
//
//  Created by Anton Nazarov on 06/03/2019.
//  Copyright © 2019 Anton Nazarov. All rights reserved.
//

import UIKit
import ReactorKit
import LanguageTranslator
import TextToSpeech
import RxSwift

final class TranslateAndSayReactor: Reactor {
    enum Action {
        case loadVoices
        case loadLanguages
        case chooseVoice(Voice)
        case translate
        case sound
    }
    
    enum Mutation {
        case setVoices([Voice])
        case setLanguages([IdentifiableLanguage])
        case setVoice(Voice)
        case setLanguage(IdentifiableLanguage)
        case setTranslation(String)
        case setSoundData(Data)
    }
    
    struct State {
        var languages: [IdentifiableLanguage]
        var voices: [Voice]
        var selectedLanguage: IdentifiableLanguage?
        var selectedVoice: Voice?
        let text: String
        var translation: String
        var soundData: Data?
        
        init(languages: [IdentifiableLanguage] = [],
             voices: [Voice] = [],
             selectedLanguage: IdentifiableLanguage? = nil,
             selectedVoice: Voice? = nil,
             text: String,
             translation: String = "",
             soundData: Data? = nil) {
            self.languages = languages
            self.voices = voices
            self.selectedLanguage = selectedLanguage
            self.selectedVoice = selectedVoice
            self.text = text
            self.translation = translation
            self.soundData = soundData
        }
    }
    
    let initialState: State
    private let languageTranslator: LanguageTranslator
    private let textToSpeech: TextToSpeech
    
    init(text: String, credentialsService: CredentialsService) {
        languageTranslator =  LanguageTranslator(
            credentialsFile: Bundle.main.url(forResource: "translator", withExtension: "env")!,
            version: "2018-05-01"
            )!
        textToSpeech = TextToSpeech(
            credentialsFile: Bundle.main.url(forResource: "textToSpeech", withExtension: "env")!
            )!
        initialState = State(text: text)
    }
    
    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .loadLanguages:
            return .create { observer in
                self.languageTranslator.listIdentifiableLanguages { response, error in
                    guard let languages = response?.result?.languages else { return }
                    observer.onNext(.setLanguages(languages))
                }
                return Disposables.create()
            }
        case .loadVoices:
            return .create { observer in
                self.textToSpeech.listVoices { response, _ in
                    guard let voices = response?.result?.voices else { return }
                    observer.onNext(.setVoices(voices))
                }
                return Disposables.create()
            }
        case .translate:
            return .create { observer in
                self.languageTranslator.translate(
                    text: [self.currentState.text], source: "en", target: self.currentState.selectedLanguage?.language
                ) { response, error in
                    if let translations = response?.result?.translations {
                        observer.onNext(.setTranslation(translations.map { $0.translationOutput }.joined()))
                    }
                    if let error = error {
                        observer.onError(error)
                    }
                }
                return Disposables.create()
            }
        case let .chooseVoice(voice):
            let tranlationLanguage = currentState.languages.first { voice.name.contains($0.language) }
            return .merge(
                .just(.setVoice(voice)),
                .just(.setLanguage(tranlationLanguage!))
            )
        case .sound:
            guard let selectedVoice = currentState.selectedVoice else { return .empty() }
            return .create { observer in
                self.textToSpeech.synthesize(text: self.currentState.translation, accept: "audio/wav", voice: selectedVoice.name) { response, error in
                    guard let data = response?.result else { return }
                    observer.onNext(.setSoundData(data))
                }
                return Disposables.create()
            }
        }
    }
    
    func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        switch mutation {
        case let .setLanguages(languages):
            newState.languages = languages
        case let .setTranslation(translation):
            newState.translation = translation
        case let .setVoices(voices):
            newState.voices = voices
        case let .setLanguage(language):
            newState.selectedLanguage = language
        case let .setVoice(voice):
            newState.selectedVoice = voice
        case let .setSoundData(data):
            newState.soundData = data
        }
        return newState
    }
    
    func transform(action: Observable<Action>) -> Observable<Action> {
        return action.startWith(.loadLanguages, .loadVoices)
    }
}
