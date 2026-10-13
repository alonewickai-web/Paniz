import 'package:flutter/material.dart';
import 'admin_api.dart';
import 'paniz_theme.dart';

class AdminAvatar extends StatelessWidget {
  const AdminAvatar({super.key, required this.name, this.path, this.size = 44});
  final String name;
  final String? path;
  final double size;
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      color: context.paniz.primarySoft,
      alignment: Alignment.center,
      child: Text(
        name.trim().isEmpty ? 'م' : name.trim().characters.first,
        style: TextStyle(
          color: context.paniz.primary,
          fontSize: size * .36,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return Semantics(
      label: 'تصویر $name',
      image: true,
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child:
              path?.trim().isNotEmpty == true
                  ? Image.network(
                    AdminApi.imageUrl(path!),
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    cacheWidth: (size * 3).round(),
                    errorBuilder: (_, __, ___) => fallback,
                  )
                  : fallback,
        ),
      ),
    );
  }
}
