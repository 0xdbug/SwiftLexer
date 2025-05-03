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
let brackets = ["(", ")", "{", "}", ";", ","]

enum TokenType: String {
    case keyword
    case identifier
    case `operator`
    case literal
    case delimiter
    case comment
    case error
}

// this is the model im using to represent each token
struct Token {
    let type: TokenType
    let value: String
    let line: Int
    
    func description() -> String {
        return "[\(type.rawValue)] \"\(value)\""
    }
}

class LexicalAnalyzer {
    private var lines: [String]
    // goal is to recognize and append each token
    private var tokens: [Token] = []
    
    // if it starts with /*
    private var isMultilineComment = false
    
    init(sourceCode: String) {
        self.lines = sourceCode.components(separatedBy: .newlines)
    }
    
    func analyze() -> [Token] {
        for (lineIndex, line) in lines.enumerated() {
            processLine(line, lineNumber: lineIndex + 1)
        }
        return tokens
    }
    
    private func processLine(_ line: String, lineNumber: Int) {
        var commentRemvedLine = line
        var singleLineComment = ""
        
        if let commentRange = commentRemvedLine.range(of: "//") {
            
            singleLineComment = String(commentRemvedLine[commentRange.lowerBound...])
            commentRemvedLine = String(commentRemvedLine[..<commentRange.lowerBound])
            
            tokens.append(Token(type: .comment, value: singleLineComment, line: lineNumber))
            
            print("single line comment \(singleLineComment)")
            print("commentRemvedLine \(commentRemvedLine)")
        }
        
        if isMultilineComment {
            
            if let endMultilineComment = commentRemvedLine.range(of: "*/") {
                
                // up to and includin */
                let commentPart = String(commentRemvedLine[..<endMultilineComment.upperBound])
                
                tokens.append(Token(type: .comment, value: commentPart, line: lineNumber))
                
                commentRemvedLine = String(commentRemvedLine[endMultilineComment.upperBound...])
                isMultilineComment = false
                
            } else {
                
                tokens.append(Token(type: .comment, value: commentRemvedLine, line: lineNumber))
                return
            }
            
        }
        
        if let startMultilineComment = commentRemvedLine.range(of: "/*") {
            
            let beforeComment = String(commentRemvedLine[..<startMultilineComment.lowerBound])
            
            tokenizeBySpace(beforeComment, lineNumber: lineNumber)
            
            if let endMultilineComment = commentRemvedLine.range(of: "*/", range: startMultilineComment.upperBound..<commentRemvedLine.endIndex) {
                
                let commentText = String(commentRemvedLine[startMultilineComment.lowerBound...endMultilineComment.upperBound])
                
                tokens.append(Token(type: .comment, value: commentText, line: lineNumber))
                
                let afterComment = String(commentRemvedLine[endMultilineComment.upperBound...])
                
                tokenizeBySpace(afterComment, lineNumber: lineNumber)
                
            } else {
                let commentText = String(commentRemvedLine[startMultilineComment.lowerBound...])
                tokens.append(Token(type: .comment, value: commentText, line: lineNumber))
                isMultilineComment = true
            }
        } else {
            tokenizeBySpace(commentRemvedLine, lineNumber: lineNumber)
        }
    }
    
    // break lines of code
    private func tokenizeBySpace(_ text: String, lineNumber: Int) {
        var temp = text.trimmingCharacters(in: .whitespaces)
        while !temp.isEmpty {
            if let (token, len) = extractNextToken(temp, lineNumber: lineNumber) {
                tokens.append(token)
                temp.removeFirst(len)
                temp = temp.trimmingCharacters(in: .whitespaces)
            } else {
                tokens.append(Token(type: .error, value: String(temp.first!), line: lineNumber))
                temp.removeFirst()
                temp = temp.trimmingCharacters(in: .whitespaces)
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
        let singleLinePattern = "^//.*"
        if let match = str.range(of: singleLinePattern, options: .regularExpression) {
            let comment = String(str[match])
            return (Token(type: .comment, value: comment, line: lineNumber), comment.count)
        }
        let multiLinePattern = "^/\\*.*?\\*/"
        if let match = str.range(of: multiLinePattern, options: .regularExpression) {
            let comment = String(str[match])
            return (Token(type: .comment, value: comment, line: lineNumber), comment.count)
        }
        return nil
    }
    
    private func matchLiteral(_ str: String, lineNumber: Int) -> (Token, Int)? {
        let stringPattern = #"^"([^"\\]|\\.)*""#
        if let match = str.range(of: stringPattern, options: .regularExpression) {
            let literal = String(str[match])
            return (Token(type: .literal, value: literal, line: lineNumber), literal.count)
        }
        let numberPattern = "^[0-9]+(\\.[0-9]+)?"
        if let match = str.range(of: numberPattern, options: .regularExpression) {
            let literal = String(str[match])
            return (Token(type: .literal, value: literal, line: lineNumber), literal.count)
        }
        return nil
    }
    
    private func matchOperator(_ str: String, lineNumber: Int) -> (Token, Int)? {
        let sortedOps = operators.sorted { $0.count > $1.count }
        let pattern = "^(" + sortedOps.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|") + ")"
        if let match = str.range(of: pattern, options: .regularExpression) {
            let op = String(str[match])
            return (Token(type: .operator, value: op, line: lineNumber), op.count)
        }
        return nil
    }
    
    private func matchBracket(_ str: String, lineNumber: Int) -> (Token, Int)? {
        let pattern = "^[\\(\\)\\{\\}\\[\\]]"
        if let match = str.range(of: pattern, options: .regularExpression) {
            let bracket = String(str[match])
            return (Token(type: .delimiter, value: bracket, line: lineNumber), bracket.count)
        }
        return nil
    }
    
    private func matchSpecialCharacter(_ str: String, lineNumber: Int) -> (Token, Int)? {
        let pattern = "^[,.;]"
        if let match = str.range(of: pattern, options: .regularExpression) {
            let special = String(str[match])
            return (Token(type: .delimiter, value: special, line: lineNumber), special.count)
        }
        return nil
    }
    
    private func matchKeyword(_ str: String, lineNumber: Int) -> (Token, Int)? {
        let pattern = "^\\b(" + javaKeywords.joined(separator: "|") + ")\\b"
        if let match = str.range(of: pattern, options: .regularExpression) {
            let keyword = String(str[match])
            return (Token(type: .keyword, value: keyword, line: lineNumber), keyword.count)
        }
        return nil
    }
    
    private func matchIdentifier(_ str: String, lineNumber: Int) -> (Token, Int)? {
        let pattern = "^[a-zA-Z_][a-zA-Z0-9_]*"
        if let match = str.range(of: pattern, options: .regularExpression) {
            let identifier = String(str[match])
            return (Token(type: .identifier, value: identifier, line: lineNumber), identifier.count)
        }
        return nil
    }
    
    private func matchInvalidStringLiteral(_ str: String, lineNumber: Int) -> (Token, Int)? {
        if str.first == "\"" {
            let errorStr = String(str)
            return (Token(type: .error, value: errorStr, line: lineNumber), errorStr.count)
        }
        return nil
    }
    
    private func matchInvalidIdentifier(_ str: String, lineNumber: Int) -> (Token, Int)? {
        let pattern = "^#[a-zA-Z0-9_]+"
        if let match = str.range(of: pattern, options: .regularExpression) {
            let errorId = String(str[match])
            return (Token(type: .error, value: errorId, line: lineNumber), errorId.count)
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
