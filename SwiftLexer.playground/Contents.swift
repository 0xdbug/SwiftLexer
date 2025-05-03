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
    case comment
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
    
    // For multi-line comment tracking
    private var inMultilineComment = false
    private var multilineCommentString: String = ""
    private var multilineCommentStartLine: Int = 0
    
    init(sourceCode: String) {
        self.lines = sourceCode.components(separatedBy: .newlines)
    }
    
    func analyze() -> [Token] {
        for (lineIndex, line) in lines.enumerated() {
            tokenizeLine(line, lineNumber: lineIndex + 1)
        }
        // If file ends while still in a multi-line comment, emit what we have
        if inMultilineComment {
            tokens.append(Token(type: .comment, lexeme: multilineCommentString, line: multilineCommentStartLine))
            inMultilineComment = false
            multilineCommentString = ""
        }
        return tokens
    }
    
    // break lines of code
    private func tokenizeLine(_ text: String, lineNumber: Int) {
        var temp = text
        if inMultilineComment {
            multilineCommentString += "\n" + temp
            if let endRange = temp.range(of: "*/") {

                let upToEnd = String(temp[..<endRange.upperBound])
                multilineCommentString = multilineCommentString.dropLast(temp.count) + upToEnd
                tokens.append(Token(type: .comment, lexeme: multilineCommentString, line: multilineCommentStartLine))
                inMultilineComment = false
                multilineCommentString = ""

                let rest = temp[endRange.upperBound...].trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty {
                    tokenizeLine(String(rest), lineNumber: lineNumber)
                }
            }
            return
        }
        temp = temp.trimmingCharacters(in: .whitespaces)
        
        while !temp.isEmpty {
            if let startRange = temp.range(of: "/*") {
                let before = String(temp[..<startRange.lowerBound])
                if !before.trimmingCharacters(in: .whitespaces).isEmpty {
                    if let (token, len) = extractNextToken(before, lineNumber: lineNumber) {
                        tokens.append(token)
                        temp.removeFirst(len)
                        temp = temp.trimmingCharacters(in: .whitespaces)
                        continue
                    }
                }
                let after = String(temp[startRange.lowerBound...])
                if let endRange = after.range(of: "*/") {
                    let comment = String(after[..<endRange.upperBound])
                    tokens.append(Token(type: .comment, lexeme: comment, line: lineNumber))
                    temp = String(after[endRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    continue
                } else {
                    inMultilineComment = true
                    multilineCommentStartLine = lineNumber
                    multilineCommentString = after
                    return
                }
            }
            if let (token, len) = extractNextToken(temp, lineNumber: lineNumber) {
                tokens.append(token)
                temp.removeFirst(len)
                temp = temp.trimmingCharacters(in: .whitespaces)
            } else {
                break
            }
        }
    }
    
    private func extractNextToken(_ str: String, lineNumber: Int) -> (Token, Int)? {
        if let (token, len) = matchComment(str, lineNumber: lineNumber) { return (token, len) }
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
    
    private func matchComment(_ str: String, lineNumber: Int) -> (Token, Int)? {
        if str.hasPrefix("//") {
            let comment = str
            return (Token(type: .comment, lexeme: comment, line: lineNumber), comment.count)
        }
        if str.hasPrefix("/*") {
            if let endRange = str.range(of: "*/") {
                let comment = String(str[str.startIndex..<endRange.upperBound])
                return (Token(type: .comment, lexeme: comment, line: lineNumber), comment.count)
            } else {
                let comment = str
                return (Token(type: .comment, lexeme: comment, line: lineNumber), comment.count)
            }
        }
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
