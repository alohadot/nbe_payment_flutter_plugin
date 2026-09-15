import Gateway

// `GatewayRegion` alone refers to the Pigeon enum of this plugin; the SDK type is qualified
// with its module name.
func toSdkRegion(_ region: GatewayRegion) -> Gateway.GatewayRegion {
  switch region {
  case .mtf: return .mtf
  case .europe: return .europe
  case .northAmerica: return .northAmerica
  case .asiaPacific: return .asiaPacific
  case .india: return .india
  case .china: return .china
  case .saudiArabia: return .saudiArabia
  }
}
