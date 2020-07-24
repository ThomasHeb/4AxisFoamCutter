
import Foundation

// MARK: - Registry

extension CharacterSet {
    func containsUnicodeScalars(of character: Character) -> Bool {
        return character.unicodeScalars.allSatisfy(contains(_:))
    }
}

extension String {
    func localized(withComment comment: String? = nil) -> String {
        return NSLocalizedString(self, comment: comment ?? "")
    }
    // usage:
    // "Goodbye".localized()
    // "Hello".localized(withComment: "Simple greeting")
    
    func trimmingLeftCharacters(in charSet: CharacterSet) -> String {
        var s: String
        var string: String
        
        string = self
    
        while string.count > 0 {
            guard let c = string.first else {
                return string
            }
            s = String(c)
            if s.trimmingCharacters(in: charSet) == "" {
                string = String(string.dropFirst())
            } else {
                return string
            }
        }
        return ""
    }
    subscript (i: Int) -> Character {
        return self[index(startIndex, offsetBy: i)]
    }
    subscript (bounds: CountableRange<Int>) -> Substring {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[start ..< end]
    }
    subscript (bounds: CountableClosedRange<Int>) -> Substring {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[start ... end]
    }
    subscript (bounds: CountablePartialRangeFrom<Int>) -> Substring {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(endIndex, offsetBy: -1)
        return self[start ... end]
    }
    subscript (bounds: PartialRangeThrough<Int>) -> Substring {
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[startIndex ... end]
    }
    subscript (bounds: PartialRangeUpTo<Int>) -> Substring {
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[startIndex ..< end]
    }
}

extension Double {
    public func round(_ fractionDigits: Int) -> Double {
        let multiplier = pow(10, Double(fractionDigits))
        return Darwin.round(self * multiplier) / multiplier
    }
}

extension Dictionary where Value: Equatable {
    /// Returns all keys mapped to the specified value.
    /// ```
    /// let dict = ["A": 1, "B": 2, "C": 3]
    /// let keys = dict.keysForValue(2)
    /// assert(keys == ["B"])
    /// assert(dict["B"] == 2)
    /// ```
    func keysForValue(_ value: Value) -> [Key] {
        return compactMap { (key: Key, val: Value) -> Key? in
            value == val ? key : nil
        }
    }
}

extension Date {
    public var string: String? {
        get {
            let formatter : DateFormatter = DateFormatter()
            formatter.dateFormat =   "dateFormat".localized()
            return formatter.string(from: self)
        }
    }
}
extension Bool {
    public var stringValue: String {
        get {
            if self == true {
                return "1"
            } else {
                return "0"
            }
        }
    }
}
extension Array where Element:Equatable {
    func removeDuplicates() -> [Element] {
        var result = [Element]()
        for value in self {
            if result.contains(value) == false {
                if value is String {
                    if (value as! String) != "" {
                        result.append(value)
                    }
                } else {
                    result.append(value)
                }
            }
        }
        return result
    }
}


