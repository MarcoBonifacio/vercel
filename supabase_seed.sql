-- =====================================================================================
-- SUPABASE FULL SETUP + SEED DATA
-- Proyecto: Leandro Baterías (E-Commerce)
-- Instrucciones: Pega todo este script en el Editor SQL de Supabase y ejecútalo.
-- =====================================================================================

-- ============================================================================
-- 1. EXTENSIONES
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 2. TABLAS (con IF NOT EXISTS por si ya existen)
-- ============================================================================

-- 2a. CLIENTES
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    document_type TEXT,
    document_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2b. CATEGORÍAS
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2c. PRODUCTOS
CREATE TABLE IF NOT EXISTS public.products (
    id TEXT PRIMARY KEY,
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    sku TEXT UNIQUE NOT NULL,
    brand TEXT NOT NULL,
    model TEXT NOT NULL,
    price NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    stock INTEGER NOT NULL DEFAULT 0,
    amperage TEXT,
    voltage TEXT NOT NULL,
    "imageUrl" TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2d. CARRITO DE COMPRAS
CREATE TABLE IF NOT EXISTS public.shopping_carts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE,
    session_id TEXT UNIQUE,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2e. ITEMS DEL CARRITO
CREATE TABLE IF NOT EXISTS public.cart_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID REFERENCES public.shopping_carts(id) ON DELETE CASCADE,
    product_id TEXT REFERENCES public.products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(cart_id, product_id)
);

-- 2f. ÓRDENES / FACTURACIÓN (Cabecera)
CREATE TABLE IF NOT EXISTS public.orders (
    id TEXT PRIMARY KEY,
    customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
    date TEXT NOT NULL,
    "customerName" TEXT NOT NULL,
    "documentId" TEXT NOT NULL,
    "receiptType" TEXT NOT NULL,
    email TEXT NOT NULL,
    "phoneNumber" TEXT NOT NULL,
    shipping_address TEXT,
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    taxes NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    total NUMERIC(10, 2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'Pendiente',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2g. DETALLES DE LA ORDEN (Items)
CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id TEXT REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id TEXT REFERENCES public.products(id) ON DELETE SET NULL,
    product_title TEXT NOT NULL,
    product_sku TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL,
    subtotal_price NUMERIC(10, 2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2h. PAGOS
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id TEXT REFERENCES public.orders(id) ON DELETE CASCADE,
    "paymentMethod" TEXT NOT NULL,
    transaction_reference TEXT,
    amount NUMERIC(10, 2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'Pendiente',
    paid_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 3. TRIGGER PARA updated_at AUTOMÁTICO
-- ============================================================================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'set_products_updated_at') THEN
        CREATE TRIGGER set_products_updated_at
            BEFORE UPDATE ON public.products
            FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'set_shopping_carts_updated_at') THEN
        CREATE TRIGGER set_shopping_carts_updated_at
            BEFORE UPDATE ON public.shopping_carts
            FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'set_orders_updated_at') THEN
        CREATE TRIGGER set_orders_updated_at
            BEFORE UPDATE ON public.orders
            FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
    END IF;
END $$;

-- ============================================================================
-- 4. ÍNDICES PARA RENDIMIENTO
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_products_brand ON public.products(brand);
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_is_active ON public.products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_sku ON public.products(sku);
CREATE INDEX IF NOT EXISTS idx_orders_customer ON public.orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_cart ON public.cart_items(cart_id);
CREATE INDEX IF NOT EXISTS idx_payments_order ON public.payments(order_id);

-- ============================================================================
-- 5. DESHABILITAR ROW LEVEL SECURITY (desarrollo)
-- ============================================================================
ALTER TABLE public.customers DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.shopping_carts DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments DISABLE ROW LEVEL SECURITY;

-- ============================================================================
-- ============================================================================
-- 6. DATOS SEMILLA (SEED DATA)
-- ============================================================================
-- ============================================================================

-- 6a. CATEGORÍA
INSERT INTO public.categories (id, name, description)
VALUES (
    'a0000000-0000-0000-0000-000000000001',
    'Baterías para Autos',
    'Baterías de 12V para vehículos livianos y pesados'
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 6b. PRODUCTOS (62 baterías)
-- ============================================================================

-- CAPSA (17 productos)
INSERT INTO public.products (id, category_id, title, sku, brand, model, price, stock, amperage, voltage, "imageUrl", is_active) VALUES
('prod-1',  'a0000000-0000-0000-0000-000000000001', 'Capsa U1R 500',               'CAPSA-U1R-500-1',       'Capsa',  'U1R 500',       200, 14, '50Ah', '12V', 'https://bateriascapsa.com/wp-content/uploads/2025/09/U1R-500.png', TRUE),
('prod-2',  'a0000000-0000-0000-0000-000000000001', 'Capsa NS40L 670',             'CAPSA-NS40L-670-2',     'Capsa',  'NS40L 670',     280, 10, '50Ah', '12V', 'https://bateriascapsa.com/wp-content/uploads/2021/04/NS40L550.png', TRUE),
('prod-3',  'a0000000-0000-0000-0000-000000000001', 'Capsa NS60L 700',             'CAPSA-NS60L-700-3',     'Capsa',  'NS60L 700',     300, 15, '50Ah', '12V', 'https://bateriascapsa.com/wp-content/uploads/2021/04/NS60LS700.png', TRUE),
('prod-4',  'a0000000-0000-0000-0000-000000000001', 'Capsa NS60L 770',             'CAPSA-NS60L-770-4',     'Capsa',  'NS60L 770',     320, 24, '50Ah', '12V', 'https://bateriascapsa.com/wp-content/uploads/2025/09/NS60LS-770.png', TRUE),
('prod-5',  'a0000000-0000-0000-0000-000000000001', 'Capsa 42I 800',               'CAPSA-42I-800-5',       'Capsa',  '42I 800',       315,  9, '50Ah', '12V', 'https://bateriascapsa.com/wp-content/uploads/2025/09/42I-800.png', TRUE),
('prod-6',  'a0000000-0000-0000-0000-000000000001', 'Capsa 42I 900',               'CAPSA-42I-900-6',       'Capsa',  '42I 900',       320, 22, '50Ah', '12V', 'https://bateriascapsa.com/wp-content/uploads/2025/09/42-900.png', TRUE),
('prod-7',  'a0000000-0000-0000-0000-000000000001', 'Capsa 24R 950',               'CAPSA-24R-950-7',       'Capsa',  '24R 950',       350,  9, '50Ah', '12V', 'https://bateriascapsa.com/wp-content/uploads/2025/11/24R-1100.png', TRUE),
('prod-8',  'a0000000-0000-0000-0000-000000000001', 'Capsa 27R 1150',              'CAPSA-27R-1150-8',      'Capsa',  '27R 1150',      430, 17, '50Ah', '12V', 'https://bateriascapsa.com/wp-content/uploads/2025/09/27R-1150.png', TRUE),
('prod-9',  'a0000000-0000-0000-0000-000000000001', 'Capsa 27 1150',               'CAPSA-27-1150-9',       'Capsa',  '27 1150',       430, 16, '50Ah', '12V', 'https://bateriascapsa.com/wp-content/uploads/2025/09/27-1150.png', TRUE),
('prod-10', 'a0000000-0000-0000-0000-000000000001', 'Capsa 30H 1600',              'CAPSA-30H-1600-10',     'Capsa',  '30H 1600',      490, 10, '50Ah', '12V', 'https://bateriascapsa.com/wp-content/uploads/2025/09/30H-1600.png', TRUE),
('prod-11', 'a0000000-0000-0000-0000-000000000001', 'Capsa 31T 1600 500',          'CAPSA-31T-1600-500-11', 'Capsa',  '31T 1600 500',  500, 16, '50Ah', '12V', 'https://bateriascapsa.com/wp-content/uploads/2025/09/31T-1600.png', TRUE),
('prod-12', 'a0000000-0000-0000-0000-000000000001', 'Capsa 35 1100',               'CAPSA-35-1100-12',      'Capsa',  '35 1100',       370, 15, '50Ah', '12V', 'https://bateriascapsa.com/wp-content/uploads/2025/09/35-1100.png', TRUE),
('prod-13', 'a0000000-0000-0000-0000-000000000001', 'Capsa 36IMX 770 (11P)',       'CAPSA-36IMX-770-(11P)-13', 'Capsa', '36IMX 770 (11P)', 290, 16, '50Ah', '12V', 'https://bateriascapsa.com/wp-content/uploads/2025/09/36I-650.png', TRUE),
('prod-14', 'a0000000-0000-0000-0000-000000000001', 'Capsa 65 1100',               'CAPSA-65-1100-14',      'Capsa',  '65 1100',       520, 10, '50Ah', '12V', 'https://bateriascapsa.com/wp-content/uploads/2025/09/65-1100.png', TRUE),
('prod-15', 'a0000000-0000-0000-0000-000000000001', 'Capsa 4D 1800',               'CAPSA-4D-1800-15',      'Capsa',  '4D 1800',       680, 18, '50Ah', '12V', 'https://bateriascapsa.com/wp-content/uploads/2025/09/4D1800.png', TRUE),
('prod-16', 'a0000000-0000-0000-0000-000000000001', 'Capsa 4D 2000',               'CAPSA-4D-2000-16',      'Capsa',  '4D 2000',       700, 17, '50Ah', '12V', 'https://bateriascapsa.com/wp-content/uploads/2025/09/4D2000.png', TRUE),
('prod-17', 'a0000000-0000-0000-0000-000000000001', 'Capsa 8DI 2600',              'CAPSA-8DI-2600-17',     'Capsa',  '8DI 2600',      850, 22, '50Ah', '12V', 'https://bateriascapsa.com/wp-content/uploads/2025/09/8DI-2600.png', TRUE)
ON CONFLICT (id) DO NOTHING;

-- SOLITE (8 productos)
INSERT INTO public.products (id, category_id, title, sku, brand, model, price, stock, amperage, voltage, "imageUrl", is_active) VALUES
('prod-18', 'a0000000-0000-0000-0000-000000000001', 'Solite 42B19L',   'SOLITE-42B19L-18',   'Solite', '42B19L',    280, 22, '50Ah', '12V', 'https://bateriaskallpa.com/wp-content/uploads/2023/09/solite-42B19L.jpg', TRUE),
('prod-19', 'a0000000-0000-0000-0000-000000000001', 'Solite 50B19L',   'SOLITE-50B19L-19',   'Solite', '50B19L',    300, 17, '50Ah', '12V', 'https://bateriaskallpa.com/wp-content/uploads/2023/09/solite-65B24L.jpg', TRUE),
('prod-20', 'a0000000-0000-0000-0000-000000000001', 'Solite 55B24L',   'SOLITE-55B24L-20',   'Solite', '55B24L',    320, 20, '50Ah', '12V', 'https://bateriaskallpa.com/wp-content/uploads/2023/09/solite-55B24LS.jpg', TRUE),
('prod-21', 'a0000000-0000-0000-0000-000000000001', 'Solite 75D23L',   'SOLITE-75D23L-21',   'Solite', '75D23L',    430, 14, '50Ah', '12V', 'https://ditesac.com/wp-content/uploads/2024/09/BSO0034-768x745.jpg', TRUE),
('prod-22', 'a0000000-0000-0000-0000-000000000001', 'Solite 105D31L',  'SOLITE-105D31L-22',  'Solite', '105D31L',   480,  6, '50Ah', '12V', 'https://www.daitocar.cl/wp-content/uploads/2025/06/bas206-l.webp', TRUE),
('prod-23', 'a0000000-0000-0000-0000-000000000001', 'Solite CMF55066', 'SOLITE-CMF55066-23', 'Solite', 'CMF55066',  380, 18, '50Ah', '12V', 'https://ditesac.com/wp-content/uploads/2024/09/BSO0047-768x726.jpg', TRUE),
('prod-24', 'a0000000-0000-0000-0000-000000000001', 'Solite CMF56219', 'SOLITE-CMF56219-24', 'Solite', 'CMF56219',  400, 11, '50Ah', '12V', 'https://ditesac.com/wp-content/uploads/2024/09/BSO0052-768x706.jpg', TRUE),
('prod-25', 'a0000000-0000-0000-0000-000000000001', 'Solite CMF57412', 'SOLITE-CMF57412-25', 'Solite', 'CMF57412',  480, 23, '50Ah', '12V', 'https://bateriaskallpa.com/wp-content/uploads/2023/09/Solite-CMF57412-15-PLACAS-600x600.jpg', TRUE)
ON CONFLICT (id) DO NOTHING;

-- VARTA (9 productos)
INSERT INTO public.products (id, category_id, title, sku, brand, model, price, stock, amperage, voltage, "imageUrl", is_active) VALUES
('prod-26', 'a0000000-0000-0000-0000-000000000001', 'Varta 27R V5 1300',      'VARTA-27R-V5-1300-26',     'Varta', '27R V5 1300',   520, 22, '50Ah', '12V', 'https://ditesac.com/wp-content/uploads/2024/09/BVA0027.png', TRUE),
('prod-27', 'a0000000-0000-0000-0000-000000000001', 'Varta 31T V4 1400',      'VARTA-31T-V4-1400-27',     'Varta', '31T V4 1400',   550, 14, '50Ah', '12V', 'https://api.implementos.com.pe/file/sku/1000/CAPBAT0004_1.jpg', TRUE),
('prod-28', 'a0000000-0000-0000-0000-000000000001', 'Varta 35 V4 850',        'VARTA-35-V4-850-28',       'Varta', '35 V4 850',    400,  5, '50Ah', '12V', 'https://ditesac.com/wp-content/uploads/2024/09/BVA0030-768x768.png', TRUE),
('prod-29', 'a0000000-0000-0000-0000-000000000001', 'Varta 42IST V4 870',     'VARTA-42IST-V4-870-29',    'Varta', '42IST V4 870', 380, 21, '50Ah', '12V', 'https://ditesac.com/wp-content/uploads/2024/09/BVA0016.jpg', TRUE),
('prod-30', 'a0000000-0000-0000-0000-000000000001', 'Varta 42IST V5 950',     'VARTA-42IST-V5-950-30',    'Varta', '42IST V5 950', 420, 23, '50Ah', '12V', 'https://ditesac.com/wp-content/uploads/2024/09/BVA0046-768x768.png', TRUE),
('prod-31', 'a0000000-0000-0000-0000-000000000001', 'Varta 48IST V5 1150',    'VARTA-48IST-V5-1150-31',   'Varta', '48IST V5 1150', 460, 21, '50Ah', '12V', 'https://ditesac.com/wp-content/uploads/2024/09/BVA0007-768x768.png', TRUE),
('prod-32', 'a0000000-0000-0000-0000-000000000001', 'Varta 49ST V4 1250',     'VARTA-49ST-V4-1250-32',    'Varta', '49ST V4 1250', 550, 19, '50Ah', '12V', 'https://ditesac.com/wp-content/uploads/2024/09/BVA0031-49STV41250-3-768x768.jpg', TRUE),
('prod-33', 'a0000000-0000-0000-0000-000000000001', 'Varta 4DLTI V4 1500',    'VARTA-4DLTI-V4-1500-33',   'Varta', '4DLTI V4 1500', 730, 13, '50Ah', '12V', 'https://api.implementos.com.pe/file/sku/1000/VARBAT3003_1.jpg', TRUE),
('prod-34', 'a0000000-0000-0000-0000-000000000001', 'Varta 8DI V4 2650',      'VARTA-8DI-V4-2650-34',     'Varta', '8DI V4 2650',  950, 22, '50Ah', '12V', 'https://api.implementos.com.pe/file/sku/1000/VARBAT3002_1.jpg', TRUE)
ON CONFLICT (id) DO NOTHING;

-- ULTRABAT (5 productos)
INSERT INTO public.products (id, category_id, title, sku, brand, model, price, stock, amperage, voltage, "imageUrl", is_active) VALUES
('prod-35', 'a0000000-0000-0000-0000-000000000001', 'Ultrabat HL-55', 'ULTRABAT-HL-55-35', 'Ultrabat', 'HL-55', 250, 23, '50Ah', '12V', 'https://elgatobaterias.com/wp-content/uploads/2025/07/HL-55N.jpg', TRUE),
('prod-36', 'a0000000-0000-0000-0000-000000000001', 'Ultrabat FF-66', 'ULTRABAT-FF-66-36', 'Ultrabat', 'FF-66', 280, 18, '50Ah', '12V', 'https://elgatobaterias.com/wp-content/uploads/2025/07/FF66-N.jpg', TRUE),
('prod-37', 'a0000000-0000-0000-0000-000000000001', 'Ultrabat W-70N', 'ULTRABAT-W-70N-37', 'Ultrabat', 'W-70N', 290, 19, '50Ah', '12V', 'https://elgatobaterias.com/wp-content/uploads/2025/07/W-70N-300x300.jpg', TRUE),
('prod-38', 'a0000000-0000-0000-0000-000000000001', 'Ultrabat V-82N', 'ULTRABAT-V-82N-38', 'Ultrabat', 'V-82N', 330, 13, '50Ah', '12V', 'https://elgatobaterias.com/wp-content/uploads/2025/07/V-82I-300x300.jpg', TRUE),
('prod-39', 'a0000000-0000-0000-0000-000000000001', 'Ultrabat S-96I', 'ULTRABAT-S-96I-39', 'Ultrabat', 'S-96I', 360, 20, '50Ah', '12V', 'https://elgatobaterias.com/wp-content/uploads/2025/07/S96-I.jpg', TRUE)
ON CONFLICT (id) DO NOTHING;

-- ETNA (10 productos)
INSERT INTO public.products (id, category_id, title, sku, brand, model, price, stock, amperage, voltage, "imageUrl", is_active) VALUES
('prod-40', 'a0000000-0000-0000-0000-000000000001', 'Etna HL-11',        'ETNA-HL-11-40',       'Etna', 'HL-11',      280, 18, '50Ah', '12V', 'https://ditesac.com/wp-content/uploads/2024/09/BET0032.png', TRUE),
('prod-41', 'a0000000-0000-0000-0000-000000000001', 'Etna FF-11',        'ETNA-FF-11-41',       'Etna', 'FF-11',      300, 22, '50Ah', '12V', 'https://promart.vteximg.com.br/arquivos/ids/6963206-380-380/150232.jpg?v=638182350717800000', TRUE),
('prod-42', 'a0000000-0000-0000-0000-000000000001', 'Etna FF-13',        'ETNA-FF-13-42',       'Etna', 'FF-13',      320, 10, '50Ah', '12V', 'https://promart.vteximg.com.br/arquivos/ids/6963205-380-380/150233.jpg?v=638182350679130000', TRUE),
('prod-43', 'a0000000-0000-0000-0000-000000000001', 'Etna W-13',         'ETNA-W-13-43',        'Etna', 'W-13',       330,  5, '50Ah', '12V', 'https://promart.vteximg.com.br/arquivos/ids/6888016-380-380/149962.jpg?v=638155766389300000', TRUE),
('prod-44', 'a0000000-0000-0000-0000-000000000001', 'Etna V-13NOR',      'ETNA-V-13NOR-44',     'Etna', 'V-13NOR',    370, 15, '50Ah', '12V', 'https://promart.vteximg.com.br/arquivos/ids/6888022-380-380/149972.jpg?v=638155766581970000', TRUE),
('prod-45', 'a0000000-0000-0000-0000-000000000001', 'Etna FH-1215NOR',   'ETNA-FH-1215NOR-45',  'Etna', 'FH-1215NOR', 400, 18, '50Ah', '12V', 'https://promart.vteximg.com.br/arquivos/ids/6888017-380-380/149971.jpg?v=638155766421900000', TRUE),
('prod-46', 'a0000000-0000-0000-0000-000000000001', 'Etna S-1215EM',     'ETNA-S-1215EM-46',    'Etna', 'S-1215EM',   380, 16, '50Ah', '12V', 'https://promart.vteximg.com.br/arquivos/ids/6888019-380-380/149970.jpg?v=638155766487900000', TRUE),
('prod-47', 'a0000000-0000-0000-0000-000000000001', 'Etna SU-1217',      'ETNA-SU-1217-47',     'Etna', 'SU-1217',    480, 24, '50Ah', '12V', 'https://ditesac.com/wp-content/uploads/2024/09/BET0093.png', TRUE),
('prod-48', 'a0000000-0000-0000-0000-000000000001', 'Etna S-1219',       'ETNA-S-1219-48',      'Etna', 'S-1219',     580, 13, '50Ah', '12V', 'https://ditesac.com/wp-content/uploads/2024/09/BET0112.png', TRUE),
('prod-49', 'a0000000-0000-0000-0000-000000000001', 'Etna S-1223 N/I',   'ETNA-S-1223-N/I-49',  'Etna', 'S-1223 N/I', 630, 23, '50Ah', '12V', 'https://ditesac.com/wp-content/uploads/2024/09/BET0112.png', TRUE)
ON CONFLICT (id) DO NOTHING;

-- ENERJET (13 productos)
INSERT INTO public.products (id, category_id, title, sku, brand, model, price, stock, amperage, voltage, "imageUrl", is_active) VALUES
('prod-50', 'a0000000-0000-0000-0000-000000000001', 'Enerjet 11D56',  'ENERJET-11D56-50',  'Enerjet', '11D56', 290, 23, '50Ah', '12V', 'https://www.enerjet.com.pe/_next/image?url=https%3A%2F%2Fwww.enerjet.com.pe%2Fadmin%2Fuploads%2F11d56p.jpg&w=3840&q=75', TRUE),
('prod-51', 'a0000000-0000-0000-0000-000000000001', 'Enerjet 11T56',  'ENERJET-11T56-51',  'Enerjet', '11T56', 320, 24, '50Ah', '12V', 'https://www.enerjet.com.pe/_next/image?url=https%3A%2F%2Fwww.enerjet.com.pe%2Fadmin%2Fuploads%2Fffff.png&w=3840&q=75', TRUE),
('prod-52', 'a0000000-0000-0000-0000-000000000001', 'Enerjet 11W75',  'ENERJET-11W75-52',  'Enerjet', '11W75', 320, 15, '50Ah', '12V', 'https://www.enerjet.com.pe/_next/image?url=https%3A%2F%2Fwww.enerjet.com.pe%2Fadmin%2Fuploads%2F11w63.jpg&w=3840&q=75', TRUE),
('prod-53', 'a0000000-0000-0000-0000-000000000001', 'Enerjet 13W75',  'ENERJET-13W75-53',  'Enerjet', '13W75', 340, 12, '50Ah', '12V', 'https://promart.vteximg.com.br/arquivos/ids/951603-1000-1000/136376.jpg?v=637584190146570000', TRUE),
('prod-54', 'a0000000-0000-0000-0000-000000000001', 'Enerjet 13S85',  'ENERJET-13S85-54',  'Enerjet', '13S85', 380, 13, '50Ah', '12V', 'https://www.enerjet.com.pe/_next/image?url=https%3A%2F%2Fwww.enerjet.com.pe%2Fadmin%2Fuploads%2Fbaa0000019.png&w=3840&q=75', TRUE),
('prod-55', 'a0000000-0000-0000-0000-000000000001', 'Enerjet 15M99',  'ENERJET-15M99-55',  'Enerjet', '15M99', 430, 12, '50Ah', '12V', 'https://www.enerjet.com.pe/_next/image?url=https%3A%2F%2Fwww.enerjet.com.pe%2Fadmin%2Fuploads%2F15m99.png&w=3840&q=75', TRUE),
('prod-56', 'a0000000-0000-0000-0000-000000000001', 'Enerjet 15MB90', 'ENERJET-15MB90-56', 'Enerjet', '15MB90', 410,  5, '50Ah', '12V', 'https://www.enerjet.com.pe/_next/image?url=https%3A%2F%2Fwww.enerjet.com.pe%2Fadmin%2Fuploads%2Fbaa0000107.png&w=3840&q=75', TRUE),
('prod-57', 'a0000000-0000-0000-0000-000000000001', 'Enerjet 17T114', 'ENERJET-17T114-57', 'Enerjet', '17T114', 510,  8, '50Ah', '12V', 'https://www.enerjet.com.pe/_next/image?url=https%3A%2F%2Fwww.enerjet.com.pe%2Fadmin%2Fuploads%2F17t114.jpg&w=3840&q=75', TRUE),
('prod-58', 'a0000000-0000-0000-0000-000000000001', 'Enerjet 19P130', 'ENERJET-19P130-58', 'Enerjet', '19P130', 610,  6, '50Ah', '12V', 'https://www.enerjet.com.pe/_next/image?url=https%3A%2F%2Fwww.enerjet.com.pe%2Fadmin%2Fuploads%2F19p130.jpg&w=3840&q=75', TRUE),
('prod-59', 'a0000000-0000-0000-0000-000000000001', 'Enerjet 23P159', 'ENERJET-23P159-59', 'Enerjet', '23P159', 670, 22, '50Ah', '12V', 'https://www.enerjet.com.pe/_next/image?url=https%3A%2F%2Fwww.enerjet.com.pe%2Fadmin%2Fuploads%2Fbaa0000011.png&w=3840&q=75', TRUE),
('prod-60', 'a0000000-0000-0000-0000-000000000001', 'Enerjet 25P170', 'ENERJET-25P170-60', 'Enerjet', '25P170', 730, 24, '50Ah', '12V', 'https://www.enerjet.com.pe/_next/image?url=https%3A%2F%2Fwww.enerjet.com.pe%2Fadmin%2Fuploads%2Fbaa0000012.png&w=3840&q=75', TRUE),
('prod-61', 'a0000000-0000-0000-0000-000000000001', 'Enerjet 27P190', 'ENERJET-27P190-61', 'Enerjet', '27P190', 770, 14, '50Ah', '12V', 'https://www.enerjet.com.pe/_next/image?url=https%3A%2F%2Fwww.enerjet.com.pe%2Fadmin%2Fuploads%2Fbaa0000235.png&w=3840&q=75', TRUE),
('prod-62', 'a0000000-0000-0000-0000-000000000001', 'Enerjet 33P224', 'ENERJET-33P224-62', 'Enerjet', '33P224', 900, 11, '50Ah', '12V', 'https://www.enerjet.com.pe/_next/image?url=https%3A%2F%2Fwww.enerjet.com.pe%2Fadmin%2Fuploads%2Fbaa0000106.png&w=3840&q=75', TRUE)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 6c. ORDEN DE PRUEBA (ORD-1042)
-- ============================================================================

INSERT INTO public.orders (id, customer_id, date, "customerName", "documentId", "receiptType", email, "phoneNumber", subtotal, taxes, total, status)
VALUES (
    'ORD-1042',
    NULL,
    '2026-05-27',
    'Juan Pérez',
    '09812423',
    'boleta',
    'juan.perez@gmail.com',
    '987654321',
    280.00,
    45.00,
    325.00,
    'Pendiente'
)
ON CONFLICT (id) DO NOTHING;

-- Items de la orden
INSERT INTO public.order_items (order_id, product_id, product_title, product_sku, quantity, unit_price)
VALUES (
    'ORD-1042',
    'prod-40',
    'Etna HL-11',
    'ETNA-HL-11-40',
    1,
    280.00
);

-- Pago de la orden
INSERT INTO public.payments (order_id, "paymentMethod", amount, status)
VALUES (
    'ORD-1042',
    'yape',
    325.00,
    'Pendiente'
);

-- ============================================================================
-- 7. VERIFICACIÓN FINAL
-- ============================================================================
SELECT '✅ Setup completado' AS mensaje,
       (SELECT COUNT(*) FROM public.products) AS total_productos,
       (SELECT COUNT(*) FROM public.categories) AS total_categorias,
       (SELECT COUNT(*) FROM public.orders) AS total_ordenes,
       (SELECT COUNT(*) FROM public.order_items) AS total_order_items,
       (SELECT COUNT(*) FROM public.payments) AS total_pagos;
