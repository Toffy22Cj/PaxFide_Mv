import 'package:flutter/material.dart';

import '../../../shared/quantity.dart';
import '../data/physical_asset_api.dart';
import 'lifecycle_status.dart';

/// Textos para personas de lo que el backend guarda como códigos (`FOOD_KIT`, `UNITS`, `centro-comunitario`).
/// El código interno del activo (`assetRef`) nunca es el título: solo se muestra pequeño, para soporte.

const _types = {
  'FOOD_KIT': 'Kit de alimentos',
  'FOOD': 'Alimentos',
  'BLANKET': 'Cobijas',
  'BLANKETS': 'Cobijas',
  'CLOTHING': 'Ropa',
  'CLOTHES': 'Ropa',
  'HYGIENE_KIT': 'Kit de higiene',
  'SCHOOL_KIT': 'Kit escolar',
  'SCHOOL_SUPPLIES': 'Útiles escolares',
  'MEDICINE': 'Medicamentos',
  'MEDICAL_SUPPLIES': 'Insumos médicos',
  'WATER': 'Agua',
  'TOYS': 'Juguetes',
  'SHOES': 'Calzado',
  'MATTRESS': 'Colchones',
  'TOOLS': 'Herramientas',
};

const _units = {
  'UNITS': ('unidad', 'unidades'),
  'UNIT': ('unidad', 'unidades'),
  'KG': ('kg', 'kg'),
  'KILOGRAMS': ('kg', 'kg'),
  'G': ('g', 'g'),
  'LITERS': ('litro', 'litros'),
  'L': ('litro', 'litros'),
  'BOXES': ('caja', 'cajas'),
  'BOX': ('caja', 'cajas'),
  'KITS': ('kit', 'kits'),
  'PACKS': ('paquete', 'paquetes'),
  'BAGS': ('bolsa', 'bolsas'),
};

/// «centro-comunitario», «FOOD_KIT» → «Centro comunitario», «Food kit»: sin guiones ni mayúsculas sostenidas.
String humanize(String raw) {
  final t = raw.trim().replaceAll(RegExp(r'[_\-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return t;
  final lower = t == t.toUpperCase() ? t.toLowerCase() : t;
  return lower[0].toUpperCase() + lower.substring(1);
}

String assetTypeLabel(String? type) {
  if (type == null || type.trim().isEmpty) return 'Activo';
  return _types[type.trim().toUpperCase()] ?? humanize(type);
}

/// «20 unidades», «1 unidad», «2,5 kg».
String quantityLabel(String? quantity, String? unit) {
  final q = quantity == null ? null : formatQuantity(quantity);
  final u = unit?.trim();
  if (u == null || u.isEmpty) return q ?? '—';
  final names = _units[u.toUpperCase()];
  final name = names == null ? humanize(u).toLowerCase() : (q == '1' ? names.$1 : names.$2);
  return q == null ? name : '$q $name';
}

/// El título del activo: «Kit de alimentos · 20 unidades».
String assetTitle(PhysicalAssetDto a) =>
    '${assetTypeLabel(a.assetType)} · ${quantityLabel(a.quantity, a.unitOfMeasure)}';

/// Código corto para reconocer el activo sin leer el UUID entero (las primeras 8 cifras).
String shortRef(String assetRef) => assetRef.length > 8 ? assetRef.substring(0, 8) : assetRef;

IconData lifecycleIcon(String wire) => switch (LifecycleStatus.fromWire(wire)) {
  LifecycleStatus.registered => Icons.inventory_2_outlined,
  LifecycleStatus.dispatched => Icons.local_shipping_outlined,
  LifecycleStatus.received => Icons.warehouse_outlined,
  LifecycleStatus.delivered => Icons.task_alt,
  LifecycleStatus.depleted => Icons.call_split,
  null => Icons.help_outline,
};
