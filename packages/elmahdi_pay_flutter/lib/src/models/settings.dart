class PaySettings {
  final double? usdToSdgRate;

  const PaySettings({this.usdToSdgRate});

  factory PaySettings.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return PaySettings(
      usdToSdgRate: data['usd_to_sdg_rate'] != null
          ? (data['usd_to_sdg_rate'] as num).toDouble()
          : null,
    );
  }
}
