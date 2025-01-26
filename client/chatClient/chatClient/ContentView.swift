import SwiftUI
import Network

struct ContentView: View {
    @State private var messages: [ChatMessage] = []
    @State private var isConnected = false
    @State private var messageText = ""
    @State private var connection: NWConnection?
    @State private var isSending = false
    @State private var connectionState = "未连接"
    @State private var lastError: String? = nil
    @State private var lastSendError: String? = nil
    private let clientId = UUID().uuidString
    
    struct ChatMessage: Identifiable {
        let id: UUID
        let content: String
        let timestamp: Date
        let isFromCurrentUser: Bool
        var status: MessageStatus = .none
        
        var formattedTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter.string(from: timestamp)
        }
    }
    
    enum MessageStatus {
        case none
        case sending
        case sent
        case failed
    }
    
    var body: some View {
        VStack {
            // 连接状态指示器
            VStack(spacing: 4) {
                HStack {
                    Circle()
                        .fill(isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(connectionState)
                        .font(.caption)
                        .foregroundColor(isConnected ? .green : .red)
                }
                
                if let error = lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                if let sendError = lastSendError {
                    Text("发送失败: \(sendError)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.top)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { message in
                        MessageView(message: message)
                    }
                }
                .padding()
            }
            
            HStack {
                TextField("输入消息", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isSending)
                
                Button(action: sendMessage) {
                    if isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .disabled(messageText.isEmpty || isSending || !isConnected)
            }
            .padding()
        }
        .navigationTitle("聊天客户端")
        .onAppear {
            setupConnection()
        }
    }
    
    private func setupConnection() {
        let endpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: 8000)!)
        let parameters = NWParameters.tcp
        connection = NWConnection(to: endpoint, using: parameters)
        connection?.stateUpdateHandler = { state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    print("Connected to server")
                    isConnected = true
                    connectionState = "已连接"
                    lastError = nil
                    setupReceive()
                case .failed(let error):
                    print("Connection failed: \(error)")
                    isConnected = false
                    connectionState = "连接失败"
                    lastError = error.localizedDescription
                    reconnect()
                case .cancelled:
                    print("Connection cancelled")
                    isConnected = false
                    connectionState = "连接已取消"
                    lastError = nil
                    reconnect()
                case .preparing:
                    connectionState = "准备连接中"
                    lastError = nil
                case .waiting(let error):
                    connectionState = "等待连接"
                    lastError = error.localizedDescription
                default:
                    connectionState = "未知状态"
                    break
                }
            }
        }
        
        connection?.start(queue: .main)
    }
    
    private func setupReceive() {
        connection?.receiveMessage { content, _, isComplete, error in
            if let data = content,
               let text = String(data: data, encoding: .utf8) {
                // 如果收到的不是确认消息'X'，则发送确认并添加到消息列表
                if text != "X" {
                    let message = ChatMessage(
                        id: UUID(),
                        content: text,
                        timestamp: Date(),
                        isFromCurrentUser: false
                    )
                    DispatchQueue.main.async {
                        messages.append(message)
                    }
                    // 发送确认消息
                    let confirmData = "X\r\n".data(using: .utf8)!
                    connection?.send(content: confirmData, completion: .contentProcessed { _ in })
                }
            }
            
            if error == nil {
                setupReceive()
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty,
              let connection = connection else { return }
        
        // 确保消息以\r\n结尾
        var messageWithDelimiter = messageText
        if !messageWithDelimiter.hasSuffix("\r\n") {
            messageWithDelimiter += "\r\n"
        }
        
        guard let data = messageWithDelimiter.data(using: .utf8) else { return }
        
        isSending = true
        lastSendError = nil
        
        let message = ChatMessage(
            id: UUID(),
            content: messageText,
            timestamp: Date(),
            isFromCurrentUser: true,
            status: .sending
        )
        messages.append(message)
        
        connection.send(content: data, completion: .contentProcessed { error in
            DispatchQueue.main.async {
                isSending = false
                if let error = error {
                    print("Failed to send message: \(error)")
                    lastSendError = error.localizedDescription
                    if let index = messages.firstIndex(where: { $0.id == message.id }) {
                        messages[index].status = .failed
                    }
                } else {
                    if let index = messages.firstIndex(where: { $0.id == message.id }) {
                        messages[index].status = .sent
                    }
                }
            }
        })
        
        messageText = ""
    }
    
    private func reconnect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            setupConnection()
        }
    }
}

struct MessageView: View {
    let message: ContentView.ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading) {
                HStack {
                    Text(message.content)
                    if message.isFromCurrentUser {
                        Group {
                            switch message.status {
                            case .sending:
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 16, height: 16)
                            case .sent:
                                Image(systemName: "checkmark")
                                    .foregroundColor(.white)
                                    .font(.system(size: 12))
                            case .failed:
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                                    .font(.system(size: 12))
                            case .none:
                                EmptyView()
                            }
                        }
                        .padding(.leading, 4)
                    }
                }
                .padding(10)
                .background(message.isFromCurrentUser ? 
                    (message.status == .failed ? Color.red.opacity(0.8) : Color.blue) : 
                    Color.gray.opacity(0.2))
                .foregroundColor(message.isFromCurrentUser ? .white : .primary)
                .cornerRadius(10)
                
                Text(message.formattedTime)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if !message.isFromCurrentUser {
                Spacer()
            }
        }
    }
}

#Preview {
    ContentView()
}
