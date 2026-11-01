// Job categories and work types — edit here to add/remove options.
// Changes apply to: admin.html, jobs.html, job-detail.html, index.html

var JOB_CATEGORIES = [
  { value: 'kitchen',            en: 'Kitchen',       es: 'Cocina' },
  { value: 'construction',       en: 'Construction',  es: 'Construcción' },
  { value: 'moving',             en: 'Moving',        es: 'Mudanzas' },
  { value: 'cleaning',           en: 'Cleaning',      es: 'Limpieza' },
  { value: 'landscaping',        en: 'Landscaping',   es: 'Landscaping' },
  { value: 'painting',           en: 'Painting',      es: 'Pintura' },
  { value: 'plumbing',           en: 'Plumbing',      es: 'Plomería' },
  { value: 'electrical',         en: 'Electrical',    es: 'Electricidad' },
  { value: 'other_general_labor',en: 'General Labor', es: 'Mano de obra' },
  { value: 'other',              en: 'Other',         es: 'Otro' },
];

var JOB_WORK_TYPES = [
  { value: 'gig',       en: 'Gig / One-time',  es: 'Eventual' },
  { value: 'part_time', en: 'Part-time',        es: 'Medio tiempo' },
  { value: 'full_time', en: 'Full-time',        es: 'Tiempo completo' },
];

// Helper: value → label
function jobCatLabel(value, lang) {
  var c = JOB_CATEGORIES.find(function(c){ return c.value === value; });
  return c ? c[lang] || c.en : value;
}
function jobWorkLabel(value, lang) {
  var w = JOB_WORK_TYPES.find(function(w){ return w.value === value; });
  return w ? w[lang] || w.en : value;
}
