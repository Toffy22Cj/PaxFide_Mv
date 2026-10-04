/// Acciones operativas que pueden ejecutarse sobre un PhysicalAsset.
/// Conforme a front-fase1.md §9 y ADR-043 D2.
enum AssetAction {
  dispatch,
  receive,
  deliver,
  readOnly,
}