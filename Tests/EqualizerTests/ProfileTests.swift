import Testing
@testable import Equalizer

@MainActor
struct ProfileTests {
    
    @Test func builtInProfilesDecodeSuccessfully() {
        let store = ProfileStore()
        let builtIn = store.loadBuiltInProfiles()
        #expect(builtIn.count == 3)
        
        let names = builtIn.map(\.name)
        #expect(names.contains { $0.contains("WH-1000XM4") })
        #expect(names.contains { $0.contains("ZSN Pro X") })
        #expect(names.contains { $0.contains("FreeBuds Pro 5") })
    }
    
    @Test func builtInProfilesHaveExpectedPreamp() {
        let store = ProfileStore()
        let builtIn = store.loadBuiltInProfiles()
        
        let sony = builtIn.first { $0.name.contains("WH-1000XM4") }
        let kz = builtIn.first { $0.name.contains("ZSN Pro X") }
        let huawei = builtIn.first { $0.name.contains("FreeBuds Pro 5") }
        
        #expect(sony?.preampGain == -5.6)
        #expect(kz?.preampGain == -4.2)
        #expect(huawei?.preampGain == -3.5)
        
        #expect(sony?.isBuiltIn == true)
        #expect(kz?.isBuiltIn == true)
        #expect(huawei?.isBuiltIn == true)
    }
    
    @Test func profileBandQToBandwidthAndBack() {
        let q: Float = 1.0
        let bw = ProfileBand.qToBandwidth(q: q)
        let qBack = ProfileBand.bandwidthToQ(bw: bw)
        
        #expect(bw > 0)
        #expect(abs(q - qBack) < 0.001)
    }
    
    @Test func profileBandLowQProducesWideBandwidth() {
        let bw = ProfileBand.qToBandwidth(q: 0.5)
        #expect(bw > 2.0)
    }
    
    @Test func profileBandHighQProducesNarrowBandwidth() {
        let bw = ProfileBand.qToBandwidth(q: 5.0)
        #expect(bw < 0.5)
    }
    
    @Test func importFromJSONStringCreatesValidProfile() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "name": "Test Profile",
          "brand": "Test",
          "model": "Test Model",
          "targetCurve": "Harman 2019",
          "preampGain": -3.0,
          "bands": [
            {
              "filterType": "PEAK",
              "frequency": 1000,
              "gain": 2.0,
              "qFactor": 1.0,
              "bandwidth": 1.39,
              "enabled": true
            }
          ]
        }
        """
        
        let importer = ProfileImporter()
        let profile = try importer.importFromJSON(string: json)
        
        #expect(profile.name == "Test Profile")
        #expect(profile.preampGain == -3.0)
        #expect(profile.bands.count == 1)
        #expect(profile.bands[0].filterType == .peak)
        #expect(profile.bands[0].frequency == 1000.0)
        #expect(profile.bands[0].isEnabled == true)
    }
    
    @Test func importFromAutoEQParsesCorrectly() throws {
        let text = """
        Preamp: -5.6 dB
        Filter 1: ON LSC Fc 105 Hz Gain 5.5 dB Q 0.71
        Filter 2: ON PK Fc 210 Hz Gain -4.5 dB Q 0.71
        Filter 3: ON HSC Fc 12000 Hz Gain -2.0 dB Q 0.71
        """
        
        let importer = ProfileImporter()
        let profile = try importer.importFromAutoEQ(text: text, brand: "Sony", model: "WH-1000XM4")
        
        #expect(profile.preampGain == -5.6)
        #expect(profile.bands.count == 3)
        #expect(profile.bands[0].filterType == .lowShelf)
        #expect(profile.bands[1].filterType == .peak)
        #expect(profile.bands[2].filterType == .highShelf)
        #expect(profile.bands[0].frequency == 105.0)
        #expect(profile.bands[0].gain == 5.5)
        #expect(profile.bands[0].qFactor == 0.71)
    }
    
    @Test func importFromAutoEQRejectsInvalidFormat() {
        let text = "This is not a valid AutoEQ file"
        let importer = ProfileImporter()
        
        #expect(throws: ProfileImportError.self) {
            _ = try importer.importFromAutoEQ(text: text)
        }
    }
}
