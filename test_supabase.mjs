import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

const env = fs.readFileSync('.env', 'utf8');
const urlMatch = env.match(/VITE_SUPABASE_URL="([^"]+)"/);
const keyMatch = env.match(/VITE_SUPABASE_ANON_KEY="([^"]+)"/);

const url = urlMatch ? urlMatch[1] : '';
const key = keyMatch ? keyMatch[1] : '';

console.log('URL:', url ? url.substring(0, 35) + '...' : 'VACIA');
console.log('KEY:', key ? key.substring(0, 25) + '...' : 'VACIA');

if (!url || !key) {
  console.log('ERROR: Faltan credenciales de Supabase en .env');
  process.exit(1);
}

const supabase = createClient(url, key);

const { count, error } = await supabase
  .from('products')
  .select('count', { count: 'exact', head: true });

if (error) {
  console.log('ERROR de conexion:', error.message);
} else {
  console.log('CONECTADO correctamente a Supabase');
  console.log('Productos en la BD:', count);
}

// Also check other tables
for (const table of ['categories', 'orders', 'order_items', 'payments']) {
  const { count: c, error: e } = await supabase
    .from(table)
    .select('count', { count: 'exact', head: true });
  if (e) {
    console.log(`  ${table}: ERROR - ${e.message}`);
  } else {
    console.log(`  ${table}: ${c} registros`);
  }
}
