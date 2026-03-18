class Perfil {
  final String id;
  final String nombre;
  final int rolId;
  final bool estado;

  Perfil({required this.id, required this.nombre, required this.rolId, required this.estado});

  // Convierte el JSON de la base de datos a un objeto de Dart
  factory Perfil.fromMap(Map<String, dynamic> map) {
    return Perfil(
      id: map['id'],
      nombre: map['nombre_completo'] ?? '',
      rolId: map['rol_id'] ?? 4,
      estado: map['estado'] ?? true,
    );
  }
}