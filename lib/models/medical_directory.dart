// 友善医疗名录 — 数据模型
// 对应 mtf.wiki / ftm.wiki 等友善医疗机构信息。

/// 科室分类
class DepartmentType {
  const DepartmentType._(this.id, this.label);

  final String id;
  final String label;

  static const endocrinology = DepartmentType._('endocrinology', '内分泌科');
  static const psychiatry = DepartmentType._('psychiatry', '精神科/心理科');
  static const surgery = DepartmentType._('surgery', '整形外科');
  static const voice = DepartmentType._('voice', '嗓音训练/外科');
  static const laser = DepartmentType._('laser', '激光/脱毛');
  static const general = DepartmentType._('general', '综合/全科');
  static const gynecology = DepartmentType._('gynecology', '妇科/乳腺科');
  static const dermatology = DepartmentType._('dermatology', '皮肤科');

  static const List<DepartmentType> values = [
    endocrinology,
    psychiatry,
    surgery,
    voice,
    laser,
    general,
    gynecology,
    dermatology,
  ];

  static DepartmentType? fromId(String id) {
    try {
      return values.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DepartmentType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => label;
}

/// 医生信息
class MedicalDoctor {
  final String name;
  final String? title;
  final String? notes;

  const MedicalDoctor({required this.name, this.title, this.notes});

  factory MedicalDoctor.fromJson(Map<String, dynamic> json) {
    return MedicalDoctor(
      name: json['name'] as String,
      title: json['title'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (title != null) 'title': title,
        if (notes != null) 'notes': notes,
      };
}

/// 友善医疗机构
class FriendlyInstitution {
  final String id;
  final String name;
  final String province;
  final String city;
  final String? address;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final List<String> departmentIds;
  final List<String> tags;
  final List<MedicalDoctor> doctors;
  final String? notes;
  final String? sourceUrl;

  /// 收藏状态（本地状态，不序列化到 JSON）
  bool isFavorite;

  FriendlyInstitution({
    required this.id,
    required this.name,
    required this.province,
    required this.city,
    this.address,
    this.phone,
    this.latitude,
    this.longitude,
    required this.departmentIds,
    this.tags = const [],
    this.doctors = const [],
    this.notes,
    this.sourceUrl,
    this.isFavorite = false,
  });

  /// 获取科室标签列表
  List<DepartmentType> get departments => departmentIds
      .map((id) => DepartmentType.fromId(id))
      .whereType<DepartmentType>()
      .toList();

  /// 科室显示文字
  String get departmentLabels => departments.map((d) => d.label).join('、');

  /// 标签显示文字
  String get tagLabels => tags.join('、');

  factory FriendlyInstitution.fromJson(Map<String, dynamic> json) {
    return FriendlyInstitution(
      id: json['id'] as String,
      name: json['name'] as String,
      province: json['province'] as String,
      city: json['city'] as String,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      departmentIds: (json['departments'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              [],
      doctors: (json['doctors'] as List<dynamic>?)
              ?.map((e) => MedicalDoctor.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'province': province,
        'city': city,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'departments': departmentIds,
        'tags': tags,
        'doctors': doctors.map((d) => d.toJson()).toList(),
        if (notes != null) 'notes': notes,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
      };
}
