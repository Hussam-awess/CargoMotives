/// Common truck body types offered as a dropdown on Add Truck (still just
/// a suggestion list, not a server-side enum — Truck.vehicle_type stays a
/// free string on the backend, see SubmitTruckRequest). [kOtherTruckType]
/// is a sentinel, never sent as the actual value: selecting it reveals a
/// plain text field for whatever the real answer is.
const kOtherTruckType = 'Other';

const kTruckTypes = [
  'Flatbed',
  'Box Truck',
  'Container Trailer',
  'Tanker',
  'Refrigerated (Reefer)',
  'Curtain-sider',
  'Lowbed',
  'Dump Truck',
  kOtherTruckType,
];

/// Common make+model combinations offered as autocomplete suggestions on
/// Add Truck's make/model field — typing "Isuzu" suggests every Isuzu
/// entry below. Purely a convenience list: the field stays free text, so
/// anything not here can still be typed and submitted as-is.
const kTruckMakeModels = [
  'Isuzu FVR',
  'Isuzu NPR',
  'Isuzu FRR',
  'Isuzu NQR',
  'Isuzu GIGA',
  'Scania G410',
  'Scania R450',
  'Scania P360',
  'MAN TGS',
  'MAN TGX',
  'MAN TGL',
  'Mercedes-Benz Actros',
  'Mercedes-Benz Axor',
  'Mercedes-Benz Atego',
  'FUSO Fighter',
  'FUSO Canter',
  'Hino 500 Series',
  'Hino 700 Series',
  'Hino Dutro',
  'DAF XF',
  'DAF CF',
  'Volvo FH',
  'Volvo FM',
  'Tata Prima',
  'Tata LPT',
  'Sinotruk HOWO',
  'UD Trucks Quon',
  'UD Trucks Quester',
];
