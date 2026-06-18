import React, { useState, useMemo, useEffect } from 'react';
import Header from './components/Header';
import Footer from './components/Footer';
import BrandListSidebar from './components/BrandListSidebar';
import ProductCard from './components/ProductCard';
import CartDrawer from './components/CartDrawer';
import LoginView from './components/LoginView';
import CheckoutView from './components/CheckoutView';
import AdminView from './components/AdminView';

import { Product, CartItem, Order, ViewType, DbStatus } from './types';
import { INITIAL_PRODUCTS, INITIAL_ORDERS } from './data';
import { Sparkles, SlidersHorizontal, Search, ShoppingCart, HelpCircle, AlertCircle, Database } from 'lucide-react';

export default function App() {
  // Primary States
  const [products, setProducts] = useState<Product[]>(INITIAL_PRODUCTS);
  const [orders, setOrders] = useState<Order[]>(INITIAL_ORDERS);
  const [cartItems, setCartItems] = useState<CartItem[]>([]);
  const [cartLoaded, setCartLoaded] = useState(false);
  const [currentView, setView] = useState<ViewType>('catalog');

  // Interactive Preference States
  const [cartOpen, setCartOpen] = useState(false);
  const [theme, setTheme] = useState<'light' | 'dark'>('light');
  const [lang, setLang] = useState<'ES' | 'EN'>('ES');

  // Filtering States
  const [selectedBrands, setSelectedBrands] = useState<string[]>([]);
  const [selectedAmperages, setSelectedAmperages] = useState<string[]>([]);
  const [catalogSearch, setCatalogSearch] = useState('');
  const [mobileFiltersOpen, setMobileFiltersOpen] = useState(false);

  // Session ID for cart persistence (se mantiene entre recargas)
  const [sessionId] = useState(() => {
    let sid = localStorage.getItem('cart_session_id');
    if (!sid) {
      sid = crypto.randomUUID();
      localStorage.setItem('cart_session_id', sid);
    }
    return sid;
  });

  // Auth helper
  const [isAdminAuthenticated, setIsAdminAuthenticated] = useState(false);

  // DB Connected status info
  const [dbStatus, setDbStatus] = useState<DbStatus | null>(null);
  const [isDataLoading, setIsDataLoading] = useState(true);

  // Fetch Database content on component mount
  useEffect(() => {
    let active = true;
    async function loadBackendData() {
      try {
        const [pRes, oRes, sRes] = await Promise.all([
          fetch('/api/products').then(res => res.json()),
          fetch('/api/orders').then(res => res.json()),
          fetch('/api/db-status').then(res => res.json()).catch(() => null)
        ]);

        if (!active) return;

        if (Array.isArray(pRes)) {
          setProducts(pRes);
        }
        if (Array.isArray(oRes)) {
          setOrders(oRes);
        }
        if (sRes) {
          setDbStatus(sRes);
        }
      } catch (err) {
        console.error('Error contacting backend service:', err);
      } finally {
        if (active) {
          setIsDataLoading(false);
        }
      }
    }
    loadBackendData();
    return () => { active = false; };
  }, []);

  // Cargar carrito desde Supabase al iniciar
  useEffect(() => {
    let active = true;
    async function loadCart() {
      try {
        const res = await fetch(`/api/cart?session_id=${sessionId}`);
        const data = await res.json();
        if (active && Array.isArray(data) && data.length > 0) {
          setCartItems(data);
        }
      } catch (err) {
        console.error('Error loading cart from server:', err);
      } finally {
        if (active) setCartLoaded(true);
      }
    }
    loadCart();
    return () => { active = false; };
  }, [sessionId]);

  // Sincronizar carrito con Supabase cada vez que cambie
  useEffect(() => {
    if (!cartLoaded) return;
    const timer = setTimeout(() => {
      fetch('/api/cart', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ session_id: sessionId, items: cartItems })
      }).catch(err => console.error('Error syncing cart:', err));
    }, 300);
    return () => clearTimeout(timer);
  }, [cartItems, sessionId, cartLoaded]);

  // Cart operations
  const addToCart = (product: Product) => {
    setCartItems((prevItems) => {
      const existing = prevItems.find((item) => item.product.id === product.id);
      if (existing) {
        if (existing.quantity >= product.stock) {
          alert(lang === 'ES' ? 'No hay más unidades en stock' : 'No more units in stock');
          return prevItems;
        }
        return prevItems.map((item) =>
          item.product.id === product.id
            ? { ...item, quantity: item.quantity + 1 }
            : item
        );
      }
      return [...prevItems, { product, quantity: 1 }];
    });
    // Open cart drawer immediately for visual feedback
    setCartOpen(true);
  };

  const updateQuantity = (productId: string, delta: number) => {
    setCartItems((prevItems) => {
      return prevItems
        .map((item) => {
          if (item.product.id === productId) {
            const nextQuantity = item.quantity + delta;
            if (nextQuantity <= 0) {
              return null;
            }
            if (nextQuantity > item.product.stock) {
              alert(lang === 'ES' ? 'Límite de stock alcanzado' : 'Stock limit reached');
              return item;
            }
            return { ...item, quantity: nextQuantity };
          }
          return item;
        })
        .filter(Boolean) as CartItem[];
    });
  };

  const removeFromCart = (productId: string) => {
    setCartItems((prevItems) => prevItems.filter((item) => item.product.id !== productId));
  };

  const clearCart = () => {
    setCartItems([]);
  };

  const addNewOrder = async (order: Order) => {
    // 1. Pessimistically trigger post sequence
    try {
      const response = await fetch('/api/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(order)
      });
      if (response.ok) {
        // Fetch fresh products or map state directly
        const freshProducts = await fetch('/api/products').then(res => res.json());
        if (Array.isArray(freshProducts)) {
          setProducts(freshProducts);
        } else {
          setProducts((prevProducts) => {
            return prevProducts.map((prod) => {
              const matchingCartItem = order.items.find((item) => item.product.id === prod.id);
              if (matchingCartItem) {
                const nextStock = Math.max(0, prod.stock - matchingCartItem.quantity);
                return { ...prod, stock: nextStock };
              }
              return prod;
            });
          });
        }

        const freshOrders = await fetch('/api/orders').then(res => res.json());
        if (Array.isArray(freshOrders)) {
          setOrders(freshOrders);
        } else {
          setOrders((prevOrders) => [order, ...prevOrders]);
        }
      } else {
        const errorMsg = await response.json().then(j => j.error).catch(() => 'Unknown network error');
        console.error('Failed to create order on server:', errorMsg);
        // Fallback save order locally
        setProducts((prevProducts) => {
          return prevProducts.map((prod) => {
            const matchingCartItem = order.items.find((item) => item.product.id === prod.id);
            if (matchingCartItem) {
              const nextStock = Math.max(0, prod.stock - matchingCartItem.quantity);
              return { ...prod, stock: nextStock };
            }
            return prod;
          });
        });
        setOrders((prevOrders) => [order, ...prevOrders]);
      }
    } catch (err) {
      console.error('Server is offline or database connection is busy. Fallback save locally:', err);
      setProducts((prevProducts) => {
        return prevProducts.map((prod) => {
          const matchingCartItem = order.items.find((item) => item.product.id === prod.id);
          if (matchingCartItem) {
            const nextStock = Math.max(0, prod.stock - matchingCartItem.quantity);
            return { ...prod, stock: nextStock };
          }
          return prod;
        });
      });
      setOrders((prevOrders) => [order, ...prevOrders]);
    }
  };

  // Filter Catalog Products
  const filteredProducts = useMemo(() => {
    return products.filter((prod) => {
      const matchSearch = 
        prod.title.toLowerCase().includes(catalogSearch.toLowerCase()) ||
        prod.sku.toLowerCase().includes(catalogSearch.toLowerCase()) ||
        prod.brand.toLowerCase().includes(catalogSearch.toLowerCase());

      const matchBrand = selectedBrands.length === 0 || selectedBrands.includes(prod.brand);
      const matchAmperage = selectedAmperages.length === 0 || (prod.amperage && selectedAmperages.includes(prod.amperage));

      return matchSearch && matchBrand && matchAmperage;
    });
  }, [products, catalogSearch, selectedBrands, selectedAmperages]);

  const cartCount = cartItems.reduce((acc, item) => acc + item.quantity, 0);

  return (
    <div className={`min-h-screen font-sans flex flex-col transition-colors duration-200 ${
      theme === 'dark' ? 'dark bg-slate-950 text-slate-900 dark:text-slate-100' : 'bg-white text-slate-900'
    }`}>
      
      {/* 1. Header (Omitted for global full-screen admin layout) */}
      {currentView !== 'admin' && (
        <Header 
          currentView={currentView}
          setView={setView}
          cartCount={cartCount}
          toggleCartOpen={() => setCartOpen(!cartOpen)}
          theme={theme}
          setTheme={setTheme}
          lang={lang}
          setLang={setLang}
          dbStatus={dbStatus}
        />
      )}

      {/* 2. Primary Routing Section */}
      <div className="flex-grow">
        {currentView === 'catalog' && (
          <main className="max-w-7xl mx-auto px-4 md:px-10 py-8">
            
            {/* Promotional Banner */}
            <div className="relative overflow-hidden bg-slate-900 text-slate-900 dark:text-white rounded-2xl p-6 md:p-8 mb-8 shadow-xl flex flex-col md:flex-row items-center justify-between gap-6 border border-slate-800">
              <div className="absolute right-0 top-0 bottom-0 w-1/3 bg-blue-600/10 blur-[100px] pointer-events-none select-none" />
              <div className="space-y-2 max-w-lg relative z-10 text-center md:text-left">
                <span className="inline-flex items-center gap-1 text-xs font-bold text-blue-400 bg-blue-500/10 px-2.5 py-1 rounded-full uppercase tracking-wider">
                  <Sparkles size={12} />
                  {lang === 'ES' ? 'PROMO DE TEMPORADA' : 'SEASONAL PROMO'}
                </span>
                <h1 className="text-xl md:text-2xl font-extrabold tracking-tight">
                  {lang === 'ES' ? 'Delivery e Instalación Gratis hoy' : 'Free Home Delivery & Installation today'}
                </h1>
                <p className="text-xs text-slate-400 leading-relaxed">
                  {lang === 'ES' 
                    ? 'Compre su batería en línea con instalación profesional incluida a domicilio en tiempo récord.' 
                    : 'Get your backup power with official technician installation anywhere in Lima Metropolitan.'}
                </p>
              </div>
              
              {/* Promotional QR badge */}
              <div className="bg-slate-950 rounded-xl p-4 border border-slate-800 text-center flex flex-col items-center flex-shrink-0 select-none">
                <div className="w-16 h-16 bg-blue-600/20 border border-blue-500/30 rounded-lg flex items-center justify-center font-bold text-blue-400 text-xs animate-pulse">
                  QR CODE
                </div>
                <span className="text-[10px] text-slate-400 mt-2 font-mono">
                  {lang === 'ES' ? 'Asistencia WhatsApp' : 'WhatsApp Support'}
                </span>
                <strong className="text-slate-200 text-xs">987 654 321</strong>
              </div>
            </div>

            {/* Layout Split: Side Filters & Product Grid */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
              
              {/* Sidebar Filters - Desktop (hidden on mobile) */}
              <aside className="hidden md:block md:col-span-1">
                <BrandListSidebar 
                  selectedBrands={selectedBrands}
                  setSelectedBrands={setSelectedBrands}
                  selectedAmperages={selectedAmperages}
                  setSelectedAmperages={setSelectedAmperages}
                  lang={lang}
                />
              </aside>

              {/* Main Catalog View Grid */}
              <section className="md:col-span-3 space-y-6">
                
                {/* Search & Overview count toolbar */}
                <div className="flex flex-col sm:flex-row gap-4 items-center justify-between bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-xl px-4 py-3 shadow-xs">
                  
                  {/* Search accumulate Input */}
                  <div className="relative w-full sm:max-w-xs flex items-center bg-slate-50 dark:bg-slate-950 border border-slate-150 dark:border-slate-850 rounded-lg px-3 py-2">
                    <Search size={14} className="text-slate-400 mr-2 flex-shrink-0" />
                    <input 
                      type="text"
                      className="w-full bg-transparent border-none text-xs text-slate-900 dark:text-white outline-none focus:ring-0 placeholder:text-slate-500 focus:outline-none"
                      placeholder={lang === 'ES' ? 'Buscar modelo, marca...' : 'Search baterias...'}
                      value={catalogSearch}
                      onChange={(e) => setCatalogSearch(e.target.value)}
                    />
                  </div>

                  {/* Summary Counter text */}
                  <div className="text-xs text-slate-500 font-sans font-medium flex items-center gap-2">
                    <span>
                      {lang === 'ES' 
                        ? `Mostrando ${filteredProducts.length} acumuladores` 
                        : `Showing ${filteredProducts.length} power accumulators`}
                    </span>
                    
                    {/* Floating Mobile Filter Trigger Button */}
                    <button 
                      onClick={() => setMobileFiltersOpen(true)}
                      className="md:hidden flex items-center gap-1 px-2.5 py-1.5 rounded-lg border border-slate-200 dark:border-slate-800 bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 font-bold text-[10px] cursor-pointer"
                    >
                      <SlidersHorizontal size={10} />
                      {lang === 'ES' ? 'Filtros' : 'Filters'}
                    </button>
                  </div>

                </div>

                {/* Product listing matrix */}
                {filteredProducts.length === 0 ? (
                  <div className="text-center py-20 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl flex flex-col items-center gap-3">
                    <div className="p-4 rounded-full bg-slate-100 dark:bg-slate-800 text-slate-400">
                      <HelpCircle size={40} />
                    </div>
                    <div>
                      <h3 className="font-bold text-slate-800 dark:text-slate-200">
                        {lang === 'ES' ? 'No se encontraron baterías' : 'No batteries found'}
                      </h3>
                      <p className="text-xs text-slate-500 dark:text-slate-450 max-w-[260px] mx-auto mt-1">
                        {lang === 'ES' 
                          ? 'Prueba modificando las marcas seleccionadas o limpiando la barra de búsqueda.' 
                          : 'Try removing selected brand tags or checking the spelling of your query.'}
                      </p>
                    </div>
                    <button 
                      onClick={() => { setSelectedBrands([]); setSelectedAmperages([]); setCatalogSearch(''); }}
                      className="text-xs font-semibold px-4 py-2 rounded-lg bg-blue-600 hover:bg-blue-500 text-slate-900 dark:text-white transition-all cursor-pointer"
                    >
                      {lang === 'ES' ? 'Limpiar Filtros' : 'Reset Filters'}
                    </button>
                  </div>
                ) : (
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
                    {filteredProducts.map((prod) => (
                      <ProductCard 
                        key={prod.id} 
                        product={prod} 
                        addToCart={addToCart} 
                        lang={lang} 
                      />
                    ))}
                  </div>
                )}

              </section>

            </div>

            {/* Mobile Filters Side Drawer popover */}
            {mobileFiltersOpen && (
              <div className="fixed inset-0 z-50 overflow-hidden md:hidden">
                <div className="absolute inset-0 bg-slate-950/60 backdrop-blur-xs" onClick={() => setMobileFiltersOpen(false)} />
                <div className="absolute inset-y-0 right-0 max-w-xs w-full bg-white dark:bg-slate-900 p-6 shadow-xl flex flex-col gap-6 animate-in slide-in-from-right duration-200 overflow-y-auto">
                  <div className="flex justify-between items-center pb-3 border-b border-neutral-100 dark:border-slate-800">
                    <h3 className="font-sans font-bold text-slate-900 dark:text-white text-sm">
                      {lang === 'ES' ? 'Filtrar Productos' : 'Filter Products'}
                    </h3>
                    <button onClick={() => setMobileFiltersOpen(false)} className="text-slate-400 hover:text-slate-600 dark:hover:text-slate-900 dark:text-white text-xs font-bold font-mono">
                      CERRAR
                    </button>
                  </div>
                  <BrandListSidebar 
                    selectedBrands={selectedBrands}
                    setSelectedBrands={setSelectedBrands}
                    selectedAmperages={selectedAmperages}
                    setSelectedAmperages={setSelectedAmperages}
                    lang={lang}
                    onClose={() => setMobileFiltersOpen(false)}
                  />
                </div>
              </div>
            )}

          </main>
        )}

        {currentView === 'checkout' && (
          <CheckoutView 
            cartItems={cartItems} 
            setView={setView} 
            lang={lang} 
            clearCart={clearCart} 
            addNewOrder={addNewOrder} 
          />
        )}

        {currentView === 'login' && (
          <LoginView 
            setView={setView} 
            lang={lang} 
            onLoginSuccess={() => setIsAdminAuthenticated(true)}
          />
        )}

        {currentView === 'admin' && (
          <AdminView 
            products={products}
            setProducts={setProducts}
            orders={orders}
            setView={setView}
            lang={lang}
            theme={theme}
            setTheme={setTheme}
            dbStatus={dbStatus}
          />
        )}
      </div>

      {/* 3. Global Cart Drawer Popup */}
      <CartDrawer 
        isOpen={cartOpen} 
        onClose={() => setCartOpen(false)} 
        cartItems={cartItems} 
        updateQuantity={updateQuantity} 
        removeFromCart={removeFromCart} 
        setView={setView} 
        lang={lang} 
      />

      {/* 4. Footer (Omitted for global full-screen admin layout) */}
      {currentView !== 'admin' && (
        <Footer 
          lang={lang} 
          setView={setView} 
        />
      )}

    </div>
  );
}
