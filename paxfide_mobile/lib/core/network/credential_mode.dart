/// Modo de credencial requerido para el transporte HTTP (ADR-043 D4).
/// Refleja los tres mecanismos confirmados en ADR-041; nunca son intercambiables.
enum CredentialMode {
  none,
  jwt,
  tracking,
}