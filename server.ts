import 'dotenv/config';
import express from 'express';
import path from 'path';
import { createServer as createViteServer } from 'vite';
import { 
  getDbStatus, 
  getProducts, 
  createProduct, 
  updateProduct, 
  deleteProduct, 
  getOrders, 
  createOrder,
  getCart,
  saveCart
} from './server_db';
import { Product, Order } from './src/types';

// Let's create the Express and Vite hybrid development / production server
async function startServer() {
  const app = express();
  const PORT = 3000;

  // JSON parsing middleware
  app.use(express.json());

  // Log API requests for debugging
  app.use((req, res, next) => {
    console.log(`[API ${req.method}] ${req.url}`);
    next();
  });

  // -------------------------------------------------------------------------
  // ENDPOINT: Database Connection and System Status
  // -------------------------------------------------------------------------
  app.get('/api/db-status', (req, res) => {
    try {
      const status = getDbStatus();
      res.json(status);
    } catch (error: any) {
      res.status(500).json({ error: error.message || 'Error checking status' });
    }
  });

  // -------------------------------------------------------------------------
  // API: Products Catalog
  // -------------------------------------------------------------------------
  app.get('/api/products', async (req, res) => {
    try {
      const products = await getProducts();
      res.json(products);
    } catch (error: any) {
      res.status(500).json({ error: error.message || 'Failed to fetch products' });
    }
  });

  app.post('/api/products', async (req, res) => {
    try {
      const productBody: Product = req.body;
      if (!productBody.title || !productBody.sku || !productBody.brand || !productBody.price) {
        res.status(400).json({ error: 'Missing required product fields (title, sku, brand, price)' });
        return;
      }
      
      // Auto-generate numeric or string ID if missing
      const newProduct: Product = {
        ...productBody,
        id: productBody.id || `prod-${Date.now()}`
      };

      const created = await createProduct(newProduct);
      res.status(201).json(created);
    } catch (error: any) {
      res.status(500).json({ error: error.message || 'Failed to create product' });
    }
  });

  app.put('/api/products/:id', async (req, res) => {
    try {
      const { id } = req.params;
      const updates = req.body;
      const updated = await updateProduct(id, updates);
      
      if (!updated) {
        res.status(404).json({ error: 'Product not found' });
        return;
      }
      res.json(updated);
    } catch (error: any) {
      res.status(500).json({ error: error.message || 'Failed to update product' });
    }
  });

  app.delete('/api/products/:id', async (req, res) => {
    try {
      const { id } = req.params;
      const deleted = await deleteProduct(id);
      if (!deleted) {
        res.status(404).json({ error: 'Product not found or delete unsuccessful' });
        return;
      }
      res.json({ success: true, message: 'Product successfully deleted' });
    } catch (error: any) {
      res.status(500).json({ error: error.message || 'Failed to delete product' });
    }
  });

  // -------------------------------------------------------------------------
  // API: Orders System
  // -------------------------------------------------------------------------
  app.get('/api/orders', async (req, res) => {
    try {
      const orders = await getOrders();
      res.json(orders);
    } catch (error: any) {
      res.status(500).json({ error: error.message || 'Failed to fetch orders' });
    }
  });

  app.post('/api/orders', async (req, res) => {
    try {
      const orderBody: Order = req.body;
      if (!orderBody.customerName || !orderBody.items || orderBody.items.length === 0 || !orderBody.total) {
        res.status(400).json({ error: 'Invalid order payloads. Missing customerName, items, or total.' });
        return;
      }

      const newOrder: Order = {
        ...orderBody,
        id: orderBody.id || `ORD-${Math.floor(1000 + Math.random() * 9000)}`,
        date: orderBody.date || new Date().toISOString().split('T')[0]
      };

      const created = await createOrder(newOrder);
      res.status(201).json(created);
    } catch (error: any) {
      res.status(500).json({ error: error.message || 'Failed to place order' });
    }
  });

  // -------------------------------------------------------------------------
  // API: Cart (persistente en Supabase)
  // -------------------------------------------------------------------------
  app.get('/api/cart', async (req, res) => {
    try {
      const sessionId = req.query.session_id as string;
      if (!sessionId) {
        res.json([]);
        return;
      }
      const cart = await getCart(sessionId);
      res.json(cart);
    } catch (error: any) {
      res.status(500).json({ error: error.message || 'Failed to fetch cart' });
    }
  });

  app.post('/api/cart', async (req, res) => {
    try {
      const { session_id, items } = req.body;
      if (!session_id) {
        res.status(400).json({ error: 'session_id is required' });
        return;
      }
      await saveCart(session_id, items || []);
      res.json({ success: true });
    } catch (error: any) {
      res.status(500).json({ error: error.message || 'Failed to save cart' });
    }
  });

  // -------------------------------------------------------------------------
  // Static Assets / Vite setup Integration
  // -------------------------------------------------------------------------
  if (process.env.NODE_ENV !== 'production') {
    console.log('Vite executing in Development Middleware mode...');
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  } else {
    console.log('App running in Production Serving mode.');
    const distPath = path.join(process.cwd(), 'dist');
    app.use(express.static(distPath));
    app.get('*', (req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Leandro Baterías Server successfully started on http://0.0.0.0:${PORT}`);
  });
}

startServer().catch((err) => {
  console.error('Fatal crash on starting Leandro Baterías server:', err);
});
