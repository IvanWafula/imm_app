class AppSettings {
  final String? aboutUs;
  final String? contactEmail;
  final String? contactPhone;
  final String? appIconUrl;
  final String? playStoreUrl;


  AppSettings({
    this.aboutUs,
    this.contactEmail,
    this.contactPhone,
    this.appIconUrl,
    this.playStoreUrl,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      aboutUs: json['about_us'],
      contactEmail: json['contact_email'],
      contactPhone: json['contact_phone'],
      appIconUrl: json['app_icon_url'],
      playStoreUrl: json['playstore_url'],

    );
  }
}
