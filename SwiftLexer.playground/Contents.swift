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
    
    private func tokenizeBySpace(_ text: String, lineNumber: Int) {
        var temp = text
        while !temp.isEmpty {
            temp = temp.trimmingCharacters(in: .whitespaces)
            
            if temp.isEmpty { break }
            
            // literal
            if temp.first == "\"" {
                if let closingIndex = temp.dropFirst().firstIndex(of: "\"") {
                    let endIndex = temp.index(after: closingIndex)
                    let literal = String(temp[..<endIndex])
                    tokens.append(Token(type: .literal, value: literal, line: lineNumber))
                    temp = String(temp[endIndex...])
                    continue
                } else {
                    tokens.append(Token(type: .error, value: temp, line: lineNumber))
                    break
                }
            }
            
            // operators
            if let op = operators.sorted(by: { $0.count > $1.count }).first(where: { temp.hasPrefix($0) }) {
                tokens.append(Token(type: .operator, value: op, line: lineNumber))
                temp.removeFirst(op.count)
                continue
            }
            
            // delimiters
            if let br = brackets.first(where: { temp.hasPrefix($0) }) {
                tokens.append(Token(type: .delimiter, value: br, line: lineNumber))
                temp.removeFirst(br.count)
                continue
            }
            
            if let match = temp.firstIndex(where: { $0.isWhitespace || brackets.contains(String($0)) || operators.contains(String($0)) }) {
                let part = String(temp[..<match])
                classifyToken(part, lineNumber: lineNumber)
                temp = String(temp[match...])
            } else {
                classifyToken(temp, lineNumber: lineNumber)
                break
            }
        }
    }
    
    private func classifyToken(_ part: String, lineNumber: Int) {
        let trimmed = part.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        if javaKeywords.contains(trimmed) {
            tokens.append(Token(type: .keyword, value: trimmed, line: lineNumber))
            
        } else if isString(trimmed) {
            tokens.append(Token(type: .literal, value: trimmed, line: lineNumber))
        } else if isNumber(trimmed) {
            tokens.append(Token(type: .literal, value: trimmed, line: lineNumber))
        } else if isValidIdentifier(trimmed) {
            tokens.append(Token(type: .identifier, value: trimmed, line: lineNumber))
        } else {
            tokens.append(Token(type: .error, value: trimmed, line: lineNumber))
        }
    }
    
    private func isValidIdentifier(_ str: String) -> Bool {
        guard let first = str.first, first.isLetter || first == "_" else {
            return false
        }
        return str.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
    
    private func isNumber(_ str: String) -> Bool {
        return Double(str) != nil
    }
    
    private func isString(_ str: String) -> Bool {
        return str.first == "\"" && str.last == "\"" && str.count >= 2
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
