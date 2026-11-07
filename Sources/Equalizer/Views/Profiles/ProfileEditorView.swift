import SwiftUI

/// Editor paramétrico inline para criar ou modificar um perfil de fone.
struct ProfileEditorView: View {
    @State var profile: HeadphoneProfile
    var onSave: (HeadphoneProfile) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(profile.id == UUID() ? "New Profile" : "Edit Profile")
                .font(.headline)
            
            Group {
                TextField("Name", text: $profile.name)
                HStack {
                    TextField("Brand", text: $profile.brand)
                    TextField("Model", text: $profile.model)
                }
                TextField("Target Curve", text: $profile.targetCurve)
                HStack {
                    Text("Preamp")
                    Slider(value: $profile.preampGain, in: -15...15, step: 0.1)
                    Text("\(String(format: "%.1f", profile.preampGain)) dB")
                        .frame(width: 60, alignment: .trailing)
                }
            }
            .textFieldStyle(.roundedBorder)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Type").frame(width: 70, alignment: .leading)
                        Text("Freq").frame(width: 60, alignment: .leading)
                        Text("Gain").frame(width: 60, alignment: .leading)
                        Text("Q").frame(width: 50, alignment: .leading)
                    }
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    
                    ForEach($profile.bands) { $band in
                        BandEditorRow(band: $band)
                    }
                }
            }
            
            HStack {
                Button("+ Band") {
                    let newBand = ProfileBand(filterType: .peak, frequency: 1000, gain: 0)
                    profile.bands.append(newBand)
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Button("Save") {
                    onSave(profile)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 420, height: 480)
        .background(Color.eqBackground)
    }
}

/// Row editável para uma banda paramétrica.
struct BandEditorRow: View {
    @Binding var band: ProfileBand
    
    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: $band.filterType) {
                ForEach(EQFilterType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .frame(width: 90)
            .labelsHidden()
            
            TextField("Freq", value: $band.frequency, format: .number)
                .frame(width: 60)
                .textFieldStyle(.roundedBorder)
            
            TextField("Gain", value: $band.gain, format: .number)
                .frame(width: 60)
                .textFieldStyle(.roundedBorder)
            
            TextField("Q", value: $band.qFactor, format: .number)
                .frame(width: 50)
                .textFieldStyle(.roundedBorder)
            
            Toggle("", isOn: $band.isEnabled)
                .labelsHidden()
        }
    }
}
