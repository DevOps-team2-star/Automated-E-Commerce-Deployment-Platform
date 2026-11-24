-- Schema and seed data for the shop. Runs automatically the first time the
-- Postgres container starts (docker-entrypoint-initdb.d). On RDS, Ansible runs it once.

CREATE TABLE IF NOT EXISTS products (
    id          SERIAL PRIMARY KEY,
    name        TEXT          NOT NULL,
    description TEXT          NOT NULL,
    price       NUMERIC(10,2) NOT NULL,
    image       TEXT          NOT NULL,
    stock       INTEGER       NOT NULL DEFAULT 100
);

CREATE TABLE IF NOT EXISTS orders (
    id         SERIAL PRIMARY KEY,
    product_id INTEGER       NOT NULL REFERENCES products(id),
    quantity   INTEGER       NOT NULL,
    amount     NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMPTZ   NOT NULL DEFAULT now()
);

INSERT INTO products (name, description, price, image, stock)
SELECT * FROM (VALUES
    ('Running Shoe',      'Lightweight shoe for daily runs',        79.90, 'shoe.jpg',      120),
    ('Trail Shoe',        'Grippy sole for rocky paths',            94.50, 'trail-shoe.jpg', 80),
    ('Water Bottle',      'Insulated steel bottle, 750 ml',         19.99, 'bottle.jpg',    300),
    ('Backpack',          '25 L backpack with laptop sleeve',       59.00, 'backpack.jpg',  150),
    ('Wireless Earbuds',  'Noise cancelling, 24 h battery',         89.00, 'earbuds.jpg',    90),
    ('Smart Watch',       'Heart rate, GPS and sleep tracking',    149.00, 'watch.jpg',      60),
    ('Yoga Mat',          'Non-slip 6 mm mat',                      29.50, 'yoga-mat.jpg',  200),
    ('Desk Lamp',         'LED lamp with warm and cold light',      34.90, 'lamp.jpg',      110),
    ('Coffee Mug',        'Ceramic mug, 350 ml',                     9.90, 'mug.jpg',       500),
    ('Mechanical Keyboard','Hot-swap switches, RGB',                 99.00, 'keyboard.jpg',   70),
    ('USB-C Hub',         '7-in-1 hub with HDMI',                   39.00, 'hub.jpg',       160),
    ('Hoodie',            'Cotton hoodie with DevOps logo',         45.00, 'hoodie.jpg',    130)
) AS seed(name, description, price, image, stock)
WHERE NOT EXISTS (SELECT 1 FROM products);
