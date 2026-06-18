import fs from 'fs';
import path from 'path';
import { Product, Order, CartItem } from './src/types';
import { INITIAL_PRODUCTS, INITIAL_ORDERS } from './src/data';
import { createClient } from '@supabase/supabase-js';

export interface DbStatus {
  connected: boolean;
  mode: 'supabase' | 'local_file';
  server?: string;
  database?: string;
  error?: string;
}

const BACKUP_FILE = path.join(process.cwd(), 'data_store.json');

// Memory cache & backup system
let localProducts: Product[] = [];
let localOrders: Order[] = [];

function loadLocalData() {
  if (fs.existsSync(BACKUP_FILE)) {
    try {
      const fileData = fs.readFileSync(BACKUP_FILE, 'utf8');
      const data = JSON.parse(fileData);
      localProducts = data.products || INITIAL_PRODUCTS;
      localOrders = data.orders || INITIAL_ORDERS;
      console.log(`Loaded ${localProducts.length} products and ${localOrders.length} orders from local JSON database.`);
      return;
    } catch (e) {
      console.error('Error reading backup file, using defaults', e);
    }
  }
  localProducts = [...INITIAL_PRODUCTS];
  localOrders = [...INITIAL_ORDERS];
  saveLocalData();
}

function saveLocalData() {
  try {
    fs.writeFileSync(BACKUP_FILE, JSON.stringify({ products: localProducts, orders: localOrders }, null, 2), 'utf8');
  } catch (e) {
    console.error('Error writing backup file', e);
  }
}

loadLocalData();

const supabaseUrl = process.env.VITE_SUPABASE_URL || '';
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY || '';

const supabase = (supabaseUrl && supabaseKey) ? createClient(supabaseUrl, supabaseKey) : null;

export const dbStatus: DbStatus = {
  connected: !!supabase,
  mode: supabase ? 'supabase' : 'local_file',
  server: supabaseUrl || 'Local File System',
};

export function getDbStatus(): DbStatus {
  return dbStatus;
}

// --- DATA ACCESS METHODS ---

export async function getProducts(): Promise<Product[]> {
  if (supabase) {
    try {
      const { data, error } = await supabase.from('products').select('*');
      if (error) throw error;
      if (data && data.length > 0) return data;
    } catch (err: any) {
      console.error('Supabase error in getProducts:', err.message || err);
      // Fallback if table does not exist
      if (err?.code === '42P01') {
        console.warn('The products table does not exist in your Supabase project. Please run the SQL script.');
      }
    }
  }
  return localProducts;
}

export async function createProduct(prod: Product): Promise<Product> {
  if (supabase) {
    try {
      const { data, error } = await supabase.from('products').insert([prod]).select();
      if (error) throw error;
      if (data && data.length > 0) return data[0];
    } catch (err) {
      console.error('Supabase error in createProduct', err);
    }
  }
  localProducts.push(prod);
  saveLocalData();
  return prod;
}

export async function updateProduct(id: string, updates: Partial<Product>): Promise<Product | null> {
  if (supabase) {
    try {
      const { data, error } = await supabase.from('products').update(updates).eq('id', id).select();
      if (error) throw error;
      if (data && data.length > 0) return data[0];
    } catch (err) {
      console.error('Supabase error in updateProduct', err);
    }
  }
  const index = localProducts.findIndex(p => p.id === id);
  if (index !== -1) {
    localProducts[index] = { ...localProducts[index], ...updates };
    saveLocalData();
    return localProducts[index];
  }
  return null;
}

export async function deleteProduct(id: string): Promise<boolean> {
  if (supabase) {
    try {
      const { error } = await supabase.from('products').delete().eq('id', id);
      if (error) throw error;
      return true;
    } catch (err) {
      console.error('Supabase error in deleteProduct', err);
    }
  }
  const index = localProducts.findIndex(p => p.id === id);
  if (index !== -1) {
    localProducts.splice(index, 1);
    saveLocalData();
    return true;
  }
  return false;
}

export async function getOrders(): Promise<Order[]> {
  if (supabase) {
    // Basic implementation that doesn't natively join items
    try {
      const { data, error } = await supabase.from('orders').select('*');
      if (error) throw error;
      if (data) return data;
    } catch (err: any) {
      console.error('Supabase error in getOrders:', err.message || err);
      if (err?.code === '42P01') {
        console.warn('The orders table does not exist in your Supabase project. Please run the SQL script.');
      }
    }
  }
  return localOrders;
}

export async function createOrder(ord: Order): Promise<Order> {
  if (supabase) {
    try {
      const { data, error } = await supabase.from('orders').insert([ord]).select();
      if (error) throw error;
      if (data && data.length > 0) return data[0];
    } catch (err) {
      console.error('Supabase error in createOrder', err);
    }
  }
  localOrders.push(ord);
  saveLocalData();
  return ord;
}

// --- CART PERSISTENCE (Supabase) ---

export async function getCart(sessionId: string): Promise<CartItem[]> {
  if (supabase) {
    try {
      const { data: cart } = await supabase
        .from('shopping_carts')
        .select('id')
        .eq('session_id', sessionId)
        .eq('status', 'active')
        .maybeSingle();

      if (!cart) return [];

      const { data: items } = await supabase
        .from('cart_items')
        .select('product_id, quantity')
        .eq('cart_id', cart.id);

      if (!items || items.length === 0) return [];

      const productIds = items.map(i => i.product_id);
      const { data: products } = await supabase
        .from('products')
        .select('*')
        .in('id', productIds);

      if (!products) return [];

      const productMap = new Map(products.map(p => [p.id, p]));

      return items
        .map(item => {
          const product = productMap.get(item.product_id);
          if (!product) return null;
          return { product, quantity: item.quantity };
        })
        .filter(Boolean) as CartItem[];
    } catch (err) {
      console.error('Supabase error in getCart', err);
    }
  }
  return [];
}

export async function saveCart(sessionId: string, items: CartItem[]): Promise<boolean> {
  if (supabase) {
    try {
      let { data: existingCart } = await supabase
        .from('shopping_carts')
        .select('id')
        .eq('session_id', sessionId)
        .eq('status', 'active')
        .maybeSingle();

      let cartId: string;

      if (existingCart) {
        cartId = existingCart.id;
      } else {
        const { data: newCart } = await supabase
          .from('shopping_carts')
          .insert({ session_id: sessionId, status: 'active' })
          .select('id')
          .single();

        if (!newCart) return false;
        cartId = newCart.id;
      }

      await supabase.from('cart_items').delete().eq('cart_id', cartId);

      if (items.length > 0) {
        const cartItems = items.map(item => ({
          cart_id: cartId,
          product_id: item.product.id,
          quantity: item.quantity
        }));

        const { error } = await supabase.from('cart_items').insert(cartItems);
        if (error) throw error;
      }

      return true;
    } catch (err) {
      console.error('Supabase error in saveCart', err);
    }
  }
  return false;
}
