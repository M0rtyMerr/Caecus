//
//  UITableView+items.swift
//  Divy Rewards
//
//  Created by Anton Nazarov on 10/10/2018.
//  Copyright © 2018 Scal.io. All rights reserved.
//

import Reusable
import RxSwift

extension Reactive where Base: UITableView {
    func items<S: Sequence, Cell: UITableViewCell & Reusable, O: ObservableType>(_ cellType: Cell.Type)
        -> (_ source: O)
        -> (_ configureCell: @escaping (Int, S.Iterator.Element, Cell) -> Void)
        -> Disposable where O.E == S {
            return items(cellIdentifier: cellType.reuseIdentifier, cellType: cellType)
    }
}
