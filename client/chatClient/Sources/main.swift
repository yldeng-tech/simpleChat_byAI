import Foundation
import Network

// 设置工作目录
let workingDirectory = "/Users/yldeng/Documents/code/L7_test/client/chatClient"
FileManager.default.changeCurrentDirectoryPath(workingDirectory)

class TerminalChatClient {
    private var connection: NWConnection?
    private var isConnected = false
    private let clientId = UUID().uuidString
    private let queue = DispatchQueue(label: "com.chat.client")
    private var messageBuffer = Data()
    
    func start() {
        print("正在连接到聊天服务器...")
        connectToServer()
        RunLoop.current.run()
    }
    
    private func connectToServer() {
        let endpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: 8000)
        establishConnection(with: endpoint)
    }
    
    private func establishConnection(with endpoint: NWEndpoint) {
        let parameters = NWParameters.tcp
        connection = NWConnection(to: endpoint, using: parameters)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("已连接到服务器")
                self?.isConnected = true
                self?.startReceiving()
            case .failed(let error):
                print("连接失败: \(error)")
                exit(1)
            case .waiting(let error):
                print("等待连接: \(error)")
            default:
                break
            }
        }
        
        connection?.start(queue: queue)
    }
    
    private func startReceiving() {
        receiveNextMessage()
    }
    
    private func processMessageBuffer() {
        while true {
            guard let range = messageBuffer.range(of: Data("\r\n".utf8)) else { break }
            let messageData = messageBuffer.subdata(in: 0..<range.lowerBound)
            if let message = String(data: messageData, encoding: .utf8) {
                print("收到消息: \(message)")
                // 如果收到的不是确认消息'X'，则立即发送确认
                if message != "X" {
                    let confirmData = "X\r\n".data(using: .utf8)!
                    connection?.send(content: confirmData, completion: .contentProcessed { error in
                        if let error = error {
                            print("发送确认消息失败: \(error)")
                        }
                    })
                }
            }
            messageBuffer.removeSubrange(0..<range.upperBound)
        }
    }
    
    func sendMessage(_ message: String) {
        guard isConnected, let connection = connection else {
            print("未连接到服务器")
            return
        }
        
        var messageWithDelimiter = message
        if !message.hasSuffix("\r\n") {
            messageWithDelimiter += "\r\n"
        }
        
        let messageData = messageWithDelimiter.data(using: .utf8)!
        connection.send(content: messageData, completion: .contentProcessed { error in
            if let error = error {
                print("发送消息失败: \(error)")
            } else {
                print("消息已发送: \(message)")
            }
        })
    }
    
    private func receiveNextMessage() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            if let error = error {
                print("接收消息错误: \(error)")
                return
            }
            
            if let data = content {
                self?.messageBuffer.append(data)
                self?.processMessageBuffer()
            }
            
            if isComplete {
                self?.receiveNextMessage()
            }
        }
    }
    
    func sendMessage(_ message: String) {
        guard isConnected, let connection = connection else {
            print("未连接到服务器")
            return
        }
        
        var messageWithDelimiter = message
        if !message.hasSuffix("\r\n") {
            messageWithDelimiter += "\r\n"
        }
        
        let messageData = messageWithDelimiter.data(using: .utf8)
        connection.send(content: messageData, completion: .contentProcessed { error in
            if let error = error {
                print("发送消息失败: \(error)")
            } else {
                print("消息已发送: \(message)")
            }
        })
    }
}

// 启动客户端
let client = TerminalChatClient()
client.start()