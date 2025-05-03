import Foundation

func readJavaCode() -> String {
    FileHelper.readTextFile(named: "File", withExtension: "txt") ?? ""
}

func readKeywordsFromFile() -> [String] {
    FileHelper.readLinesFromFile(named: "reserved_java")
}


// MARK: Lexical Analyzer
let javaCode = readJavaCode()
let javaKeywords = readKeywordsFromFile()
let operators = ["+", "-", "*", "/", "%", "=", "==", "!=", "<", ">", "<=", ">=", "&&", "||", "!"]

enum TokenType: String {
    case keyword
    case identifier
    case `operator`
    case literal
    case delimiter
    case error
}

struct Token {
    let type: TokenType
    let lexeme: String
    let line: Int
    
    func description() -> String {
        return "[\(type.rawValue)] \"\(lexeme)\""
    }
}

class LexicalAnalyzer {
    private var lines: [String] = []
    private var tokens: [Token] = []
    
    // if it starts with /*
    private var isMultilineComment = false
    
    init(sourceCode: String) {
        let noComments = removeComments(sourceCode)
        self.lines = noComments.components(separatedBy: .newlines)
    }
    
    private func removeComments(_ sourceCode: String) -> String {
        var code = sourceCode
        
        while let startRange = code.range(of: "/*") {
            if let endRange = code.range(of: "*/", range: startRange.upperBound..<code.endIndex) {
                code.replaceSubrange(startRange.lowerBound..<endRange.upperBound, with: " ")
            } else {
                code.removeSubrange(startRange.lowerBound..<code.endIndex)
                break
            }
        }
        
        var result = ""
        for line in code.components(separatedBy: .newlines) {
            if let commentRange = line.range(of: "//") {
                result += line[..<commentRange.lowerBound] + "\n"
            } else {
                result += line + "\n"
            }
        }
        
        return result
    }
    
    func analyze() -> [Token] {
        for (lineIndex, line) in lines.enumerated() {
            tokenizeLine(line, lineNumber: lineIndex + 1)
        }
        return tokens
    }
    
    // break lines of code
    private func tokenizeLine(_ text: String, lineNumber: Int) {
        var temp = text.trimmingCharacters(in: .whitespaces)
        while !temp.isEmpty {
            if let (token, len) = extractNextToken(temp, lineNumber: lineNumber) {
                tokens.append(token)
                temp.removeFirst(len)
                temp = temp.trimmingCharacters(in: .whitespaces)
            }
        }
    }
    
    private func extractNextToken(_ str: String, lineNumber: Int) -> (Token, Int)? {
        if let (token, len) = matchLiteral(str, lineNumber: lineNumber) { return (token, len) }
        if let (token, len) = matchOperator(str, lineNumber: lineNumber) { return (token, len) }
        if let (token, len) = matchBracket(str, lineNumber: lineNumber) { return (token, len) }
        if let (token, len) = matchSpecialCharacter(str, lineNumber: lineNumber) { return (token, len) }
        if let (token, len) = matchKeyword(str, lineNumber: lineNumber) { return (token, len) }
        if let (token, len) = matchIdentifier(str, lineNumber: lineNumber) { return (token, len) }
        
        if let (token, len) = matchInvalidStringLiteral(str, lineNumber: lineNumber) { return (token, len) }
        if let (token, len) = matchInvalidIdentifier(str, lineNumber: lineNumber) { return (token, len) }
        return nil
    }
    
    private func matchLiteral(_ str: String, lineNumber: Int) -> (Token, Int)? {
        // matches quoted string
        let stringPattern = #"^"([^"\\]|\\.)*""#
        if let match = str.range(of: stringPattern, options: .regularExpression) {
            let literal = String(str[match])
            return (Token(type: .literal, lexeme: literal, line: lineNumber), literal.count)
        }
        // numbers
        let numberPattern = "^[0-9]+(\\.[0-9]+)?"
        if let match = str.range(of: numberPattern, options: .regularExpression) {
            let literal = String(str[match])
            return (Token(type: .literal, lexeme: literal, line: lineNumber), literal.count)
        }
        return nil
    }
    
    private func matchOperator(_ str: String, lineNumber: Int) -> (Token, Int)? {
        let sortedOps = operators.sorted { $0.count > $1.count }
        let pattern = "^(" + sortedOps.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|") + ")"
        if let match = str.range(of: pattern, options: .regularExpression) {
            let op = String(str[match])
            return (Token(type: .operator, lexeme: op, line: lineNumber), op.count)
        }
        return nil
    }
    
    private func matchBracket(_ str: String, lineNumber: Int) -> (Token, Int)? {
        let pattern = "^[\\(\\)\\{\\}\\[\\]]"
        if let match = str.range(of: pattern, options: .regularExpression) {
            let bracket = String(str[match])
            return (Token(type: .delimiter, lexeme: bracket, line: lineNumber), bracket.count)
        }
        return nil
    }
    
    private func matchSpecialCharacter(_ str: String, lineNumber: Int) -> (Token, Int)? {
        let pattern = "^[,.;]"
        if let match = str.range(of: pattern, options: .regularExpression) {
            let special = String(str[match])
            return (Token(type: .delimiter, lexeme: special, line: lineNumber), special.count)
        }
        return nil
    }
    
    private func matchKeyword(_ str: String, lineNumber: Int) -> (Token, Int)? {
        let pattern = "^\\b(" + javaKeywords.joined(separator: "|") + ")\\b"
        if let match = str.range(of: pattern, options: .regularExpression) {
            let keyword = String(str[match])
            return (Token(type: .keyword, lexeme: keyword, line: lineNumber), keyword.count)
        }
        return nil
    }
    
    private func matchIdentifier(_ str: String, lineNumber: Int) -> (Token, Int)? {
        let pattern = "^[a-zA-Z_][a-zA-Z0-9_]*"
        if let match = str.range(of: pattern, options: .regularExpression) {
            let identifier = String(str[match])
            return (Token(type: .identifier, lexeme: identifier, line: lineNumber), identifier.count)
        }
        return nil
    }
    
    private func matchInvalidStringLiteral(_ str: String, lineNumber: Int) -> (Token, Int)? {
        // starts with " but doesn't end with "
        let pattern = "^\"([^\"\n\\\\]|\\\\.)*$"
        if let match = str.range(of: pattern, options: .regularExpression) {
            let errorStr = String(str[match])
            return (Token(type: .error, lexeme: errorStr, line: lineNumber), errorStr.count)
        }
        return nil
    }
    
    private func matchInvalidIdentifier(_ str: String, lineNumber: Int) -> (Token, Int)? {
        // if it starts with any of the invalid identifiers
        let pattern = "^[#$%@][a-zA-Z0-9_]+"
        if let match = str.range(of: pattern, options: .regularExpression) {
            let errorId = String(str[match])
            return (Token(type: .error, lexeme: errorId, line: lineNumber), errorId.count)
        }
        return nil
    }
    
    func printAllTokens() {
        for token in tokens {
            print("\(token.line): \(token.description())")
        }
    }
    
    func printErrorsOnly() {
        for token in tokens {
            if token.type == .error {
                print("\(token.line): \(token.description())")
            }
        }
    }
    
}

let analyzer = LexicalAnalyzer(sourceCode: javaCode)
let tokens = analyzer.analyze()

// all tokens found
print("results:")
analyzer.printAllTokens()
print("errors:")
analyzer.printErrorsOnly()

// MARK: Helpers
class FileHelper {
    static func readTextFile(named filename: String, withExtension ext: String = "txt") -> String? {
        guard let fileURL = Bundle.main.url(forResource: filename, withExtension: ext) else {
            print("Error: Could not find \(filename).\(ext) in the bundle")
            return nil
        }
        
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            return content
        } catch {
            print("Error reading file \(filename).\(ext): \(error)")
            return nil
        }
    }
    
    static func readLinesFromFile(named filename: String, withExtension ext: String = "txt") -> [String] {
        guard let content = readTextFile(named: filename, withExtension: ext) else {
            return []
        }
        
        return content.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }
    
    static func readFile(at path: String) -> String? {
        let fileURL = URL(fileURLWithPath: path)
        
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            return content
        } catch {
            print("Error reading file at \(path): \(error)")
            return nil
        }
    }
}
