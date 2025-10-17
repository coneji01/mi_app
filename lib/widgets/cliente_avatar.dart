// lib/widgets/cliente_avatar.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../models/cliente.dart';

ImageProvider<Object>? clienteImageProvider(Cliente cliente) {
  final rawPath = cliente.fotoPath?.trim();
  if (rawPath == null || rawPath.isEmpty) return null;

  final path = rawPath;
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }

  if (!kIsWeb) {
    final file = File(path);
    if (file.existsSync()) {
      return FileImage(file);
    }
  }

  final base = Repository.i.baseUrl.trim();
  if (base.isEmpty) return null;

  final normalizedBase = base.replaceAll(RegExp(r'/+$'), '');
  final normalizedPath = path.startsWith('/')
      ? path.substring(1)
      : path;

  return NetworkImage('$normalizedBase/$normalizedPath');
}

class ClienteAvatar extends StatelessWidget {
  const ClienteAvatar({
    super.key,
    required this.cliente,
    this.radius = 24,
    this.placeholderIcon = Icons.person,
  });

  final Cliente cliente;
  final double radius;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final image = clienteImageProvider(cliente);
    return CircleAvatar(
      radius: radius,
      backgroundImage: image,
      child: image == null
          ? Icon(
              placeholderIcon,
              size: radius,
            )
          : null,
    );
  }
}
