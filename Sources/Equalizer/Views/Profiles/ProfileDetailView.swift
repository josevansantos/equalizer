import SwiftUI

/// Painel de detalhes de um perfil de fone, exibindo metadados e tabela de bandas.
struct ProfileDetailView: View {
    let profile: HeadphoneProfile
    var onActivate: () -> Void
    var onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.headline)
                Text("\(profile.brand) · \(profile.model)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Curve: \(profile.targetCurve) · Preamp: \(String(format: "%.1f", profile.preampGain)) dB")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Type").frame(width: 70, alignment: .leading)
                        Text("Freq").frame(width: 60, alignment: .leading)
                        Text("Gain").frame(width: 60, alignment: .leading)
                        Text("Q").frame(width: 50, alignment: .leading)
                    }
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    
                    ForEach(profile.bands) { band in
                        HStack {
                            Text(band.filterType.rawValue)
                                .frame(width: 70, alignment: .leading)
                                .font(.caption)
                            Text("\(Int(band.frequency)) Hz")
                                .frame(width: 60, alignment: .leading)
                                .font(.caption)
                            Text("\(String(format: "%+.1f", band.gain)) dB")
                                .frame(width: 60, alignment: .leading)
                                .font(.caption)
                            Text("\(String(format: "%.2f", band.qFactor))")
                                .frame(width: 50, alignment: .leading)
                                .font(.caption)
                        }
                        .foregroundColor(band.isEnabled ? .primary : .secondary)
                    }
                }
            }
            
            HStack {
                Button("Activate") {
                    onActivate()
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button("Edit") {
                    onEdit()
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .frame(width: 360, height: 420)
        .background(Color.eqBackground)
    }
}
