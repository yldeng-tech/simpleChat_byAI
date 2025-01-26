import Foundation
import Network

public class ChatServer: ObservableObject {
    @Published var connectedClients: [ChatClient] = []
    @Published var messageCount: Int = 0
    private var messageQueue: [ChatMessage] = []
    private let listener: NWListener
    private let port: UInt16 = 8000
    
    init() {
        let parameters = NWParameters.tcp
        guard let listener = try? NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!) else {
            fatalError("Failed to create listener")
        }
        self.listener = listener
        setupListener()
    }
    
    private func setupListener() {
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Server is ready on port \(self?.port ?? 0)")
            case .failed(let error):
                print("Server failed with error: \(error)")
            default:
                break
            }
        }
        
        listener.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }
        
        listener.start(queue: .main)
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        let client = ChatClient(connection: connection)
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.connectedClients.append(client)
                self?.sendMessageHistory(to: client)
            case .failed, .cancelled:
                self?.removeClient(client)
                connection.cancel()
            case .preparing:
                break
            case .waiting(let error):
                print("Connection waiting with error: \(error)")
            default:
                break
            }
        }
        
        self.receiveMessages(from: client)
        connection.start(queue: .main)
    }
    
    private func removeClient(_ client: ChatClient) {
        if let index = connectedClients.firstIndex(where: { $0.id == client.id }) {
            connectedClients.remove(at: index)
        }
    }
    
    private func sendMessageHistory(to client: ChatClient) {
        let recentMessages = messageQueue.suffix(30)
        for message in recentMessages {
            send(message: message, to: client)
        }
    }
    
    private func receiveMessages(from client: ChatClient) {
        client.connection.receiveMessage { [weak self] content, _, isComplete, error in
            // 如果连接已经关闭或出错，不继续处理
            if error != nil || client.connection.state == .cancelled || client.connection.state == .failed(NWError.posix(.ECONNABORTED)) {
                return
            }
            
            if let data = content, let message = String(data: data, encoding: .utf8) {
                // 检查消息是否完整（以\r\n结尾）
                if !message.hasSuffix("\r\n") {
                    // 如果消息不完整，继续接收
                    self?.receiveMessages(from: client)
                    return
                }
                
                // 去除消息末尾的\r\n
                let cleanMessage = message.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                
                // 发送确认消息
                self?.send(message: "X", to: client)
                
                if cleanMessage == "X" {
                    // 这是一个确认消息，不需要进一步处理
                    self?.receiveMessages(from: client)
                    return
                }
                
                if cleanMessage == "我吃串串" {
                    self?.send(message: "你吃签签\r\n", to: client)
                } else {
                    let chatMessage = ChatMessage(sender: client.name, content: cleanMessage, timestamp: Date())
                    self?.messageQueue.append(chatMessage)
                    DispatchQueue.main.async {
                        self?.messageCount += 1
                    }
                    self?.broadcast(message: chatMessage, except: client)
                }
            }
            
            if error == nil {
                // 继续监听新消息
                self?.receiveMessages(from: client)
            } else {
                print("接收消息出错: \(error?.localizedDescription ?? "未知错误")")
            }
        }
    }
    
    private func send(message: ChatMessage, to client: ChatClient) {
        let messageString = "\(message.sender): \(message.content)\r\n"
        send(message: messageString, to: client)
    }
    
    private func send(message: String, to client: ChatClient) {
        guard let data = message.data(using: .utf8) else { return }
        client.connection.send(content: data, completion: .idempotent)
    }
    
    private func broadcast(message: ChatMessage, except excludedClient: ChatClient? = nil) {
        for client in connectedClients where client.id != excludedClient?.id {
            send(message: message, to: client)
        }
    }
    
    func stop() {
        listener.cancel()
        for client in connectedClients {
            client.connection.cancel()
        }
        connectedClients.removeAll()
    }
}