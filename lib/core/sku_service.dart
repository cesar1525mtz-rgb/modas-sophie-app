class SkuService {
  static String baseSku({
    required String prefix,
    required int consecutive,
  }) {
    return '${prefix.toUpperCase()}-${consecutive.toString().padLeft(4, '0')}';
  }

  static String variantSku({
    required String baseSku,
    String? size,
    String? color,
  }) {
    final parts = <String>[baseSku];

    if (size != null && size.trim().isNotEmpty) {
      parts.add(_clean(size));
    }
    if (color != null && color.trim().isNotEmpty) {
      parts.add(_colorCode(color));
    }

    return parts.join('-');
  }

  static String _clean(String value) =>
      value.trim().toUpperCase().replaceAll(' ', '');

  static String _colorCode(String color) {
    const known = {
      'NEGRO': 'NEG',
      'ROSA': 'ROS',
      'BLANCO': 'BLA',
      'AZUL': 'AZU',
      'ROJO': 'ROJ',
      'GRIS': 'GRI',
      'BEIGE': 'BEI',
      'VERDE': 'VER',
      'MORADO': 'MOR',
    };

    final normalized = color.trim().toUpperCase();
    return known[normalized] ??
        normalized.replaceAll(' ', '').substring(
              0,
              normalized.replaceAll(' ', '').length.clamp(0, 3),
            );
  }
}
