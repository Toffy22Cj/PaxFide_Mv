#!/usr/bin/env bash
# Muestra qué hay guardado en una base, sin cambiar nada (solo lectura).
#   ./ver-datos.sh pruebas   o   ./ver-datos.sh presentacion
source "$(dirname "$0")/comun.sh"
BASE="$(base_de "${1:-}")"
docker exec paxfide-demo-mongo mongosh --quiet "$BASE" --eval '
const estados = {CONFIRMED: "pagadas", PENDING: "esperando pago", FAILED: "pago fallido",
                 EXPIRED_UNKNOWN: "vencidas", FUNDING_REJECTED: "rechazadas"};
print("Causas: " + db.convocatorias.countDocuments());
db.convocatorias.find({}, {title: 1, status: 1}).forEach(c =>
  print("  - " + c.title + (c.status === "CLOSED" ? " (terminada)" : " (abierta)")));
print("Donaciones: " + db.donation_intents.countDocuments());
db.donation_intents.aggregate([{$group: {_id: "$status", n: {$sum: 1}}}]).forEach(g =>
  print("  - " + (estados[g._id] || g._id) + ": " + g.n));
const dias = db.donation_intents.aggregate([
  {$match: {status: "CONFIRMED"}},
  {$group: {_id: {$dateToString: {format: "%Y-%m-%d", date: "$confirmedAt", timezone: "America/Bogota"}}, n: {$sum: 1}}},
  {$sort: {_id: 1}}]).toArray();
print("Días con donaciones pagadas: " + dias.length);
dias.forEach(d => print("  - " + d._id + ": " + d.n));
'
