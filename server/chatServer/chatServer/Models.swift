import Foundation
import Network

struct ChatMessage: Identifiable {
    let id = UUID()
    let sender: String
    let content: String
    let timestamp: Date
}

class ChatClient: Identifiable {
    let id = UUID()
    let connection: NWConnection
    var name: String
    
    init(connection: NWConnection, name: String = UUID().uuidString) {
        self.connection = connection
        self.name = name
    }
}