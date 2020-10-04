//
//  ContentView.swift
//  WTrack
//
//  Created by Jackson Rakena on 4/Oct/20.
//

import SwiftUI
import CoreData

struct CheckInEvent {
    var id = UUID()
    var friendlyName: String
    var name: String
    var date: Date
    var notes: String?
}

struct CheckInEventView: View {
    var checkInEvent: CheckInEvent
    
    var body: some View {
        Text(checkInEvent.friendlyName)
    }
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var userData = UserData()
    
    let datef = DateFormatter()
    init() {
        datef.dateFormat = "h:mm a"
    }
    var body: some View {
        NavigationView {
            VStack {
                Button(action: {
                    userData.startScan()
                }) {
                    HStack {
                        Image(systemName: "wave.3.right.circle")
                            .font(.title)
                        Text("Check-in")
                            .fontWeight(.semibold)
                            .font(.title)
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.yellow)
                    .cornerRadius(40)
                }
                Text("Check-in history:").bold()
                List {
                    ForEach(userData.checkInEvents.sorted(by: { (d0, d1) -> Bool in
                        d0.date.compare(d1.date) == .orderedDescending
                    }), id: \.id) { element in
                        NavigationLink(destination: CheckInEventView(checkInEvent: element)) {
                            HStack {
                                Text(element.friendlyName)
                                Spacer()
                                Text(datef.string(from: element.date)).foregroundColor(Color.gray)
                            }
                        }
                    }
                }
            }.navigationTitle("WTrack")
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}


import Foundation
import Combine
import SwiftUI
import CoreNFC
import PromiseKit

final class UserData: NSObject, ObservableObject, NFCTagReaderSessionDelegate {
    @Published var roomName: String?
    @Published var checkInEvents: [CheckInEvent] = []
    
    func startScan() {
        let readerSession = NFCTagReaderSession(pollingOption: .iso14443, delegate: self)
        readerSession?.alertMessage = "Hold your iPhone near a WTrack point."
        readerSession?.begin()
    }
    
    // MARK: - NFCTagReaderSessionDelegate
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        // If necessary, you may perform additional operations on session start.
        // At this point RF polling is enabled.
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        // If necessary, you may handle the error. Note session is no longer valid.
        // You must create a new session to restart RF polling.
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        if tags.count > 1 {
            print("More than 1 point was found. Please present only 1 point.")
            session.invalidate(errorMessage: "More than 1 point was found. Please present only 1 point.")
            return
        }
        
        guard let firstTag = tags.first else {
            print("Unable to get first point.")
            session.invalidate(errorMessage: "Unable to get first point.")
            return
        }
        
        print("Got a tag!", firstTag)
        
        session.connect(to: firstTag) { (error: Error?) in
            if error != nil {
                session.invalidate(errorMessage: "Connection error. Please try again.")
                return
            }
            
            print("Connected to tag!")
            
            var importPromise: Promise<String>?
            
            switch firstTag {
            case .miFare(let discoveredTag):
                print("Got a MIFARE tag.")
                discoveredTag.readNDEF { (msg, err) in
                    DispatchQueue.main.async {
                        let record = msg!.records[0]
                        let text = record.wellKnownTypeTextPayload().0!
                        let arr = text.split(separator: "|")
                        let checkInEvent = CheckInEvent(friendlyName: arr[0].trimmingCharacters(in: .whitespacesAndNewlines), name: arr[1].trimmingCharacters(in: .whitespacesAndNewlines), date: Date(), notes: nil)
                        self.roomName = checkInEvent.friendlyName
                        let datef = DateFormatter()
                        datef.dateFormat = "h:mm a"
                        self.checkInEvents.append(checkInEvent)
                        session.alertMessage = "Checked in to " + self.roomName! + " at " + datef.string(from: Date()) + "."
                        session.invalidate()
                    }
                }
            default:
                session.invalidate(errorMessage: "WTrack doesn't support this kind of point.")
            }
            
            importPromise?.done { tag in
                print("Got tag!", tag)
                self.roomName = tag
                session.invalidate()
            }.catch { err in
                session.invalidate(errorMessage: err.localizedDescription)
            }
        }
    }
}
