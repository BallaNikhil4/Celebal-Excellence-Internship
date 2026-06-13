create database week2;
use week2;
CREATE TABLE customers (
    customer_id   INT           PRIMARY KEY,
    first_name    VARCHAR(50)   NOT NULL,
    last_name     VARCHAR(50)   NOT NULL,
    email         VARCHAR(100)  UNIQUE NOT NULL,
    city          VARCHAR(50)   NOT NULL,
    state         VARCHAR(50)   NOT NULL,
    join_date     DATE          NOT NULL,
    is_premium    BOOLEAN       DEFAULT FALSE
);

CREATE INDEX idx_customers_city ON customers(city);
CREATE INDEX idx_customers_state ON customers(state);

CREATE TABLE products (
    product_id    INT           PRIMARY KEY,
    product_name  VARCHAR(100)  NOT NULL,
    category      VARCHAR(50)   NOT NULL,
    brand         VARCHAR(50)   NOT NULL,
    unit_price    DECIMAL(10,2) NOT NULL CHECK (unit_price > 0),
    stock_qty     INT           NOT NULL DEFAULT 0 CHECK (stock_qty >= 0)
);

CREATE INDEX idx_products_category ON products(category);

CREATE TABLE orders (
    order_id      INT           PRIMARY KEY,
    customer_id   INT           NOT NULL,
    order_date    DATE          NOT NULL,
    status        VARCHAR(20)   NOT NULL DEFAULT 'Pending'
                  CHECK (status IN ('Pending','Shipped','Delivered','Cancelled')),
    total_amount  DECIMAL(12,2) NOT NULL CHECK (total_amount >= 0),

    FOREIGN KEY (customer_id)
    REFERENCES customers(customer_id)
);

CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_orders_status ON orders(status);

CREATE TABLE order_items (
    item_id       INT           PRIMARY KEY,
    order_id      INT           NOT NULL,
    product_id    INT           NOT NULL,
    quantity      INT           NOT NULL CHECK (quantity > 0),
    unit_price    DECIMAL(10,2) NOT NULL CHECK (unit_price > 0),
    discount_pct  DECIMAL(5,2)  DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 100),

    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

INSERT INTO customers VALUES 
(101, 'Aarav',  'Sharma', 'aarav.s@email.com',  'Mumbai',    'Maharashtra', '2024-01-15', TRUE), 
(102, 'Priya',  'Patel',  'priya.p@email.com',  'Ahmedabad', 'Gujarat',     '2024-02-20', FALSE), 
(103, 'Rohan',  'Gupta',  'rohan.g@email.com',  'Delhi',     'Delhi',       '2024-03-10', TRUE), 
(104, 'Sneha',  'Reddy',  'sneha.r@email.com',  'Hyderabad', 'Telangana',   '2024-04-05', FALSE), 
(105, 'Vikram', 'Singh',  'vikram.s@email.com', 'Jaipur',    'Rajasthan',   '2024-05-12', TRUE), 
(106, 'Ananya', 'Iyer',   'ananya.i@email.com', 'Chennai',   'Tamil Nadu',  '2024-06-18', FALSE), 
(107, 'Karan',  'Mehta',  'karan.m@email.com',  'Pune',      'Maharashtra', '2024-07-22', TRUE), 
(108, 'Divya',  'Nair',   'divya.n@email.com',  'Kochi',     'Kerala',      '2024-08-30', FALSE); 

-- ========== INSERT: products ========== 
INSERT INTO products VALUES 
(201, 'Wireless Earbuds',     'Electronics', 'BoAt',          1499.00, 250), 
(202, 'Cotton T-Shirt',       'Clothing',    'Levis',         799.00,  500), 
(203, 'Smart Watch',          'Electronics', 'Noise',         2999.00, 150), 
(204, 'Running Shoes',        'Clothing',    'Nike',          4599.00, 120), 
(205, 'Bluetooth Speaker',    'Electronics', 'JBL',           3499.00, 200), 
(206, 'Bedsheet Set',         'Home',        'Spaces',        1299.00, 300), 
(207, 'Laptop Stand',         'Electronics', 'AmazonBasics',  899.00,  180), 
(208, 'Cushion Covers (Set)', 'Home',        'HomeCenter',    599.00,  400); 

-- ========== INSERT: orders ========== 
INSERT INTO orders VALUES 
(1001, 101, '2024-08-01', 'Delivered',  4498.00), 
(1002, 102, '2024-08-03', 'Delivered',  799.00), 
(1003, 103, '2024-08-05', 'Shipped',    7498.00), 
(1004, 101, '2024-08-10', 'Delivered',  3499.00), 
(1005, 104, '2024-08-12', 'Cancelled',  2999.00), 
(1006, 105, '2024-08-15', 'Delivered',  5898.00), 
(1007, 106, '2024-08-18', 'Pending',    1299.00), 
(1008, 103, '2024-08-20', 'Delivered',  899.00), 
(1009, 107, '2024-08-25', 'Shipped',    6098.00), 
(1010, 108, '2024-08-28', 'Delivered',  1598.00); 

-- ========== INSERT: order_items ========== 
INSERT INTO order_items VALUES 
(5001, 1001, 201, 2, 1499.00, 0), 
(5002, 1001, 207, 1, 899.00,  10), 
(5003, 1002, 202, 1, 799.00,  0), 
(5004, 1003, 203, 1, 2999.00, 0), 
(5005, 1003, 204, 1, 4599.00, 5), 
(5006, 1004, 205, 1, 3499.00, 0), 
(5007, 1005, 203, 1, 2999.00, 0), 
(5008, 1006, 201, 1, 1499.00, 10), 
(5009, 1006, 204, 1, 4599.00, 5), 
(5010, 1007, 206, 1, 1299.00, 0), 
(5011, 1008, 207, 1, 899.00,  0), 
(5012, 1009, 205, 1, 3499.00, 0), 
(5013, 1009, 208, 2, 599.00,  15), 
(5014, 1010, 206, 1, 1299.00, 0), 
(5015, 1010, 208, 1, 599.00,  0); 

-- q1. write a query to display all columns and rows from the customers table

select * from customers;


-- q2. retrieve only the first_name, last_name and city of all customers

select first_name,last_name,city from customers;


-- q3. list all unique categories available in the products table

select distinct category from products;


-- q6. try inserting a product with unit_price = -50

insert into products values(
209,
'test product',
'electronics',
'testbrand',
-50,
100
);


-- q7. retrieve all orders with status = 'Delivered'

select * from orders where status='Delivered';


-- q8. find all products in the electronics category with unit_price greater than 2000

select * from products
where category='Electronics' and unit_price>2000;


-- q9. list all customers who joined in 2024 and belong to maharashtra

select * from customers
where state='Maharashtra' and year(join_date)=2024;


-- q10. find all orders placed between 2024-08-10 and 2024-08-25 that are not cancelled

select * from orders
where order_date between '2024-08-10' and '2024-08-25'
and status<>'Cancelled';


-- q11. sample query using order_date

select * from orders where order_date>='2024-08-10';


-- q12. given query

select * from customers where year(join_date)=2024;


-- q12. rewritten query

select * from customers
where join_date>='2024-01-01'
and join_date<'2025-01-01';


-- q13. count total number of orders

select count(*) as total_orders from orders;


-- q14. total revenue from delivered orders

select sum(total_amount) as total_revenue
from orders
where status='Delivered';


-- q15. average unit price of products in each category

select category,round(avg(unit_price),2) as average_price
from products
group by category;


-- q16. count of orders and total revenue for each status

select status,count(*) as total_orders,sum(total_amount) as total_revenue
from orders
group by status
order by total_revenue desc;


-- q17. most expensive and cheapest product in each category

select category,max(unit_price) as most_expensive,min(unit_price) as cheapest
from products
group by category;


-- q18. categories where average unit price is greater than 2000

select category,round(avg(unit_price),2) as average_price
from products
group by category
having avg(unit_price)>2000;


-- q19. display order details along with customer names

select o.order_id,o.order_date,c.first_name,c.last_name,o.total_amount
from orders o
inner join customers c on o.customer_id=c.customer_id;


-- q20. list all customers and their orders using left join

select c.customer_id,c.first_name,c.last_name,o.order_id,o.order_date
from customers c
left join orders o on c.customer_id=o.customer_id;


-- q21. display order items with product details

select o.order_id,p.product_name,oi.quantity,oi.unit_price,oi.discount_pct
from orders o
join order_items oi on o.order_id=oi.order_id
join products p on oi.product_id=p.product_id;


-- q24. classify products into price tiers using case

select product_name,unit_price,
case
when unit_price<1000 then 'Budget'
when unit_price between 1000 and 3000 then 'Mid-Range'
else 'Premium'
end as price_tier
from products;


-- q25. count delivered and not delivered orders

select
sum(case when status='Delivered' then 1 else 0 end) as delivered_orders,
sum(case when status<>'Delivered' then 1 else 0 end) as not_delivered_orders
from orders;