import 'package:flutter/material.dart';

import '../../models/medical_directory.dart';
import '../../services/medical_directory_service.dart';

/// 友善医疗名录 — 机构详情页面
class InstitutionDetailScreen extends StatefulWidget {
  final FriendlyInstitution institution;
  final VoidCallback? onFavoriteToggled;

  const InstitutionDetailScreen({
    super.key,
    required this.institution,
    this.onFavoriteToggled,
  });

  @override
  State<InstitutionDetailScreen> createState() =>
      _InstitutionDetailScreenState();
}

class _InstitutionDetailScreenState extends State<InstitutionDetailScreen> {
  final MedicalDirectoryService _service = MedicalDirectoryService();
  late FriendlyInstitution _institution;

  @override
  void initState() {
    super.initState();
    _institution = widget.institution;
  }

  Future<void> _toggleFavorite() async {
    final newState = await _service.toggleFavorite(_institution.id);
    setState(() => _institution.isFavorite = newState);
    widget.onFavoriteToggled?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '机构详情',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _institution.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _institution.isFavorite ? const Color(0xFFF5A9B8) : null,
            ),
            tooltip: _institution.isFavorite ? '取消收藏' : '收藏',
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 基本信息卡片
          _buildInfoCard(),
          const SizedBox(height: 12),
          // 科室与标签
          _buildDepartmentAndTags(),
          const SizedBox(height: 12),
          // 医生列表
          if (_institution.doctors.isNotEmpty) ...[
            _buildDoctorsSection(),
            const SizedBox(height: 12),
          ],
          // 备注
          if (_institution.notes != null && _institution.notes!.isNotEmpty) ...[
            _buildNotesSection(),
            const SizedBox(height: 12),
          ],
          // 来源链接
          if (_institution.sourceUrl != null &&
              _institution.sourceUrl!.isNotEmpty) ...[
            _buildSourceLink(),
            const SizedBox(height: 12),
          ],
          // 地图占位
          _buildMapPlaceholder(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 名称
            Text(
              _institution.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            // 地址
            _buildInfoRow(
              Icons.location_on_outlined,
              '${_institution.province} ${_institution.city}',
              _institution.address,
            ),
            // 电话
            if (_institution.phone != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildInfoRow(
                  Icons.phone_outlined,
                  _institution.phone!,
                  null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String primary, String? secondary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 18,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                primary,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                ),
              ),
              if (secondary != null && secondary.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  secondary,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentAndTags() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText =
        isDark ? const Color(0xFF98989E) : const Color(0xFF86868B);
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 科室
            Text(
              '科室',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _institution.departments.map((d) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5BCEFA).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    d.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF5BCEFA),
                    ),
                  ),
                );
              }).toList(),
            ),
            // 标签
            if (_institution.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '标签',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _institution.tags.map((tag) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB74D).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFB74D).withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF8A65),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medical_services_outlined,
                    size: 18,
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  '相关医生',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < _institution.doctors.length; i++) ...[
              if (i > 0)
                Divider(height: 1, color: isDark ? Colors.grey.shade800 : null),
              _buildDoctorTile(_institution.doctors[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorTile(MedicalDoctor doctor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF5BCEFA).withOpacity(0.1),
            child: const Icon(Icons.person, size: 20, color: Color(0xFF5BCEFA)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                if (doctor.title != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    doctor.title!,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                    ),
                  ),
                ],
                if (doctor.notes != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    doctor.notes!,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 18,
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  '备注',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _institution.notes!,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceLink() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText =
        isDark ? const Color(0xFF98989E) : const Color(0xFF86868B);
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_institution.sourceUrl!),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: '复制',
                onPressed: () {},
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.open_in_new, size: 18, color: Colors.blue.shade400),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '信息来源',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _institution.sourceUrl!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade50,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined,
                  size: 36,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(
                '地图功能即将上线',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                ),
              ),
              if (_institution.latitude != null &&
                  _institution.longitude != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${_institution.latitude!.toStringAsFixed(4)}, '
                  '${_institution.longitude!.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
