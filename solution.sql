-- Этап 1. Создание и заполнение БД
CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales (
    id TEXT,
    auto TEXT,
    gasoline_consumption TEXT,
    price TEXT,
    date TEXT,
    person_name TEXT,
    phone TEXT,
    discount TEXT,
    brand_origin TEXT
);
CREATE SCHEMA car_shop;

-- 1. Справочник цветов
CREATE TABLE car_shop.colors (
    color_id SERIAL PRIMARY KEY /* serial суррогатный первичный ключ с автоинкрементом для быстрой связи таблиц по целочисленному идентификатору */,
    color_name VARCHAR(50) NOT NULL UNIQUE /* varchar(50) названия цветов состоят из букв переменной длины и редко превышают 50 символов; unique защищает от дублирования названий цветов */
);

-- 2. Справочник стран происхождения брендов
CREATE TABLE car_shop.origins (
    origin_id SERIAL PRIMARY KEY /* serial целочисленный автоинкрементный ID для быстрой связи брендов со странами их происхождения */,
    country_name VARCHAR(100) NOT NULL UNIQUE /* varchar(100) названия стран имеют переменную текстовую длину, ограничение в 100 символов гарантирует запас для любых сложных названий */
);

-- 3. Справочник брендов
CREATE TABLE car_shop.brands (
    brand_id SERIAL PRIMARY KEY /* serial целочисленный суррогатный ключ для уникальной идентификации марки автомобиля */,
    brand_name VARCHAR(100) NOT NULL UNIQUE /* varchar(100) названия брендов могут содержать буквы и цифры, имеют переменную длину, уникальны в рамках справочника */,
    origin_id INTEGER NOT NULL REFERENCES car_shop.origins(origin_id) /* integer внешний ключ, соответствующий типу первичного ключа origin_id, реализует связь "один ко многим" (у одной страны много брендов) */
);

-- 4. Справочник моделей (ссылается на бренд)
CREATE TABLE car_shop.models (
    model_id SERIAL PRIMARY KEY /* serial автоинкрементный идентификатор для однозначного определения модели авто */,
    brand_id INTEGER NOT NULL REFERENCES car_shop.brands(brand_id) ON DELETE CASCADE /* integer внешний ключ для связи со справочником брендов; каскадное удаление уберет модели, если удалится бренд */,
    model_name VARCHAR(150) NOT NULL UNIQUE /* varchar(150) коммерческие названия моделей бывают длинными и содержат спецсимволы, ограничение в 150 символов оптимально */,
    gasoline_consumption NUMERIC(4, 1) CHECK (gasoline_consumption < 100.0) /* numeric(4, 1) точный числовой тип с фиксированной точкой; расход измеряется максимум двузначным числом и одним знаком после запятой (например, 12.5), для электромобилей поле может оставаться null */
);

-- 3. Таблица мост автомобиля (Связь Многие-ко-Многим)
CREATE TABLE car_shop.cars (
    car_id SERIAL PRIMARY KEY /* serial уникальный суррогатный ключ для идентификации конкретной единицы автомобиля определенной модели и цвета */,
    model_id INTEGER NOT NULL REFERENCES car_shop.models(model_id) ON DELETE CASCADE /* integer внешний ключ, соответствующий типу данных первичного ключа model_id, для связи с таблицей моделей */,
    color_id INTEGER NOT NULL REFERENCES car_shop.colors(color_id) ON DELETE CASCADE /* integer внешний ключ, соответствующий типу данных первичного ключа color_id, для связи со справочником цветов */,
    CONSTRAINT unique_car_color UNIQUE (model_id, color_id)
);

-- 4. Справочник клиентов
CREATE TABLE car_shop.customers (
    customer_id SERIAL PRIMARY KEY /* serial первичный ключ с автоинкрементом для быстрой индексации и связывания записей о клиентах */,
    person_name VARCHAR(255) NOT NULL /* varchar(255) ФИО покупателя имеет переменную длину и состоит из букв, длина до 255 символов гарантирует, что даже самые длинные составные имена не обрежутся */,
    phone VARCHAR(50) NOT NULL UNIQUE /* varchar(50) номер телефона содержит цифры и спецсимволы (+, -, скобки), поэтому используется varchar; unique добавлен, так как по ТЗ телефон является уникальным маркером клиента */
);

-- 5. Таблица продаж
CREATE TABLE car_shop.sales (
    sale_id SERIAL PRIMARY KEY /* serial первичный ключ с автоинкрементом для однозначной идентификации каждой конкретной сделки купли-продажи */,
    car_id INTEGER NOT NULL REFERENCES car_shop.cars(car_id) /* integer внешний ключ для связи транзакции продажи с конкретным автомобилем из таблицы cars */,
    customer_id INTEGER NOT NULL REFERENCES car_shop.customers(customer_id) /* integer внешний ключ для связи транзакции продажи с конкретным покупателем из таблицы customers */,
    price NUMERIC(9, 2) NOT NULL CHECK (price <= 9999999.99) /* numeric(9, 2) цена может содержать только сотые и не может быть больше семизначной суммы. У numeric повышенная точность при работе с дробными числами, поэтому при операциях с этим типом данных дробные числа не потеряются */,
    purchase_date DATE NOT NULL /* date используется специальный системный тип для хранения даты (год-месяц-день) без времени, что позволяет выполнять эффективную фильтрацию и сортировку по периодам */,
    discount NUMERIC(5, 2) NOT NULL CHECK (discount BETWEEN 0 AND 100) /* numeric(5, 2) точный числовой тип с фиксированной точкой для хранения процентов (например, 99.99%), check гарантирует валидность данных в пределах от 0 до 100% */
);
-- Заполнение таблиц
INSERT INTO car_shop.colors (color_name)
SELECT DISTINCT trim(split_part(auto, ',', 2))
FROM raw_data.sales
WHERE auto IS NOT NULL AND auto LIKE '%,%';

INSERT INTO car_shop.origins (country_name)
SELECT DISTINCT 
    CASE 
        WHEN brand_origin IS NULL OR lower(trim(brand_origin)) = 'null' OR trim(brand_origin) = '' THEN 'Unknown'
        ELSE trim(brand_origin)
    END
FROM raw_data.sales;

INSERT INTO car_shop.brands (brand_name, origin_id)
SELECT DISTINCT 
    split_part(trim(split_part(s.auto, ',', 1)), ' ', 1) AS brand_name,
    o.origin_id
FROM raw_data.sales s
JOIN car_shop.origins o ON o.country_name = (
    CASE 
        WHEN s.brand_origin IS NULL OR lower(trim(s.brand_origin)) = 'null' OR trim(s.brand_origin) = '' THEN 'Unknown'
        ELSE trim(s.brand_origin)
    END
);

INSERT INTO car_shop.models (brand_id, model_name, gasoline_consumption)
SELECT DISTINCT 
    b.brand_id,
    trim(substring(trim(split_part(s.auto, ',', 1)) from '^[^\s]+\s+(.*)$')) AS model_name,
    CASE 
        WHEN s.gasoline_consumption IS NULL OR lower(trim(s.gasoline_consumption)) = 'null' OR trim(s.gasoline_consumption) = '' THEN NULL 
        ELSE s.gasoline_consumption::NUMERIC 
    END
FROM raw_data.sales s
JOIN car_shop.brands b ON b.brand_name = split_part(trim(split_part(s.auto, ',', 1)), ' ', 1);

INSERT INTO car_shop.cars (model_id, color_id)
SELECT DISTINCT m.model_id, c.color_id
FROM raw_data.sales s
JOIN car_shop.brands b ON b.brand_name = split_part(trim(split_part(s.auto, ',', 1)), ' ', 1)
JOIN car_shop.models m ON m.brand_id = b.brand_id 
    AND m.model_name = trim(substring(trim(split_part(s.auto, ',', 1)) from '^[^\s]+\s+(.*)$'))
JOIN car_shop.colors c ON c.color_name = trim(split_part(s.auto, ',', 2));

INSERT INTO car_shop.customers (person_name, phone)
SELECT DISTINCT person_name, phone
FROM raw_data.sales;

INSERT INTO car_shop.sales (car_id, customer_id, price, purchase_date, discount)
SELECT 
    car.car_id,
    cust.customer_id,
    s.price::NUMERIC,
    s.date::DATE, 
    s.discount::NUMERIC
FROM raw_data.sales s
JOIN car_shop.customers cust ON cust.phone = s.phone
JOIN car_shop.brands b ON b.brand_name = split_part(trim(split_part(s.auto, ',', 1)), ' ', 1)
JOIN car_shop.models m ON m.brand_id = b.brand_id 
    AND m.model_name = trim(substring(trim(split_part(s.auto, ',', 1)) from '^[^\s]+\s+(.*)$'))
JOIN car_shop.colors c ON c.color_name = trim(split_part(s.auto, ',', 2))
JOIN car_shop.cars car ON car.model_id = m.model_id AND car.color_id = c.color_id;

-- Этап 2. Создание выборок

---- Запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.
SELECT 
    ROUND(
        (COUNT(*) FILTER (WHERE gasoline_consumption IS NULL) * 100.0) / COUNT(*), 
        2
    ) AS nulls_percentage_gasoline_consumption
FROM car_shop.models;

---- Запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.
SELECT 
    b.brand_name AS brand_name,
    EXTRACT(YEAR FROM s.purchase_date) AS year,
    ROUND(AVG(s.price), 2) AS price_avg
FROM car_shop.sales s
JOIN car_shop.cars c ON s.car_id = c.car_id
JOIN car_shop.models m ON c.model_id = m.model_id
JOIN car_shop.brands b ON m.brand_id = b.brand_id
GROUP BY b.brand_name, EXTRACT(YEAR FROM s.purchase_date)
ORDER BY brand_name ASC, year ASC;

---- Средняя цена всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.
SELECT 
    EXTRACT(MONTH FROM purchase_date) AS month,
    EXTRACT(YEAR FROM purchase_date) AS year,
    ROUND(AVG(price), 2) AS price_avg
FROM car_shop.sales
WHERE EXTRACT(YEAR FROM purchase_date) = 2022
GROUP BY EXTRACT(MONTH FROM purchase_date), EXTRACT(YEAR FROM purchase_date)
ORDER BY month ASC;

---- Запрос, который выведет список купленных машин у каждого пользователя.
SELECT 
    cust.person_name AS person,
    STRING_AGG(b.brand_name || ' ' || m.model_name, ', ') AS cars
FROM car_shop.sales s
JOIN car_shop.customers cust ON s.customer_id = cust.customer_id
JOIN car_shop.cars c ON s.car_id = c.car_id
JOIN car_shop.models m ON c.model_id = m.model_id
JOIN car_shop.brands b ON m.brand_id = b.brand_id
GROUP BY cust.customer_id, cust.person_name
ORDER BY person ASC;


---- Запрос находит максимальную и минимальную базовую цену (без скидки) автомобиля для каждой страны происхождения бренда.
SELECT 
    o.country_name AS brand_origin,
    ROUND(MAX(s.price / (1 - s.discount / 100.0)), 2) AS price_max,
    ROUND(MIN(s.price / (1 - s.discount / 100.0)), 2) AS price_min
FROM car_shop.sales s
JOIN car_shop.cars c ON s.car_id = c.car_id
JOIN car_shop.models m ON c.model_id = m.model_id
JOIN car_shop.brands b ON m.brand_id = b.brand_id
JOIN car_shop.origins o ON b.origin_id = o.origin_id
GROUP BY o.country_name;


---- Запрос, который покажет количество всех пользователей из США.
SELECT 
    COUNT(*) AS persons_from_usa_count
FROM car_shop.customers
WHERE phone LIKE '+1%';


