//
//  ContentView.swift
//  chatServer
//
//  Created by yonglong deng on 2025/1/26.
//

import SwiftUI
import Network

struct ContentView: View {
    @StateObject private var server = ChatServer()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("聊天服务器状态")
                .font(.title)
            
            HStack(spacing: 40) {
                VStack {
                    Text("\(server.connectedClients.count)")
                        .font(.system(size: 40, weight: .bold))
                    Text("在线客户端")
                }
                
                VStack {
                    Text("\(server.messageCount)")
                        .font(.system(size: 40, weight: .bold))
                    Text("消息数量")
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1)))
        }
        .padding()
    }
}
