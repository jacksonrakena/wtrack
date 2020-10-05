//
//  ContentView.swift
//  WTrack
//
//  Created by Jackson Rakena on 4/Oct/20.
//

import SwiftUI
import CoreData
import MapKit

struct Utils {
    static var datef: DateFormatter { get {
        let l = DateFormatter()
        l.dateFormat = "h:mm aa"
        return l
    }}
    
    static var date: DateFormatter { get {
        let l = DateFormatter()
        l.dateFormat = "EEEE, MMM d, yyyy"
        return l
    }}
}

final class MapCheckInPoint: NSObject, MKAnnotation {
    let checkInEvent: CheckInEvent
    let title: String?
    let coordinate: CLLocationCoordinate2D
    
    init (checkInEvent: CheckInEvent) {
        self.checkInEvent = checkInEvent
        self.title = checkInEvent.friendlyName + ", at " + Utils.datef.string(from: checkInEvent.date)
        self.coordinate = CLLocationCoordinate2D(latitude: checkInEvent.lat!, longitude: checkInEvent.long!)
    }
}

struct CheckInMapView: UIViewRepresentable {
    private let checkpoints: [MapCheckInPoint]
    
    init (checkpoints: [MapCheckInPoint]) {
        self.checkpoints = checkpoints
    }
    
    init (checkpoint: MapCheckInPoint) {
        self.checkpoints = [checkpoint]
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        
        if checkpoints.count > 0 {
            let averageLat: Double = checkpoints.map { (p) -> Double in
                return p.coordinate.latitude
            }.reduce(0.0) { (d0, d1) -> Double in
                return d0+d1
            }/Double(checkpoints.count)
            
            let averageLong: Double = checkpoints.map { (p)  -> Double in
                return p.coordinate.longitude
            }.reduce(0.0) { (d0, d1) -> Double in
                return d0+d1
            }/Double(checkpoints.count)
            
            map.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: averageLat, longitude: averageLong), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        }
        else {
            map.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        }
        return map
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.addAnnotations(checkpoints)
    }
}

struct CheckInEvent {
    var id = UUID()
    var friendlyName: String
    var date = Date()
    var notes: String?
    var lat: Double?
    var long: Double?
}

struct CheckInEventView: View {
    var checkInEvent: CheckInEvent
    
    var body: some View {
        VStack {
            Text(checkInEvent.friendlyName).bold()
            Text("Checked in at " + Utils.datef.string(from: checkInEvent.date))
            if (checkInEvent.lat != nil) {
                CheckInMapView(checkpoint: MapCheckInPoint(checkInEvent: checkInEvent))
            }
        }
    }
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var api = WTrackNFCScanner()
    @State var showingManualCheckInAlert = false
    
    var body: some View {
        TabView {
            HomeView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(api)
                .tabItem {
                    Image(systemName: "wave.3.right.circle")
                    Text("Check-in")
                }
            
            CheckInHistoryView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(api)
                .tabItem {
                    Image(systemName: "clock")
                    Text("History")
                }
            
            ViewAllCheckInsMapView(scanner: api)
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(api)
                .tabItem {
                    Image(systemName: "map")
                    Text("Map")
                }
        }
    }
}

struct CheckInHistoryView: View {
    @EnvironmentObject var api: WTrackNFCScanner
    
    var body: some View {
        NavigationView {
            Text(Dictionary(grouping: api.checkInEvents, by: { Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: $0.date))! }).sorted(by: {$0.key > $1.key}).count)
            ForEach(Dictionary(grouping: api.checkInEvents, by: { Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: $0.date))! }).sorted(by: {$0.key > $1.key}), id: \.key) { (key, value) in
                Text(Utils.date.string(from: key)).bold()
                    List {
                        ForEach(value.sorted(by: { (d0, d1) -> Bool in
                            d0.date.compare(d1.date) == .orderedDescending
                        }), id: \.id) { element in
                            NavigationLink(destination: CheckInEventView(checkInEvent: element)) {
                                HStack {
                                    Text(element.friendlyName)
                                    Spacer()
                                    Text(Utils.datef.string(from: element.date)).foregroundColor(Color.gray)
                                }
                            }
                        }
                    }
            }.navigationTitle("History")
        }
    }
}

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var api: WTrackNFCScanner
    @State var showingManualCheckInAlert = false
    
    var body: some View {
        NavigationView {
            VStack {
                Button(action: {
                    api.startScan()
                }) {
                    HStack {
                        Image(systemName: "wave.3.right.circle").font(.title)
                        Text("Check-in").fontWeight(.semibold).font(.title)
                    }.padding().foregroundColor(.white).background(Color.yellow).cornerRadius(40)
                }
                
                Button(action: {
                    self.showingManualCheckInAlert = true
                }) {
                    HStack {
                        Image(systemName: "wave.3.right.circle")
                            .font(.title)
                        Text("Manual check-in")
                            .fontWeight(.semibold)
                            .font(.title)
                    }
                    .padding()
                    .foregroundColor(.yellow)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 40).stroke(Color.yellow, lineWidth: 5))
                }
            }.alert(isPresented: $showingManualCheckInAlert, TextAlert(title: "Where are you right now?", action: {
                guard let text = $0 else {
                    return
                }
                if (text.isEmpty) {
                    return
                }
                self.api.addManualCheckIn(name: text)
            })).navigationTitle("Check-in")
        }
    }
}

struct ViewAllCheckInsMapView: View {
    @ObservedObject var scanner: WTrackNFCScanner
    var body: some View {
        NavigationView {
            VStack {
                CheckInMapView(checkpoints: scanner.checkInEvents.filter({ (r) -> Bool in
                    return r.lat != nil && r.long != nil
                }).map({ (e) -> MapCheckInPoint in
                    return MapCheckInPoint(checkInEvent: e)
                }))
            }.navigationTitle("Map")
        }
    }
}

import Foundation
import Combine
import SwiftUI
import CoreNFC
import PromiseKit

final class WTrackNFCScanner: NSObject, ObservableObject, NFCTagReaderSessionDelegate {
    @Published var checkInEvents: [CheckInEvent] = []
    
    let POINT_CORRUPT_ERROR = "This WTrack point is corrupt. Please contact WTrack."
    let UNCONFIGURED_ERROR = "This WTrack point has not been configured. Please contact WTrack."
    
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
    
    func addManualCheckIn(name: String) {
        DispatchQueue.main.async {
            let d = LocationManager.shared.lastLocation
        }
        
        DispatchQueue.main.async {
            var checkInEvent = CheckInEvent(friendlyName: name)
            if (LocationManager.shared.lastLocation != nil) {
                checkInEvent.lat = LocationManager.shared.lastLocation!.coordinate.latitude
                checkInEvent.long = LocationManager.shared.lastLocation!.coordinate.longitude
            }
            self.checkInEvents.append(checkInEvent)
        }
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        if tags.count > 1 {
            session.invalidate(errorMessage: "More than 1 point was found. Please present only 1 point.")
            return
        }
        
        guard let firstTag = tags.first else {
            session.invalidate(errorMessage: "Unexpected error. Please try again.")
            return
        }
        
        print("Got a tag!", firstTag)
        
        session.connect(to: firstTag) { (error: Error?) in
            if error != nil {
                session.invalidate(errorMessage: "Connection error. Please try again.")
                return
            }
            
            DispatchQueue.main.async {
                let d = LocationManager.shared.lastLocation
            }
            
            switch firstTag {
            case .miFare(let discoveredTag):
                discoveredTag.readNDEF { (msg, err) in
                    DispatchQueue.main.async { [self] in
                        guard let msg = msg else {
                            session.invalidate(errorMessage: UNCONFIGURED_ERROR)
                            return
                        }
                        
                        if (msg.records.count == 0) {
                            session.invalidate(errorMessage: UNCONFIGURED_ERROR)
                            return
                        }
                        
                        let record = msg.records[0]
                        
                        guard let text = record.wellKnownTypeTextPayload().0 else {
                            session.invalidate(errorMessage: POINT_CORRUPT_ERROR)
                            return
                        }
                        
                        let arr = text.split(separator: "|")
                        
                        if (arr.count == 0) {
                            session.invalidate(errorMessage: POINT_CORRUPT_ERROR)
                            return
                        }
                        
                        var checkInEvent = CheckInEvent(friendlyName: arr[0].trimmingCharacters(in: .whitespacesAndNewlines))
                        
                        if (LocationManager.shared.lastLocation != nil) {
                            checkInEvent.lat = LocationManager.shared.lastLocation!.coordinate.latitude
                            checkInEvent.long = LocationManager.shared.lastLocation!.coordinate.longitude
                        }
                        
                        self.checkInEvents.append(checkInEvent)
                        session.alertMessage = "Checked in to " + checkInEvent.friendlyName + " at " + Utils.datef.string(from: checkInEvent.date) + "."
                        session.invalidate()
                    }
                }
            default:
                session.invalidate(errorMessage: "WTrack doesn't support this kind of point.")
            }
        }
    }
}
